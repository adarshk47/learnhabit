import 'dart:async';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:geolocator/geolocator.dart';
import 'package:bike_ai_analyzer/models/sensor_data.dart';

class SensorService {
  static final SensorService instance = SensorService._();
  SensorService._();

  final _sensorController = StreamController<SensorData>.broadcast();

  double _accX = 0, _accY = 0, _accZ = 0;
  double _gyroX = 0, _gyroY = 0, _gyroZ = 0;
  double? _latitude, _longitude;
  double _speedKmh = 0;
  double _heading = 0;

  // For deriving speed from position deltas when position.speed is unavailable.
  Position? _lastFixPos;
  DateTime? _lastFixTime;

  StreamSubscription? _accelSub;
  StreamSubscription? _gyroSub;
  StreamSubscription<Position>? _gpsSub;
  Timer? _fusionTimer;

  bool _isRunning = false;

  Stream<SensorData> get sensorStream => _sensorController.stream;
  bool get isRunning => _isRunning;

  Future<bool> start() async {
    if (_isRunning) return true;

    // Check if device location service is on
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return false;

    // Check GPS permissions
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return false;
      }
    }
    if (permission == LocationPermission.deniedForever) {
      return false;
    }

    // Accelerometer
    _accelSub = accelerometerEventStream(
      samplingPeriod: SensorInterval.gameInterval,
    ).listen((AccelerometerEvent event) {
      _accX = event.x;
      _accY = event.y;
      _accZ = event.z;
    });

    // Gyroscope
    _gyroSub = gyroscopeEventStream(
      samplingPeriod: SensorInterval.gameInterval,
    ).listen((GyroscopeEvent event) {
      _gyroX = event.x;
      _gyroY = event.y;
      _gyroZ = event.z;
    });

    // GPS
    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.bestForNavigation,
      distanceFilter: 0, // emit on every fix so speed updates smoothly
    );
    _gpsSub = Geolocator.getPositionStream(locationSettings: locationSettings)
        .listen((Position position) {
      _latitude = position.latitude;
      _longitude = position.longitude;
      _heading = position.heading;

      // Primary source: the GPS-reported speed (m/s -> km/h).
      double speedKmh = (position.speed.isFinite && position.speed > 0)
          ? position.speed * 3.6
          : 0;

      // Fallback: some Android devices never populate position.speed, so derive
      // speed from the distance/time between consecutive fixes.
      final now = DateTime.now();
      if (_lastFixPos != null && _lastFixTime != null) {
        final dtSec = now.difference(_lastFixTime!).inMilliseconds / 1000.0;
        if (dtSec > 0) {
          final distM = Geolocator.distanceBetween(
            _lastFixPos!.latitude,
            _lastFixPos!.longitude,
            position.latitude,
            position.longitude,
          );
          final derived = (distM / dtSec) * 3.6;
          // Use the derived value only when GPS didn't give us a usable one
          // and the movement is above GPS jitter (~ a few meters).
          if (speedKmh <= 0 && distM > 1.5 && derived.isFinite) {
            speedKmh = derived;
          }
        }
      }
      _lastFixPos = position;
      _lastFixTime = now;

      _speedKmh = speedKmh.clamp(0, 400);
    });

    // Fusion timer - publish at ~50Hz
    _fusionTimer = Timer.periodic(
      const Duration(milliseconds: 20),
      (_) => _publishSensorData(),
    );

    _isRunning = true;
    return true;
  }

  void _publishSensorData() {
    if (_sensorController.isClosed) return;
    final data = SensorData(
      accX: _accX,
      accY: _accY,
      accZ: _accZ,
      gyroX: _gyroX,
      gyroY: _gyroY,
      gyroZ: _gyroZ,
      latitude: _latitude,
      longitude: _longitude,
      speedKmh: _speedKmh,
      heading: _heading,
      timestamp: DateTime.now(),
    );
    _sensorController.add(data);
  }

  void stop() {
    _fusionTimer?.cancel();
    _accelSub?.cancel();
    _gyroSub?.cancel();
    _gpsSub?.cancel();
    _fusionTimer = null;
    _accelSub = null;
    _gyroSub = null;
    _gpsSub = null;
    _lastFixPos = null;
    _lastFixTime = null;
    _speedKmh = 0;
    _isRunning = false;
  }

  void dispose() {
    stop();
    _sensorController.close();
  }
}
