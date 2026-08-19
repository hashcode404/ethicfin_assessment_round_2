import '../entities/task.dart';

abstract class TaskRepository {
  Future<List<Task>> getTasks();
  Future<void> createTask(Task task);
  Future<void> updateTask(Task task);
  Future<void> deleteTask(String taskId);
  Future<void> syncPendingTasks();
}
