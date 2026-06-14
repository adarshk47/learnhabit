import 'package:bike_ai_analyzer/models/event_model.dart';

class RideModel {
  final String id;
  final DateTime startTime;
  final DateTime? endTime;
  final double distanceKm;
  final double maxSpeedKmh;
  final double avgSpeedKmh;
  final double? skillScore;
  final double? dangerScore;
  final String? safetyRating;   // A-F string
  final double? aggressionScore;
  final double? accidentProbability;
  final double? smoothness;
  final List<RideEvent> events;
  final String? ridingContext;
  final List<double> speedPoints;
  final List<String> recommendations;

  // Event counters
  final int hardBrakeCount;
  final int zigzagCount;
  final int speedViolationCount;
  final int unsafeDistanceCount;
  final int overtakeCount;

  const RideModel({
    required this.id,
    required this.startTime,
    this.endTime,
    this.distanceKm = 0,
    this.maxSpeedKmh = 0,
    this.avgSpeedKmh = 0,
    this.skillScore,
    this.dangerScore,
    this.safetyRating,
    this.aggressionScore,
    this.accidentProbability,
    this.smoothness,
    this.events = const [],
    this.ridingContext,
    this.speedPoints = const [],
    this.recommendations = const [],
    this.hardBrakeCount = 0,
    this.zigzagCount = 0,
    this.speedViolationCount = 0,
    this.unsafeDistanceCount = 0,
    this.overtakeCount = 0,
  });

  bool get isActive => endTime == null;

  RideModel copyWith({
    DateTime? endTime,
    double? distanceKm,
    double? maxSpeedKmh,
    double? avgSpeedKmh,
    double? skillScore,
    double? dangerScore,
    String? safetyRating,
    double? aggressionScore,
    double? accidentProbability,
    double? smoothness,
    List<RideEvent>? events,
    String? ridingContext,
    List<double>? speedPoints,
    List<String>? recommendations,
    int? hardBrakeCount,
    int? zigzagCount,
    int? speedViolationCount,
    int? unsafeDistanceCount,
    int? overtakeCount,
  }) {
    return RideModel(
      id: id,
      startTime: startTime,
      endTime: endTime ?? this.endTime,
      distanceKm: distanceKm ?? this.distanceKm,
      maxSpeedKmh: maxSpeedKmh ?? this.maxSpeedKmh,
      avgSpeedKmh: avgSpeedKmh ?? this.avgSpeedKmh,
      skillScore: skillScore ?? this.skillScore,
      dangerScore: dangerScore ?? this.dangerScore,
      safetyRating: safetyRating ?? this.safetyRating,
      aggressionScore: aggressionScore ?? this.aggressionScore,
      accidentProbability: accidentProbability ?? this.accidentProbability,
      smoothness: smoothness ?? this.smoothness,
      events: events ?? this.events,
      ridingContext: ridingContext ?? this.ridingContext,
      speedPoints: speedPoints ?? this.speedPoints,
      recommendations: recommendations ?? this.recommendations,
      hardBrakeCount: hardBrakeCount ?? this.hardBrakeCount,
      zigzagCount: zigzagCount ?? this.zigzagCount,
      speedViolationCount: speedViolationCount ?? this.speedViolationCount,
      unsafeDistanceCount: unsafeDistanceCount ?? this.unsafeDistanceCount,
      overtakeCount: overtakeCount ?? this.overtakeCount,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'startTime': startTime.toIso8601String(),
        'endTime': endTime?.toIso8601String(),
        'distanceKm': distanceKm,
        'maxSpeedKmh': maxSpeedKmh,
        'avgSpeedKmh': avgSpeedKmh,
        'skillScore': skillScore,
        'dangerScore': dangerScore,
        'safetyRating': safetyRating,
        'aggressionScore': aggressionScore,
        'accidentProbability': accidentProbability,
        'smoothness': smoothness,
        'ridingContext': ridingContext,
        'hardBrakeCount': hardBrakeCount,
        'zigzagCount': zigzagCount,
        'speedViolationCount': speedViolationCount,
        'unsafeDistanceCount': unsafeDistanceCount,
        'overtakeCount': overtakeCount,
        'recommendations': recommendations,
        'speedPoints': speedPoints,
      };

  factory RideModel.fromJson(Map<String, dynamic> json) {
    final eventsJson = json['events'] as List<dynamic>? ?? [];
    final speedPts = (json['speedPoints'] as List<dynamic>?)
            ?.map((e) => (e as num).toDouble())
            .toList() ??
        [];
    final recs = (json['recommendations'] as List<dynamic>?)
            ?.map((e) => e as String)
            .toList() ??
        [];
    return RideModel(
      id: json['id'] as String,
      startTime: DateTime.parse(json['startTime'] as String),
      endTime: json['endTime'] != null
          ? DateTime.parse(json['endTime'] as String)
          : null,
      distanceKm: (json['distanceKm'] as num?)?.toDouble() ?? 0,
      maxSpeedKmh: (json['maxSpeedKmh'] as num?)?.toDouble() ?? 0,
      avgSpeedKmh: (json['avgSpeedKmh'] as num?)?.toDouble() ?? 0,
      skillScore: (json['skillScore'] as num?)?.toDouble(),
      dangerScore: (json['dangerScore'] as num?)?.toDouble(),
      safetyRating: json['safetyRating'] as String?,
      aggressionScore: (json['aggressionScore'] as num?)?.toDouble(),
      accidentProbability: (json['accidentProbability'] as num?)?.toDouble(),
      smoothness: (json['smoothness'] as num?)?.toDouble(),
      ridingContext: json['ridingContext'] as String?,
      events: eventsJson
          .map((e) => RideEvent.fromJson(e as Map<String, dynamic>))
          .toList(),
      speedPoints: speedPts,
      recommendations: recs,
      hardBrakeCount: (json['hardBrakeCount'] as num?)?.toInt() ?? 0,
      zigzagCount: (json['zigzagCount'] as num?)?.toInt() ?? 0,
      speedViolationCount: (json['speedViolationCount'] as num?)?.toInt() ?? 0,
      unsafeDistanceCount: (json['unsafeDistanceCount'] as num?)?.toInt() ?? 0,
      overtakeCount: (json['overtakeCount'] as num?)?.toInt() ?? 0,
    );
  }

  static RideModel empty() => RideModel(
        id: '',
        startTime: DateTime.now(),
      );
}

// Legacy alias so existing code using `Ride` still compiles
typedef Ride = RideModel;
