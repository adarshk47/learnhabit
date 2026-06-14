class AppConstants {
  AppConstants._();

  // Backend
  static const String defaultBackendUrl = 'ws://192.168.1.100:8000';
  static const String wsAnalysisEndpoint = '/ws/analyze';
  static const String httpBaseUrl = 'http://192.168.1.100:8000';
  static const String apiRidesEndpoint = '/api/rides';

  // Sensor
  static const int sensorSampleRateHz = 50;
  static const int videoFrameRateHz = 10;
  static const int reconnectBaseDelayMs = 1000;
  static const int maxReconnectAttempts = 10;

  // Speed / Danger thresholds
  static const double speedingThresholdKmh = 80.0;
  static const double dangerousSpeedThresholdKmh = 100.0;
  static const double hardBrakingThresholdG = 0.5;
  static const double zigzagThresholdDegPerSec = 45.0;

  // Score thresholds
  static const double excellentScoreThreshold = 85.0;
  static const double goodScoreThreshold = 70.0;
  static const double fairScoreThreshold = 50.0;

  // Detection classes
  static const List<String> detectionClasses = [
    'car',
    'truck',
    'bus',
    'motorcycle',
    'bicycle',
    'pedestrian',
    'traffic_light',
    'stop_sign',
    'speed_limit_sign',
  ];

  // Event descriptions
  static const Map<String, String> eventDescriptions = {
    'SPEEDING': 'Vehicle speed exceeded safe limit',
    'HARD_BRAKING': 'Sudden hard braking detected',
    'UNSAFE_OVERTAKING': 'Unsafe overtaking maneuver detected',
    'ZIG_ZAG': 'Erratic zig-zag riding pattern detected',
    'UNSAFE_DISTANCE': 'Insufficient following distance',
    'LANE_CHANGE': 'Abrupt lane change detected',
    'RED_LIGHT': 'Traffic signal violation detected',
  };

  // DB
  static const String dbName = 'bike_analyzer.db';
  static const int dbVersion = 1;

  // TTS rate limit ms
  static const int ttsRateLimitMs = 5000;
}
