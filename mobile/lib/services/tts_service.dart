import 'dart:async';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:bike_ai_analyzer/core/constants/app_constants.dart';

enum AlertType {
  SLOW_DOWN,
  UNSAFE_OVERTAKING,
  HARD_BRAKING,
  MAINTAIN_DISTANCE,
  ZIG_ZAG_DETECTED,
  RED_LIGHT_AHEAD,
  SPEED_LIMIT_EXCEEDED,
}

extension AlertTypeMessage on AlertType {
  String get message {
    switch (this) {
      case AlertType.SLOW_DOWN:
        return 'Please slow down. You are exceeding the safe speed limit.';
      case AlertType.UNSAFE_OVERTAKING:
        return 'Warning! Unsafe overtaking detected. Please be careful.';
      case AlertType.HARD_BRAKING:
        return 'Hard braking detected. Maintain safe following distance.';
      case AlertType.MAINTAIN_DISTANCE:
        return 'Warning! Maintain safe distance from the vehicle ahead.';
      case AlertType.ZIG_ZAG_DETECTED:
        return 'Erratic riding detected. Please ride in a straight line.';
      case AlertType.RED_LIGHT_AHEAD:
        return 'Red light ahead. Prepare to stop.';
      case AlertType.SPEED_LIMIT_EXCEEDED:
        return 'Speed limit exceeded. Reduce speed immediately.';
    }
  }

  bool get isHighPriority {
    return this == AlertType.HARD_BRAKING ||
        this == AlertType.UNSAFE_OVERTAKING ||
        this == AlertType.RED_LIGHT_AHEAD;
  }
}

class TtsService {
  static final TtsService instance = TtsService._();
  TtsService._();

  final FlutterTts _tts = FlutterTts();
  final Map<AlertType, DateTime> _lastSpoken = {};
  bool _enabled = true;
  double _volume = 0.8;
  bool _isSpeaking = false;

  final _queue = <AlertType>[];
  Timer? _processTimer;

  Future<void> init() async {
    await _tts.setLanguage('en-US');
    await _tts.setSpeechRate(0.5);
    await _tts.setVolume(_volume);
    await _tts.setPitch(1.0);

    _tts.setCompletionHandler(() {
      _isSpeaking = false;
      _processQueue();
    });
  }

  void setEnabled(bool enabled) {
    _enabled = enabled;
    if (!enabled) {
      _tts.stop();
      _queue.clear();
    }
  }

  void setVolume(double volume) {
    _volume = volume.clamp(0.0, 1.0);
    _tts.setVolume(_volume);
  }

  void speak(AlertType type) {
    if (!_enabled) return;

    final now = DateTime.now();
    final last = _lastSpoken[type];

    final withinRateLimit = last != null &&
        now.difference(last).inMilliseconds < AppConstants.ttsRateLimitMs;

    if (withinRateLimit && !type.isHighPriority) return;

    // High priority - insert at front of queue
    if (type.isHighPriority) {
      _queue.insert(0, type);
    } else {
      if (!_queue.contains(type)) {
        _queue.add(type);
      }
    }

    _lastSpoken[type] = now;
    _processQueue();
  }

  void _processQueue() {
    if (_isSpeaking || _queue.isEmpty || !_enabled) return;
    final next = _queue.removeAt(0);
    _isSpeaking = true;
    _tts.speak(next.message);
  }

  void speakQueue(List<String> messages) {
    if (!_enabled || messages.isEmpty) return;
    for (final msg in messages) {
      _tts.speak(msg);
    }
  }

  Future<void> dispose() async {
    _processTimer?.cancel();
    await _tts.stop();
  }
}
