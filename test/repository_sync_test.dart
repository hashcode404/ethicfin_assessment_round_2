import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ethicfin_assessment_round_2/core/network/network_info.dart';
import 'package:ethicfin_assessment_round_2/data/local/database_helper.dart';
import 'package:ethicfin_assessment_round_2/data/remote/firestore_service.dart';
import 'package:ethicfin_assessment_round_2/data/repositories/task_repository_impl.dart';
import 'package:ethicfin_assessment_round_2/domain/entities/task.dart';
import 'package:ethicfin_assessment_round_2/data/models/task_model.dart';

class FakeDatabaseHelper implements DatabaseHelper {
  final Map<String, TaskModel> tasks = {};

  @override
  Future<int> insertTask(Task task) async {
    final model = task is TaskModel ? task : TaskModel.fromEntity(task);
    tasks[model.id] = model;
    return 1;
  }

  @override
  Future<int> updateTask(Task task) async {
    return insertTask(task);
  }

  @override
  Future<TaskModel?> getTaskById(String id) async {
    return tasks[id];
  }

  @override
  Future<List<TaskModel>> getTasks(String userId) async {
    return tasks.values.where((t) => t.userId == userId && t.syncStatus != SyncStatus.pendingDelete).toList();
  }

  @override
  Future<List<TaskModel>> getAllTasksRaw({String? userId}) async {
    if (userId != null) {
      return tasks.values.where((t) => t.userId == userId).toList();
    }
    return tasks.values.toList();
  }

  @override
  Future<List<TaskModel>> getPendingTasks(String userId) async {
    return tasks.values.where((t) => t.userId == userId && t.syncStatus != SyncStatus.synced).toList();
  }

  @override
  Future<int> markTaskAsPendingDelete(String id, DateTime lastModifiedAt) async {
    final existing = tasks[id];
    if (existing != null) {
      tasks[id] = TaskModel.fromEntity(existing.copyWith(
        syncStatus: SyncStatus.pendingDelete,
        lastModifiedAt: lastModifiedAt,
      ));
    }
    return 1;
  }

