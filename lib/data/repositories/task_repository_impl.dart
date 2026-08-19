import 'package:flutter/foundation.dart';
import '../../core/errors/exceptions.dart';
import '../../core/network/network_info.dart';
import '../../domain/entities/task.dart';
import '../../domain/repositories/task_repository.dart';
import '../local/database_helper.dart';
import '../models/task_model.dart';
import '../remote/firestore_service.dart';

class TaskRepositoryImpl implements TaskRepository {
  final DatabaseHelper _dbHelper;
  final FirestoreService _firestoreService;
  final NetworkInfo _networkInfo;
  final bool _isFirebaseAvailable;
  final String Function() _userIdProvider;

  TaskRepositoryImpl({
    required DatabaseHelper dbHelper,
    required FirestoreService firestoreService,
    required NetworkInfo networkInfo,
    required bool isFirebaseAvailable,
    required String Function() userIdProvider,
  })  : _dbHelper = dbHelper,
        _firestoreService = firestoreService,
        _networkInfo = networkInfo,
        _isFirebaseAvailable = isFirebaseAvailable,
        _userIdProvider = userIdProvider;

  String get _currentUserId => _userIdProvider();

  @override
  Future<List<Task>> getTasks() async {
    try {
      return await _dbHelper.getTasks(_currentUserId);
    } catch (e) {
      throw DatabaseException('Failed to retrieve tasks from local database: $e');
    }
  }

  @override
  Future<void> createTask(Task task) async {
    final now = DateTime.now();
    
    // Start with pending status
    final taskModel = TaskModel.fromEntity(task).copyWith(
      userId: _currentUserId,
      createdAt: task.createdAt,
      lastModifiedAt: now,
      syncStatus: SyncStatus.pendingCreate,
    );

    // Save locally first
    try {
      await _dbHelper.insertTask(taskModel);
    } catch (e) {
      throw DatabaseException('Failed to write task locally: $e');
    }

    // Try syncing immediately if online and remote is available
    if (_isFirebaseAvailable && await _networkInfo.isConnected) {
      try {
        final syncedTask = taskModel.copyWith(syncStatus: SyncStatus.synced);
        await _firestoreService.setTask(syncedTask);
        // Update local status to synced
        await _dbHelper.insertTask(syncedTask);
      } catch (e) {
        // If remote fails, we keep local status as pendingCreate. No exceptions bubble up to UI
        // since the local save succeeded.
      }
    }
  }

  @override
  Future<void> updateTask(Task task) async {
    final now = DateTime.now();
    SyncStatus newSyncStatus = SyncStatus.pendingUpdate;

    try {
      final existingTask = await _dbHelper.getTaskById(task.id);
      if (existingTask != null && existingTask.syncStatus == SyncStatus.pendingCreate) {
        newSyncStatus = SyncStatus.pendingCreate;
      }
    } catch (_) {}

    final taskModel = TaskModel.fromEntity(task).copyWith(
      userId: _currentUserId,
      lastModifiedAt: now,
      syncStatus: newSyncStatus,
    );

    // Save locally first
    try {
      await _dbHelper.insertTask(taskModel);
    } catch (e) {
      throw DatabaseException('Failed to update task locally: $e');
    }

    // Try syncing immediately if online and remote is available
    if (_isFirebaseAvailable && await _networkInfo.isConnected) {
      try {
        final syncedTask = taskModel.copyWith(syncStatus: SyncStatus.synced);
        await _firestoreService.setTask(syncedTask);
        await _dbHelper.insertTask(syncedTask);
      } catch (e) {
        // If remote fails, we keep local status as pendingUpdate/pendingCreate.
      }
    }
  }

