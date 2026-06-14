import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../models/ride_model.dart';
import '../models/event_model.dart';
import '../core/constants/app_constants.dart';

class DatabaseService {
  static final DatabaseService instance = DatabaseService._();
  DatabaseService._();

  Database? _db;

  Future<void> init() async {
    _db ??= await _open();
  }

  Future<Database> get database async {
    _db ??= await _open();
    return _db!;
  }

  Future<Database> _open() async {
    final dir = await getApplicationDocumentsDirectory();
    final path = p.join(dir.path, AppConstants.dbName);
    return openDatabase(path, version: 2, onCreate: _onCreate, onUpgrade: _onUpgrade);
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE rides (
        id TEXT PRIMARY KEY,
        startTime TEXT NOT NULL,
        endTime TEXT,
        distanceKm REAL DEFAULT 0,
        maxSpeedKmh REAL DEFAULT 0,
        avgSpeedKmh REAL DEFAULT 0,
        skillScore REAL,
        dangerScore REAL,
        safetyRating TEXT,
        aggressionScore REAL,
        accidentProbability REAL,
        smoothness REAL,
        ridingContext TEXT,
        hardBrakeCount INTEGER DEFAULT 0,
        zigzagCount INTEGER DEFAULT 0,
        speedViolationCount INTEGER DEFAULT 0,
        unsafeDistanceCount INTEGER DEFAULT 0,
        overtakeCount INTEGER DEFAULT 0,
        speedPointsJson TEXT DEFAULT '[]',
        recommendationsJson TEXT DEFAULT '[]'
      )
    ''');
    await db.execute('''
      CREATE TABLE events (
        id TEXT PRIMARY KEY,
        rideId TEXT NOT NULL,
        type TEXT NOT NULL,
        severity TEXT NOT NULL DEFAULT 'LOW',
        timestamp TEXT NOT NULL,
        latitude REAL,
        longitude REAL,
        description TEXT DEFAULT '',
        FOREIGN KEY (rideId) REFERENCES rides(id) ON DELETE CASCADE
      )
    ''');
  }

  Future<void> _onUpgrade(Database db, int old, int newV) async {
    if (old < 2) {
      await db.execute('DROP TABLE IF EXISTS rides');
      await db.execute('DROP TABLE IF EXISTS events');
      await _onCreate(db, newV);
    }
  }

  Future<void> saveRide(RideModel ride) async {
    final db = await database;
    final row = {
      'id': ride.id,
      'startTime': ride.startTime.toIso8601String(),
      'endTime': ride.endTime?.toIso8601String(),
      'distanceKm': ride.distanceKm,
      'maxSpeedKmh': ride.maxSpeedKmh,
      'avgSpeedKmh': ride.avgSpeedKmh,
      'skillScore': ride.skillScore,
      'dangerScore': ride.dangerScore,
      'safetyRating': ride.safetyRating,
      'aggressionScore': ride.aggressionScore,
      'accidentProbability': ride.accidentProbability,
      'smoothness': ride.smoothness,
      'ridingContext': ride.ridingContext,
      'hardBrakeCount': ride.hardBrakeCount,
      'zigzagCount': ride.zigzagCount,
      'speedViolationCount': ride.speedViolationCount,
      'unsafeDistanceCount': ride.unsafeDistanceCount,
      'overtakeCount': ride.overtakeCount,
      'speedPointsJson': jsonEncode(ride.speedPoints),
      'recommendationsJson': jsonEncode(ride.recommendations),
    };
    await db.insert('rides', row, conflictAlgorithm: ConflictAlgorithm.replace);

    for (final ev in ride.events) {
      await _insertEvent(db, ev, ride.id);
    }
  }

  Future<void> _insertEvent(Database db, RideEvent ev, String rideId) async {
    await db.insert('events', {
      'id': ev.id,
      'rideId': rideId,
      'type': ev.type,
      'severity': ev.severity,
      'timestamp': ev.timestamp.toIso8601String(),
      'latitude': ev.latitude,
      'longitude': ev.longitude,
      'description': ev.description,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<RideModel>> getRides() async {
    final db = await database;
    final rows = await db.query('rides', orderBy: 'startTime DESC');
    final rides = <RideModel>[];
    for (final row in rows) {
      final events = await _getEvents(db, row['id'] as String);
      rides.add(_rowToRide(row, events));
    }
    return rides;
  }

  Future<RideModel?> getRideById(String id) async {
    final db = await database;
    final rows = await db.query('rides', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    final events = await _getEvents(db, id);
    return _rowToRide(rows.first, events);
  }

  Future<List<RideEvent>> _getEvents(Database db, String rideId) async {
    final rows = await db.query('events',
        where: 'rideId = ?', whereArgs: [rideId], orderBy: 'timestamp ASC');
    return rows.map((r) => RideEvent(
          id: r['id'] as String,
          type: r['type'] as String,
          severity: r['severity'] as String? ?? 'LOW',
          timestamp: DateTime.parse(r['timestamp'] as String),
          latitude: r['latitude'] as double?,
          longitude: r['longitude'] as double?,
          description: r['description'] as String? ?? '',
        )).toList();
  }

  RideModel _rowToRide(Map<String, dynamic> row, List<RideEvent> events) {
    final speedPts = (jsonDecode(row['speedPointsJson'] as String? ?? '[]') as List)
        .map((e) => (e as num).toDouble())
        .toList();
    final recs = (jsonDecode(row['recommendationsJson'] as String? ?? '[]') as List)
        .map((e) => e as String)
        .toList();
    return RideModel(
      id: row['id'] as String,
      startTime: DateTime.parse(row['startTime'] as String),
      endTime: row['endTime'] != null ? DateTime.parse(row['endTime'] as String) : null,
      distanceKm: (row['distanceKm'] as num?)?.toDouble() ?? 0,
      maxSpeedKmh: (row['maxSpeedKmh'] as num?)?.toDouble() ?? 0,
      avgSpeedKmh: (row['avgSpeedKmh'] as num?)?.toDouble() ?? 0,
      skillScore: (row['skillScore'] as num?)?.toDouble(),
      dangerScore: (row['dangerScore'] as num?)?.toDouble(),
      safetyRating: row['safetyRating'] as String?,
      aggressionScore: (row['aggressionScore'] as num?)?.toDouble(),
      accidentProbability: (row['accidentProbability'] as num?)?.toDouble(),
      smoothness: (row['smoothness'] as num?)?.toDouble(),
      ridingContext: row['ridingContext'] as String?,
      hardBrakeCount: (row['hardBrakeCount'] as num?)?.toInt() ?? 0,
      zigzagCount: (row['zigzagCount'] as num?)?.toInt() ?? 0,
      speedViolationCount: (row['speedViolationCount'] as num?)?.toInt() ?? 0,
      unsafeDistanceCount: (row['unsafeDistanceCount'] as num?)?.toInt() ?? 0,
      overtakeCount: (row['overtakeCount'] as num?)?.toInt() ?? 0,
      speedPoints: speedPts,
      recommendations: recs,
      events: events,
    );
  }

  Future<void> deleteRide(String id) async {
    final db = await database;
    await db.delete('rides', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> clearAll() async {
    final db = await database;
    await db.delete('events');
    await db.delete('rides');
  }
}