  @override
  Future<int> deletePermanently(String id) async {
    tasks.remove(id);
    return 1;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeFirestoreService implements FirestoreService {
  final Map<String, TaskModel> remoteTasks = {};
  bool throwError = false;

  @override
  Future<void> setTask(Task task) async {
    if (throwError) throw Exception('Simulated network error');
    remoteTasks[task.id] = task is TaskModel ? task : TaskModel.fromEntity(task);
  }

  @override
  Future<void> deleteTask(String id) async {
    if (throwError) throw Exception('Simulated network error');
    remoteTasks.remove(id);
  }

  @override
  Future<TaskModel?> getTask(String id) async {
    if (throwError) throw Exception('Simulated network error');
    return remoteTasks[id];
  }

  @override
  Future<List<TaskModel>> fetchTasks(String userId) async {
    if (throwError) throw Exception('Simulated network error');
    return remoteTasks.values.where((t) => t.userId == userId).toList();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeNetworkInfo implements NetworkInfo {
  bool connectionStatus = true;

  @override
  Future<bool> get isConnected async => connectionStatus;

  @override
  Stream<List<ConnectivityResult>> get onConnectivityChanged => Stream.value([
        connectionStatus ? ConnectivityResult.wifi : ConnectivityResult.none
      ]);
}

void main() {
  group('Repository Offline-First & Sync Tests', () {
    late FakeDatabaseHelper fakeDb;
    late FakeFirestoreService fakeFirestore;
    late FakeNetworkInfo fakeNetwork;
    late TaskRepositoryImpl repository;

    final testTask = Task(
      id: 'task-1',
      userId: 'test_user',
      title: 'Sync Task',
      description: 'Pending Sync Test',
      priority: TaskPriority.medium,
      dueDate: DateTime(2026, 8, 20),
      isCompleted: false,
      createdAt: DateTime(2026, 8, 19),
      syncStatus: SyncStatus.pendingCreate,
      lastModifiedAt: DateTime(2026, 8, 19),
    );

    setUp(() {
      fakeDb = FakeDatabaseHelper();
      fakeFirestore = FakeFirestoreService();
      fakeNetwork = FakeNetworkInfo();
      
      repository = TaskRepositoryImpl(
        dbHelper: fakeDb,
        firestoreService: fakeFirestore,
        networkInfo: fakeNetwork,
        isFirebaseAvailable: true,
        userIdProvider: () => 'test_user',
      );
    });

    test('Create while offline -> sync when online', () async {
      // 1. Device goes offline
      fakeNetwork.connectionStatus = false;

      // 2. Create task
      await repository.createTask(testTask);

      // Verify stored locally as pendingCreate, and not stored remotely
      final localTask = await fakeDb.getTaskById(testTask.id);
      expect(localTask, isNotNull);
      expect(localTask!.syncStatus, SyncStatus.pendingCreate);
      expect(fakeFirestore.remoteTasks[testTask.id], isNull);

      // 3. Device goes online
      fakeNetwork.connectionStatus = true;

      // 4. Trigger Sync
      await repository.syncPendingTasks();

      // Verify local status updated to synced, and remote task created
      final localTaskSynced = await fakeDb.getTaskById(testTask.id);
      expect(localTaskSynced!.syncStatus, SyncStatus.synced);
      expect(fakeFirestore.remoteTasks[testTask.id], isNotNull);
      expect(fakeFirestore.remoteTasks[testTask.id]!.title, testTask.title);
    });

    test('Update while offline -> sync when online', () async {
      // 1. Task initially synced
      fakeNetwork.connectionStatus = true;
      await repository.createTask(testTask);

      // 2. Device goes offline
      fakeNetwork.connectionStatus = false;

      // 3. Update task locally
      final updatedTask = testTask.copyWith(title: 'Updated Offline Title');
      await repository.updateTask(updatedTask);

      // Verify updated locally as pendingUpdate, remote still has old title
      final localTask = await fakeDb.getTaskById(testTask.id);
      expect(localTask!.syncStatus, SyncStatus.pendingUpdate);
      expect(localTask.title, 'Updated Offline Title');
      expect(fakeFirestore.remoteTasks[testTask.id]!.title, testTask.title);

      // 4. Device goes online
      fakeNetwork.connectionStatus = true;

      // 5. Trigger Sync
      await repository.syncPendingTasks();

      // Verify local status is synced, remote has updated title
      final localTaskSynced = await fakeDb.getTaskById(testTask.id);
      expect(localTaskSynced!.syncStatus, SyncStatus.synced);
      expect(fakeFirestore.remoteTasks[testTask.id]!.title, 'Updated Offline Title');
    });

    test('Delete while offline -> sync when online', () async {
      // 1. Task initially synced
      fakeNetwork.connectionStatus = true;
      await repository.createTask(testTask);

      // 2. Device goes offline
      fakeNetwork.connectionStatus = false;

      // 3. Delete task
      await repository.deleteTask(testTask.id);

      // Verify task marked as pendingDelete locally (to sync later), hidden in getTasks() but exists in raw map, and still exists remotely
      final localTasksList = await fakeDb.getTasks('test_user');
      expect(localTasksList.any((t) => t.id == testTask.id), false); // Hidden in UI

      final rawLocalTask = await fakeDb.getTaskById(testTask.id);
      expect(rawLocalTask!.syncStatus, SyncStatus.pendingDelete); // Exists locally as queue item
      expect(fakeFirestore.remoteTasks[testTask.id], isNotNull); // Still on remote

      // 4. Device goes online
      fakeNetwork.connectionStatus = true;

      // 5. Trigger Sync
      await repository.syncPendingTasks();

      // Verify task deleted permanently from BOTH local DB and Firestore
      final deletedLocalTask = await fakeDb.getTaskById(testTask.id);
      expect(deletedLocalTask, isNull);
      expect(fakeFirestore.remoteTasks[testTask.id], isNull);
    });
  });
}
