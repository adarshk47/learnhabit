class DetectedObject {
  final String className;
  final double confidence;
  final List<int> bbox;        // [x1, y1, x2, y2] in pixels (640x480 space)
  final double? distanceM;
  final int? trackId;

  const DetectedObject({
    required this.className,
    required this.confidence,
    this.bbox = const [0, 0, 0, 0],
    this.distanceM,
    this.trackId,
  });

  factory DetectedObject.fromJson(Map<String, dynamic> json) {
    final rawBbox = json['bbox'] as List<dynamic>? ?? [];
    return DetectedObject(
      className: json['class_name'] as String? ??
          json['class'] as String? ??
          'unknown',
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.0,
      bbox: rawBbox.length >= 4
          ? rawBbox.take(4).map((e) => (e as num).toInt()).toList()
          : [0, 0, 0, 0],
      distanceM: (json['distance_m'] as num?)?.toDouble(),
      trackId: (json['track_id'] as num?)?.toInt(),
    );
  }
}

class AnalysisResult {
  final double speed;            // km/h
  final double skillScore;       // 0-100
  final double dangerScore;      // 0-100
  final String safetyRating;     // A-F
  final double aggressionScore;  // 0-100
  final double accidentProbability; // 0-1
  final double smoothness;       // 0-100
  final List<DetectedObject> detectedObjects;
  final double trafficDensity;   // 0-1
  final double laneDeviation;    // pixels
  final bool oncomingVehicle;
  final String ridingContext;
  final List<String> warnings;
  final List<String> voiceAlerts;
  final double leanAngle;        // degrees
  final DateTime timestamp;

  // Legacy compatibility aliases
  double get currentSpeed => speed;
  double get rideScore => skillScore;
  List<String> get activeEvents => warnings;
  List<String> get warningMessages => voiceAlerts;

  const AnalysisResult({
    this.speed = 0,
    this.skillScore = 100,
    this.dangerScore = 0,
    this.safetyRating = 'A',
    this.aggressionScore = 0,
    this.accidentProbability = 0,
    this.smoothness = 100,
    this.detectedObjects = const [],
    this.trafficDensity = 0,
    this.laneDeviation = 0,
    this.oncomingVehicle = false,
    this.ridingContext = 'UNKNOWN',
    this.warnings = const [],
    this.voiceAlerts = const [],
    this.leanAngle = 0,
    required this.timestamp,
  });

  factory AnalysisResult.fromJson(Map<String, dynamic> json) {
    final objects = (json['detected_objects'] as List<dynamic>?)
            ?.map((e) => DetectedObject.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [];
    final warnings = (json['warnings'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        [];
    final alerts = (json['voice_alerts'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        [];

    return AnalysisResult(
      speed: (json['speed_kmh'] as num?)?.toDouble() ??
          (json['speed'] as num?)?.toDouble() ??
          0,
      skillScore: (json['skill_score'] as num?)?.toDouble() ??
          (json['ride_score'] as num?)?.toDouble() ??
          100,
      dangerScore: (json['danger_score'] as num?)?.toDouble() ?? 0,
      safetyRating: json['safety_rating'] as String? ?? 'A',
      aggressionScore: (json['aggression_score'] as num?)?.toDouble() ?? 0,
      accidentProbability:
          (json['accident_probability'] as num?)?.toDouble() ?? 0,
      smoothness: (json['smoothness'] as num?)?.toDouble() ?? 100,
      detectedObjects: objects,
      trafficDensity: (json['traffic_density'] as num?)?.toDouble() ?? 0,
      laneDeviation: (json['lane_deviation'] as num?)?.toDouble() ?? 0,
      oncomingVehicle: json['oncoming_vehicle'] as bool? ?? false,
      ridingContext: json['riding_context'] as String? ?? 'UNKNOWN',
      warnings: warnings,
      voiceAlerts: alerts,
      leanAngle: (json['lean_angle'] as num?)?.toDouble() ?? 0,
      timestamp: DateTime.now(),
    );
  }

  static AnalysisResult empty() => AnalysisResult(timestamp: DateTime.now());
}
