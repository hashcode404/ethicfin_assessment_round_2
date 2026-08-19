import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../core/network/network_info.dart';
import '../../core/network/sync_service.dart';
import '../../data/local/database_helper.dart';
import '../../data/remote/firestore_service.dart';
import '../../data/repositories/task_repository_impl.dart';
import '../../domain/entities/task.dart';
import '../../domain/repositories/task_repository.dart';

import 'firebase_providers.dart';
import 'auth_providers.dart';

final databaseHelperProvider = Provider<DatabaseHelper>((ref) => DatabaseHelper.instance);

final firestoreServiceProvider = Provider<FirestoreService>((ref) => FirestoreService());

final connectivityProvider = Provider<Connectivity>((ref) => Connectivity());

final networkInfoProvider = Provider<NetworkInfo>((ref) {
  final connectivity = ref.watch(connectivityProvider);
  return NetworkInfoImpl(connectivity);
});

final taskRepositoryProvider = Provider<TaskRepository>((ref) {
  final dbHelper = ref.watch(databaseHelperProvider);
  final firestoreService = ref.watch(firestoreServiceProvider);
  final networkInfo = ref.watch(networkInfoProvider);
  final firebaseAvailable = ref.watch(firebaseAvailableProvider);

  return TaskRepositoryImpl(
    dbHelper: dbHelper,
    firestoreService: firestoreService,
    networkInfo: networkInfo,
    isFirebaseAvailable: firebaseAvailable,
    userIdProvider: () => ref.read(currentUserIdProvider),
  );
});

final syncServiceProvider = StateNotifierProvider<SyncService, SyncState>((ref) {
  final repository = ref.watch(taskRepositoryProvider);
  final networkInfo = ref.watch(networkInfoProvider);
  return SyncService(taskRepository: repository, networkInfo: networkInfo);
});

// UI filtering state providers
enum TaskFilter { all, completed, pending }
enum TaskSort { dueDate, priority }

final taskFilterProvider = StateProvider<TaskFilter>((ref) => TaskFilter.all);
final taskSortProvider = StateProvider<TaskSort>((ref) => TaskSort.dueDate);
final taskSearchProvider = StateProvider<String>((ref) => '');

// Notifier for Task List
class TaskListNotifier extends StateNotifier<AsyncValue<List<Task>>> {
  final TaskRepository _repository;
  final Ref _ref;

  TaskListNotifier(this._repository, this._ref) : super(const AsyncValue.loading()) {
    loadTasks();
  }

  Future<void> loadTasks() async {
    try {
      final tasks = await _repository.getTasks();
      state = AsyncValue.data(tasks);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> createTask({
    required String title,
    required String description,
    required TaskPriority priority,
    required DateTime dueDate,
  }) async {
    try {
      final now = DateTime.now();
      final currentUserId = _ref.read(currentUserIdProvider);
      final task = Task(
        id: const Uuid().v4(),
        userId: currentUserId,
        title: title,
        description: description,
        priority: priority,
        dueDate: dueDate,
        isCompleted: false,
        createdAt: now,
        syncStatus: SyncStatus.pendingCreate,
        lastModifiedAt: now,
      );

      // Perform local update to state immediately for responsiveness
      state.whenData((currentTasks) {
        state = AsyncValue.data([...currentTasks, task]);
      });

      await _repository.createTask(task);
      // Reload tasks from source to verify synchronization status
      await loadTasks();

      // Trigger synchronization
      _ref.read(syncServiceProvider.notifier).sync();
    } catch (e, stack) {
      await loadTasks();
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> updateTask(Task task) async {
    try {
      state.whenData((currentTasks) {
        state = AsyncValue.data(
          currentTasks.map((t) => t.id == task.id ? task : t).toList(),
        );
      });

      await _repository.updateTask(task);
      await loadTasks();

      // Trigger synchronization
      _ref.read(syncServiceProvider.notifier).sync();
    } catch (e, stack) {
      await loadTasks();
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> toggleTaskCompletion(Task task) async {
    final updatedTask = task.copyWith(
      isCompleted: !task.isCompleted,
      lastModifiedAt: DateTime.now(),
    );
    await updateTask(updatedTask);
  }

  Future<void> deleteTask(String id) async {
    try {
      state.whenData((currentTasks) {
        state = AsyncValue.data(currentTasks.where((t) => t.id != id).toList());
      });

      await _repository.deleteTask(id);
      await loadTasks();

      // Trigger synchronization
      _ref.read(syncServiceProvider.notifier).sync();
    } catch (e, stack) {
      await loadTasks();
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> logout() async {
    final currentUserId = _ref.read(currentUserIdProvider);
    // 1. Sign out from Firebase Auth
    await _ref.read(authRepositoryProvider).signOut();
    // 2. Clear local tasks for this user
    await _ref.read(databaseHelperProvider).clearTasksForUser(currentUserId);
    // 3. Reset guest mode
    _ref.read(guestModeProvider.notifier).state = false;
    // 4. Reload tasks (will fetch for the new logged-out user status, i.e. guest_user, which will be empty)
    await loadTasks();
  }
}

final taskListProvider = StateNotifierProvider<TaskListNotifier, AsyncValue<List<Task>>>((ref) {
  final repository = ref.watch(taskRepositoryProvider);
  return TaskListNotifier(repository, ref);
});

// Composed filter-sort-search pipeline
final filteredTasksProvider = Provider<AsyncValue<List<Task>>>((ref) {
  final tasksAsync = ref.watch(taskListProvider);
  final filter = ref.watch(taskFilterProvider);
  final sort = ref.watch(taskSortProvider);
  final searchQuery = ref.watch(taskSearchProvider);

  return tasksAsync.when(
    data: (tasks) {
      // 1. Search (case insensitive matching on title)
      var result = tasks;
      if (searchQuery.isNotEmpty) {
        result = result
            .where((t) => t.title.toLowerCase().contains(searchQuery.toLowerCase()))
            .toList();
      }

      // 2. Filter (All, Completed, Pending)
      if (filter == TaskFilter.completed) {
        result = result.where((t) => t.isCompleted).toList();
      } else if (filter == TaskFilter.pending) {
        result = result.where((t) => !t.isCompleted).toList();
      }

      // 3. Sort (Due Date, Priority)
      if (sort == TaskSort.dueDate) {
        // Nearest due date first
        result.sort((a, b) => a.dueDate.compareTo(b.dueDate));
      } else if (sort == TaskSort.priority) {
        // High -> Medium -> Low
        result.sort((a, b) {
          final priorityA = a.priority == TaskPriority.high ? 2 : (a.priority == TaskPriority.medium ? 1 : 0);
          final priorityB = b.priority == TaskPriority.high ? 2 : (b.priority == TaskPriority.medium ? 1 : 0);
          return priorityB.compareTo(priorityA);
        });
      }

      return AsyncValue.data(result);
    },
    loading: () => const AsyncValue.loading(),
    error: (err, stack) => AsyncValue.error(err, stack),
  );
});
