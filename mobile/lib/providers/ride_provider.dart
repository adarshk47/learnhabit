import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../models/ride_model.dart';
import '../models/sensor_data.dart';
import '../models/analysis_result.dart';
import '../models/event_model.dart';
import '../services/websocket_service.dart';
import '../services/sensor_service.dart';
import '../services/camera_service.dart';
import '../services/database_service.dart';
import '../services/tts_service.dart';
import '../providers/settings_provider.dart';
import '../core/constants/app_constants.dart';

const _uuid = Uuid();

// ─── RideState ────────────────────────────────────────────────────────────────

class RideState {
  final bool isActive;
  final double currentSpeed;
  final RideModel? currentRide;

  const RideState({
    this.isActive = false,
    this.currentSpeed = 0,
    this.currentRide,
  });

  RideState copyWith({
    bool? isActive,
    double? currentSpeed,
    RideModel? currentRide,
  }) {
    return RideState(
      isActive: isActive ?? this.isActive,
      currentSpeed: currentSpeed ?? this.currentSpeed,
      currentRide: currentRide ?? this.currentRide,
    );
  }
}

// ─── ConnectionStatus extension ───────────────────────────────────────────────

extension ConnectionStatusLabel on ConnectionStatus {
  String get label {
    switch (this) {
      case ConnectionStatus.connected:    return 'Connected';
      case ConnectionStatus.connecting:   return 'Connecting…';
      case ConnectionStatus.disconnected: return 'Disconnected';
      case ConnectionStatus.error:        return 'Connection Error';
    }
  }
}

// ─── Singleton services ───────────────────────────────────────────────────────

final _wsService = WebSocketService();

// ─── connectionStatusProvider ─────────────────────────────────────────────────

final connectionStatusProvider = Provider<ConnectionStatus>((ref) {
  final async = ref.watch(_connectionStreamProvider);
  return async.valueOrNull ?? _wsService.currentStatus;
});

final _connectionStreamProvider = StreamProvider<ConnectionStatus>((ref) {
  return _wsService.status;
});

// ─── sensorDataProvider ───────────────────────────────────────────────────────

final sensorDataProvider = StreamProvider<SensorData>((ref) {
  return SensorService.instance.sensorStream;
});

// ─── analysisResultProvider ───────────────────────────────────────────────────

// Holds the latest non-null AnalysisResult; null before the first frame arrives.
final analysisResultProvider = StateProvider<AnalysisResult?>((ref) => null);

final _analysisStreamProvider = StreamProvider<AnalysisResult>((ref) {
  return _wsService.results;
});

// Sync the stream into the StateProvider so widgets can watch nullable result.
final _analysisSyncProvider = Provider<void>((ref) {
  ref.listen(_analysisStreamProvider, (_, next) {
    next.whenData((result) {
      ref.read(analysisResultProvider.notifier).state = result;
    });
  });
});

// ─── rideStateProvider ────────────────────────────────────────────────────────

class RideStateNotifier extends StateNotifier<RideState> {
  final Ref _ref;
  StreamSubscription<SensorData>? _sensorSub;
  StreamSubscription<AnalysisResult>? _analysisSub;

  double _totalDistanceKm = 0;
  double _speedSum = 0;
  int _speedCount = 0;
  double _maxSpeed = 0;
  double? _lastLat, _lastLon;
  final List<double> _speedPoints = [];
  int _hardBrakeCount = 0, _zigzagCount = 0, _speedVioCount = 0,
      _unsafeDistCount = 0, _overtakeCount = 0;

  RideStateNotifier(this._ref) : super(const RideState());

  Future<void> startRide() async {
    if (state.isActive) return;

    final settings = _ref.read(settingsProvider);

    await _wsService.connect(settings.backendWsUrl);
    await SensorService.instance.start();
    if (settings.cameraType == CameraType.PHONE) {
      await CameraService.instance.startPhoneCamera();
    }
    await TtsService.instance.init();
    TtsService.instance.setEnabled(settings.enableVoiceAlerts);

    final ride = RideModel(id: _uuid.v4(), startTime: DateTime.now());
    state = RideState(isActive: true, currentSpeed: 0, currentRide: ride);

    _sensorSub = SensorService.instance.sensorStream.listen(_onSensor);
    _analysisSub = _wsService.results.listen(_onAnalysis);
  }

  void _onSensor(SensorData data) {
    final spd = data.speedKmh;
    if (spd > _maxSpeed) _maxSpeed = spd;
    _speedSum += spd;
    _speedCount++;
    if (_speedPoints.length < 1000) _speedPoints.add(spd);

    if (data.latitude != null && data.longitude != null) {
      if (_lastLat != null) {
        _totalDistanceKm += _haversineKm(
            _lastLat!, _lastLon!, data.latitude!, data.longitude!);
      }
      _lastLat = data.latitude;
      _lastLon = data.longitude;
    }

    state = state.copyWith(currentSpeed: spd);
    _wsService.sendSensorData(data);

    if (spd > AppConstants.dangerousSpeedThresholdKmh) {
      TtsService.instance.speak(AlertType.SLOW_DOWN);
    }
  }

