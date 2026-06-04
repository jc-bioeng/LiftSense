import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../../domain/models/db_models.dart';

class DatabaseProvider {
  static final DatabaseProvider _instance = DatabaseProvider._internal();
  factory DatabaseProvider() => _instance;
  DatabaseProvider._internal();

  Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDb();
    return _database!;
  }

  Future<Database> _initDb() async {
    String dbPath = join(await getDatabasesPath(), 'liftsense_v1.db');
    return await openDatabase(
      dbPath,
      version: 1,
      onCreate: _onCreate,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // 1. Users
    await db.execute('''
      CREATE TABLE users (
        id TEXT PRIMARY KEY,
        email TEXT,
        created_at INTEGER
      )
    ''');

    // 2. Sessions
    await db.execute('''
      CREATE TABLE sessions (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        start_time INTEGER NOT NULL,
        notes TEXT,
        is_synced INTEGER DEFAULT 0,
        FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
      )
    ''');

    // 3. Videos
    await db.execute('''
      CREATE TABLE videos (
        id TEXT PRIMARY KEY,
        session_id TEXT NOT NULL,
        file_path TEXT NOT NULL,
        fps REAL NOT NULL,
        resolution TEXT,
        FOREIGN KEY (session_id) REFERENCES sessions(id) ON DELETE CASCADE
      )
    ''');

    // 4. Sets
    await db.execute('''
      CREATE TABLE sets (
        id TEXT PRIMARY KEY,
        session_id TEXT NOT NULL,
        video_id TEXT NOT NULL,
        exercise_type TEXT NOT NULL,
        view_type TEXT NOT NULL,
        weight_kg REAL,
        FOREIGN KEY (session_id) REFERENCES sessions(id) ON DELETE CASCADE,
        FOREIGN KEY (video_id) REFERENCES videos(id) ON DELETE CASCADE
      )
    ''');

    // 5. Repetitions
    await db.execute('''
      CREATE TABLE repetitions (
        id TEXT PRIMARY KEY,
        set_id TEXT NOT NULL,
        rep_number INTEGER NOT NULL,
        start_time_ms INTEGER NOT NULL,
        end_time_ms INTEGER NOT NULL,
        max_depth_cm REAL,
        max_concentric_velocity REAL,
        min_hip_knee_ratio REAL,
        is_valid INTEGER DEFAULT 1,
        FOREIGN KEY (set_id) REFERENCES sets(id) ON DELETE CASCADE
      )
    ''');

    // 6. Frame Metrics (Time Series)
    await db.execute('''
      CREATE TABLE frame_metrics (
        id TEXT PRIMARY KEY,
        set_id TEXT NOT NULL,
        time_ms INTEGER NOT NULL,
        phase TEXT NOT NULL,
        warning_level TEXT NOT NULL,
        vertical_velocity REAL,
        left_knee_angle REAL,
        right_knee_angle REAL,
        left_hip_angle REAL,
        right_hip_angle REAL,
        trunk_angle REAL,
        tibia_angle REAL,
        com_projection REAL,
        hip_knee_ratio REAL,
        valgus_angle REAL,
        asymmetry_index REAL,
        landmarks_blob BLOB,
        FOREIGN KEY (set_id) REFERENCES sets(id) ON DELETE CASCADE
      )
    ''');

    // 7. Alerts
    await db.execute('''
      CREATE TABLE alerts (
        id TEXT PRIMARY KEY,
        set_id TEXT NOT NULL,
        rep_id TEXT,
        time_ms INTEGER NOT NULL,
        alert_type TEXT NOT NULL,
        severity TEXT NOT NULL,
        description TEXT,
        FOREIGN KEY (set_id) REFERENCES sets(id) ON DELETE CASCADE,
        FOREIGN KEY (rep_id) REFERENCES repetitions(id) ON DELETE CASCADE
      )
    ''');

    // Indices
    await db.execute('CREATE INDEX idx_frame_timeline ON frame_metrics(set_id, time_ms)');
    await db.execute('CREATE INDEX idx_alerts_set ON alerts(set_id, severity)');
    await db.execute('CREATE INDEX idx_sessions_sync ON sessions(is_synced)');
  }

  // =========================================================================
  // BATCH INSERTS PARA ALTO RENDIMIENTO (60fps)
  // =========================================================================

  Future<void> insertFrameMetricsBatch(List<FrameMetric> metrics) async {
    final db = await database;
    Batch batch = db.batch();
    
    for (var metric in metrics) {
      batch.insert(
        'frame_metrics', 
        metric.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace
      );
    }
    
    // Ejecutar la transacción en bloque para evitar el overhead de SQLite por fila
    await batch.commit(noResult: true);
  }

  // Consultas de playback
  Future<List<FrameMetric>> getTimelineForSet(String setId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'frame_metrics',
      where: 'set_id = ?',
      whereArgs: [setId],
      orderBy: 'time_ms ASC'
    );
    
    // TODO: Mapear maps a objetos FrameMetric
    return []; 
  }
}