  @override
  Future<void> deleteTask(String taskId) async {
    final now = DateTime.now();
    bool localOnlyDelete = true;

    if (_isFirebaseAvailable && await _networkInfo.isConnected) {
      try {
        await _firestoreService.deleteTask(taskId);
        localOnlyDelete = false;
      } catch (e) {
        // If remote fails, mark as pendingDelete locally
      }
    }

    try {
      if (localOnlyDelete) {
        await _dbHelper.markTaskAsPendingDelete(taskId, now);
      } else {
        await _dbHelper.deletePermanently(taskId);
      }
    } catch (e) {
      throw DatabaseException('Failed to delete task locally: $e');
    }
  }

  @override
  Future<void> syncPendingTasks() async {
    if (!_isFirebaseAvailable) return;
    if (!await _networkInfo.isConnected) return;

    try {
      // 1. Push local changes
      final pendingTasks = await _dbHelper.getPendingTasks(_currentUserId);
      for (final task in pendingTasks) {
        try {
          if (task.syncStatus == SyncStatus.pendingDelete) {
            await _firestoreService.deleteTask(task.id);
            await _dbHelper.deletePermanently(task.id);
          } else if (task.syncStatus == SyncStatus.pendingCreate) {
            final remoteTask = await _firestoreService.getTask(task.id);
            if (remoteTask != null) {
              // Last Write Wins resolution
              if (task.lastModifiedAt.isAfter(remoteTask.lastModifiedAt)) {
                final syncedTask = task.copyWith(syncStatus: SyncStatus.synced);
                await _firestoreService.setTask(syncedTask);
                await _dbHelper.insertTask(syncedTask);
              } else {
                // Remote is newer, pull it
                final syncedRemoteTask = remoteTask.copyWith(syncStatus: SyncStatus.synced);
                await _dbHelper.insertTask(syncedRemoteTask);
              }
            } else {
              final syncedTask = task.copyWith(syncStatus: SyncStatus.synced);
              await _firestoreService.setTask(syncedTask);
              await _dbHelper.insertTask(syncedTask);
            }
          } else if (task.syncStatus == SyncStatus.pendingUpdate || task.syncStatus == SyncStatus.failed) {
            final remoteTask = await _firestoreService.getTask(task.id);
            if (remoteTask != null) {
              if (task.lastModifiedAt.isAfter(remoteTask.lastModifiedAt)) {
                final syncedTask = task.copyWith(syncStatus: SyncStatus.synced);
                await _firestoreService.setTask(syncedTask);
                await _dbHelper.insertTask(syncedTask);
              } else {
                // Remote is newer, overwrite local
                final syncedRemoteTask = remoteTask.copyWith(syncStatus: SyncStatus.synced);
                await _dbHelper.insertTask(syncedRemoteTask);
              }
            } else {
              // Remote task doesn't exist, recreate it
              final syncedTask = task.copyWith(syncStatus: SyncStatus.synced);
              await _firestoreService.setTask(syncedTask);
              await _dbHelper.insertTask(syncedTask);
            }
          }
        } catch (e) {
          // If a specific task sync fails, mark it as failed and continue
          await _dbHelper.insertTask(task.copyWith(syncStatus: SyncStatus.failed));
        }
      }

      // 2. Pull remote tasks for current user
      try {
        final remoteTasks = await _firestoreService.fetchTasks(_currentUserId);
        for (final remoteTask in remoteTasks) {
          final localTask = await _dbHelper.getTaskById(remoteTask.id);
          if (localTask == null) {
            await _dbHelper.insertTask(remoteTask.copyWith(syncStatus: SyncStatus.synced));
          } else if (localTask.syncStatus == SyncStatus.synced) {
            if (remoteTask.lastModifiedAt.isAfter(localTask.lastModifiedAt)) {
              await _dbHelper.insertTask(remoteTask.copyWith(syncStatus: SyncStatus.synced));
            }
          }
        }
      } catch (e) {
        debugPrint('Failed to pull remote tasks: $e');
      }
    } catch (e) {
      throw RemoteException('Failed to synchronize pending tasks: $e');
    }
  }
}