  void _onAnalysis(AnalysisResult result) {
    _ref.read(analysisResultProvider.notifier).state = result;
    // Count events for trip summary
    for (final w in result.warnings) {
      switch (w) {
        case 'HARD_BRAKING': _hardBrakeCount++; break;
        case 'ZIG_ZAG': _zigzagCount++; break;
        case 'SPEEDING': _speedVioCount++; break;
        case 'UNSAFE_DISTANCE': _unsafeDistCount++; break;
        case 'UNSAFE_OVERTAKING': _overtakeCount++; break;
      }
    }
    if (result.voiceAlerts.isNotEmpty) {
      TtsService.instance.speakQueue(result.voiceAlerts);
    }
  }

  Future<void> stopRide() async {
    if (!state.isActive) return;
    _sensorSub?.cancel();
    _analysisSub?.cancel();
    SensorService.instance.stop();
    CameraService.instance.stopStreaming();

    final ride = state.currentRide;
    if (ride != null) {
      final finalAnalysis = _ref.read(analysisResultProvider);
      final finalRide = ride.copyWith(
        endTime: DateTime.now(),
        distanceKm: _totalDistanceKm,
        maxSpeedKmh: _maxSpeed,
        avgSpeedKmh: _speedCount > 0 ? _speedSum / _speedCount : 0,
        skillScore: finalAnalysis?.skillScore,
        dangerScore: finalAnalysis?.dangerScore,
        safetyRating: finalAnalysis?.safetyRating,
        aggressionScore: finalAnalysis?.aggressionScore,
        accidentProbability: finalAnalysis?.accidentProbability,
        smoothness: finalAnalysis?.smoothness,
        ridingContext: finalAnalysis?.ridingContext,
        speedPoints: List.from(_speedPoints),
        hardBrakeCount: _hardBrakeCount,
        zigzagCount: _zigzagCount,
        speedViolationCount: _speedVioCount,
        unsafeDistanceCount: _unsafeDistCount,
        overtakeCount: _overtakeCount,
      );
      await DatabaseService.instance.saveRide(finalRide);
      _ref.invalidate(ridesHistoryProvider);
    }

    _reset();
    state = const RideState();
  }

  void _reset() {
    _totalDistanceKm = 0;
    _speedSum = 0;
    _speedCount = 0;
    _maxSpeed = 0;
    _lastLat = null;
    _lastLon = null;
    _speedPoints.clear();
    _hardBrakeCount = 0;
    _zigzagCount = 0;
    _speedVioCount = 0;
    _unsafeDistCount = 0;
    _overtakeCount = 0;
  }

  static double _haversineKm(double lat1, double lon1, double lat2, double lon2) {
    const r = 6371.0;
    final dLat = _rad(lat2 - lat1);
    final dLon = _rad(lon2 - lon1);
    final a = _sin2(dLat / 2) +
        _cos(_rad(lat1)) * _cos(_rad(lat2)) * _sin2(dLon / 2);
    return r * 2 * _asin(_sqrt(a));
  }

  static double _rad(double d) => d * 3.141592653589793 / 180;
  static double _sin2(double x) { final s = _sin(x); return s * s; }
  static double _sin(double x) => x - x*x*x/6 + x*x*x*x*x/120;
  static double _cos(double x) => 1 - x*x/2 + x*x*x*x/24;
  static double _sqrt(double x) {
    if (x <= 0) return 0;
    double g = x / 2;
    for (int i = 0; i < 20; i++) g = (g + x / g) / 2;
    return g;
  }
  static double _asin(double x) {
    x = x.clamp(-1.0, 1.0);
    return x + x*x*x/6 + 3*x*x*x*x*x/40;
  }

  @override
  void dispose() {
    _sensorSub?.cancel();
    _analysisSub?.cancel();
    super.dispose();
  }
}

final rideStateProvider = StateNotifierProvider<RideStateNotifier, RideState>(
  (ref) => RideStateNotifier(ref),
);

// ─── ridesHistoryProvider ─────────────────────────────────────────────────────

class RidesHistoryNotifier extends AsyncNotifier<List<RideModel>> {
  @override
  Future<List<RideModel>> build() => DatabaseService.instance.getRides();

  Future<void> deleteRide(String id) async {
    await DatabaseService.instance.deleteRide(id);
    state = AsyncData(
      (state.valueOrNull ?? []).where((r) => r.id != id).toList(),
    );
  }

  Future<void> clearAll() async {
    await DatabaseService.instance.clearAll();
    state = const AsyncData([]);
  }
}

final ridesHistoryProvider =
    AsyncNotifierProvider<RidesHistoryNotifier, List<RideModel>>(
  RidesHistoryNotifier.new,
);

// Init the analysis sync bridge when the app starts
final appInitProvider = Provider<void>((ref) {
  ref.watch(_analysisSyncProvider);
});
