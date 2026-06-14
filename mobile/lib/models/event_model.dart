import 'dart:convert';

enum EventType {
  SPEEDING,
  HARD_BRAKING,
  UNSAFE_OVERTAKING,
  ZIG_ZAG,
  UNSAFE_DISTANCE,
  LANE_CHANGE,
  RED_LIGHT,
}

enum EventSeverity { LOW, MEDIUM, HIGH, CRITICAL }

extension EventTypeExt on EventType {
  String get label {
    switch (this) {
      case EventType.SPEEDING:
        return 'Speeding';
      case EventType.HARD_BRAKING:
        return 'Hard Braking';
      case EventType.UNSAFE_OVERTAKING:
        return 'Unsafe Overtaking';
      case EventType.ZIG_ZAG:
        return 'Zig-Zag';
      case EventType.UNSAFE_DISTANCE:
        return 'Unsafe Distance';
      case EventType.LANE_CHANGE:
        return 'Abrupt Lane Change';
      case EventType.RED_LIGHT:
        return 'Red Light';
    }
  }

  String get icon {
    switch (this) {
      case EventType.SPEEDING:
        return '⚡';
      case EventType.HARD_BRAKING:
        return '🛑';
      case EventType.UNSAFE_OVERTAKING:
        return '⚠️';
      case EventType.ZIG_ZAG:
        return '〰️';
      case EventType.UNSAFE_DISTANCE:
        return '📏';
      case EventType.LANE_CHANGE:
        return '↔️';
      case EventType.RED_LIGHT:
        return '🚦';
    }
  }
}

extension EventSeverityExt on EventSeverity {
  String get label {
    switch (this) {
      case EventSeverity.LOW:
        return 'Low';
      case EventSeverity.MEDIUM:
        return 'Medium';
      case EventSeverity.HIGH:
        return 'High';
      case EventSeverity.CRITICAL:
        return 'Critical';
    }
  }
}

class RideEvent {
  final String id;
  final String type;        // raw string e.g. "SPEEDING"
  final String severity;    // "LOW" | "MEDIUM" | "HIGH" | "CRITICAL"
  final DateTime timestamp;
  final double? latitude;
  final double? longitude;
  final String description;
  final Map<String, dynamic> metadata;

  const RideEvent({
    required this.id,
    required this.type,
    this.severity = 'LOW',
    required this.timestamp,
    this.latitude,
    this.longitude,
    this.description = '',
    this.metadata = const {},
  });

  factory RideEvent.fromJson(Map<String, dynamic> json) {
    return RideEvent(
      id: json['id'] as String? ?? '',
      type: json['type'] as String? ?? 'UNKNOWN',
      severity: json['severity'] as String? ?? 'LOW',
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'] as String)
          : DateTime.now(),
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      description: json['description'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type,
        'severity': severity,
        'timestamp': timestamp.toIso8601String(),
        'latitude': latitude,
        'longitude': longitude,
        'description': description,
      };
}

// Legacy alias so existing code keeps compiling
class RidingEvent {
  final String id;
  final EventType type;
  final DateTime timestamp;
  final EventSeverity severity;
  final double? latitude;
  final double? longitude;
  final String description;
  final Map<String, dynamic> metadata;

  const RidingEvent({
    required this.id,
    required this.type,
    required this.timestamp,
    required this.severity,
    this.latitude,
    this.longitude,
    required this.description,
    this.metadata = const {},
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.name,
        'timestamp': timestamp.toIso8601String(),
        'severity': severity.name,
        'latitude': latitude,
        'longitude': longitude,
        'description': description,
        'metadata': jsonEncode(metadata),
      };

  factory RidingEvent.fromJson(Map<String, dynamic> json) {
    final metaRaw = json['metadata'];
    final Map<String, dynamic> meta = metaRaw is String
        ? (jsonDecode(metaRaw) as Map<String, dynamic>)
        : (metaRaw as Map<String, dynamic>? ?? {});

    return RidingEvent(
      id: json['id'] as String,
      type: EventType.values.firstWhere(
        (e) => e.name == (json['type'] as String),
        orElse: () => EventType.SPEEDING,
      ),
      timestamp: DateTime.parse(json['timestamp'] as String),
      severity: EventSeverity.values.firstWhere(
        (e) => e.name == (json['severity'] as String),
        orElse: () => EventSeverity.LOW,
      ),
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      description: json['description'] as String? ?? '',
      metadata: meta,
    );
  }
}
