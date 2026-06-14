class SensorData {
  final double accX;
  final double accY;
  final double accZ;
  final double gyroX;
  final double gyroY;
  final double gyroZ;
  final double? latitude;
  final double? longitude;
  final double speedKmh;
  final double heading;
  final DateTime timestamp;

  const SensorData({
    required this.accX,
    required this.accY,
    required this.accZ,
    required this.gyroX,
    required this.gyroY,
    required this.gyroZ,
    this.latitude,
    this.longitude,
    required this.speedKmh,
    required this.heading,
    required this.timestamp,
  });

  double get accelerationMagnitude {
    return (accX * accX + accY * accY + accZ * accZ);
  }

  double get gyroMagnitude {
    return (gyroX * gyroX + gyroY * gyroY + gyroZ * gyroZ);
  }

  Map<String, dynamic> toJson() => {
        'acc_x': accX,
        'acc_y': accY,
        'acc_z': accZ,
        'gyro_x': gyroX,
        'gyro_y': gyroY,
        'gyro_z': gyroZ,
        'latitude': latitude,
        'longitude': longitude,
        'speed_kmh': speedKmh,
        'heading': heading,
        'timestamp': timestamp.toIso8601String(),
      };

  factory SensorData.fromJson(Map<String, dynamic> json) => SensorData(
        accX: (json['acc_x'] as num?)?.toDouble() ?? 0,
        accY: (json['acc_y'] as num?)?.toDouble() ?? 0,
        accZ: (json['acc_z'] as num?)?.toDouble() ?? 0,
        gyroX: (json['gyro_x'] as num?)?.toDouble() ?? 0,
        gyroY: (json['gyro_y'] as num?)?.toDouble() ?? 0,
        gyroZ: (json['gyro_z'] as num?)?.toDouble() ?? 0,
        latitude: (json['latitude'] as num?)?.toDouble(),
        longitude: (json['longitude'] as num?)?.toDouble(),
        speedKmh: (json['speed_kmh'] as num?)?.toDouble() ?? 0,
        heading: (json['heading'] as num?)?.toDouble() ?? 0,
        timestamp: json['timestamp'] != null
            ? DateTime.parse(json['timestamp'] as String)
            : DateTime.now(),
      );

  SensorData copyWith({
    double? accX,
    double? accY,
    double? accZ,
    double? gyroX,
    double? gyroY,
    double? gyroZ,
    double? latitude,
    double? longitude,
    double? speedKmh,
    double? heading,
    DateTime? timestamp,
  }) {
    return SensorData(
      accX: accX ?? this.accX,
      accY: accY ?? this.accY,
      accZ: accZ ?? this.accZ,
      gyroX: gyroX ?? this.gyroX,
      gyroY: gyroY ?? this.gyroY,
      gyroZ: gyroZ ?? this.gyroZ,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      speedKmh: speedKmh ?? this.speedKmh,
      heading: heading ?? this.heading,
      timestamp: timestamp ?? this.timestamp,
    );
  }
}
