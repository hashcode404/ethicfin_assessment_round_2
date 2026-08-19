import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '../../domain/entities/task.dart';
import '../models/task_model.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('tasks.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 2,
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE tasks (
        id TEXT PRIMARY KEY,
        userId TEXT NOT NULL DEFAULT 'guest_user',
        title TEXT NOT NULL,
        description TEXT,
        priority TEXT NOT NULL,
        dueDate TEXT NOT NULL,
        isCompleted INTEGER NOT NULL,
        createdAt TEXT NOT NULL,
        syncStatus TEXT NOT NULL,
        lastModifiedAt TEXT NOT NULL
      )
    ''');
  }

  Future<void> _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Add userId column with default value
      await db.execute(
        "ALTER TABLE tasks ADD COLUMN userId TEXT NOT NULL DEFAULT 'guest_user'"
      );
    }
  }

  Future<int> insertTask(Task task) async {
    final db = await database;
    final model = task is TaskModel ? task : TaskModel.fromEntity(task);
    return await db.insert(
      'tasks',
      model.toLocalMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<int> updateTask(Task task) async {
    final db = await database;
    final model = task is TaskModel ? task : TaskModel.fromEntity(task);
    return await db.update(
      'tasks',
      model.toLocalMap(),
      where: 'id = ?',
      whereArgs: [task.id],
    );
  }

  Future<TaskModel?> getTaskById(String id) async {
    final db = await database;
    final maps = await db.query(
      'tasks',
      where: 'id = ?',
      whereArgs: [id],
    );

    if (maps.isNotEmpty) {
      return TaskModel.fromLocalMap(maps.first);
    }
    return null;
  }

  // Returns tasks that are NOT pending deletion (for displaying in the UI)
  Future<List<TaskModel>> getTasks(String userId) async {
    final db = await database;
    final result = await db.query(
      'tasks',
      where: "userId = ? AND syncStatus != 'pendingDelete'",
      whereArgs: [userId],
    );
    return result.map((json) => TaskModel.fromLocalMap(json)).toList();
  }

  // Returns all tasks in local DB, including those marked as pending delete
  Future<List<TaskModel>> getAllTasksRaw({String? userId}) async {
    final db = await database;
    if (userId != null) {
      final result = await db.query(
        'tasks',
        where: "userId = ?",
        whereArgs: [userId],
      );
      return result.map((json) => TaskModel.fromLocalMap(json)).toList();
    } else {
      final result = await db.query('tasks');
      return result.map((json) => TaskModel.fromLocalMap(json)).toList();
    }
  }

  // Returns tasks that need sync (i.e. status is not 'synced')
  Future<List<TaskModel>> getPendingTasks(String userId) async {
    final db = await database;
    final result = await db.query(
      'tasks',
      where: "userId = ? AND syncStatus != 'synced'",
      whereArgs: [userId],
    );
    return result.map((json) => TaskModel.fromLocalMap(json)).toList();
  }

  Future<int> markTaskAsPendingDelete(String id, DateTime lastModifiedAt) async {
    final db = await database;
    return await db.update(
      'tasks',
      {
        'syncStatus': 'pendingDelete',
        'lastModifiedAt': lastModifiedAt.toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deletePermanently(String id) async {
    final db = await database;
    return await db.delete(
      'tasks',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> clearTasksForUser(String userId) async {
    final db = await database;
    await db.delete(
      'tasks',
      where: 'userId = ?',
      whereArgs: [userId],
    );
  }

  Future<void> clearAllTasks() async {
    final db = await database;
    await db.delete('tasks');
  }

  Future<void> close() async {
    final db = await database;
    db.close();
  }
}
