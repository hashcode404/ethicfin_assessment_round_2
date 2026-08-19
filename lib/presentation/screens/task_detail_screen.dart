import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_theme.dart';
import '../../domain/entities/task.dart';
import '../providers/task_providers.dart';
import 'task_form_screen.dart';

class TaskDetailScreen extends ConsumerWidget {
  final String taskId;

  const TaskDetailScreen({super.key, required this.taskId});

  Color _getPriorityColor(TaskPriority priority) {
    switch (priority) {
      case TaskPriority.high:
        return AppTheme.highPriorityColor;
      case TaskPriority.medium:
        return AppTheme.mediumPriorityColor;
      case TaskPriority.low:
        return AppTheme.lowPriorityColor;
    }
  }

  String _getSyncStatusText(SyncStatus status) {
    switch (status) {
      case SyncStatus.synced:
        return 'Synced with Cloud';
      case SyncStatus.pendingCreate:
        return 'Pending Creation Sync';
      case SyncStatus.pendingUpdate:
        return 'Pending Update Sync';
      case SyncStatus.pendingDelete:
        return 'Pending Deletion Sync';
      case SyncStatus.failed:
        return 'Sync Failed (Will Retry)';
    }
  }

  Widget _getSyncStatusIcon(SyncStatus status) {
    switch (status) {
      case SyncStatus.synced:
        return const Icon(Icons.cloud_done, color: Colors.green, size: 20);
      case SyncStatus.pendingCreate:
      case SyncStatus.pendingUpdate:
        return const Icon(Icons.cloud_upload_outlined,
            color: Colors.orange, size: 20);
      case SyncStatus.pendingDelete:
        return const Icon(Icons.delete_sweep_outlined,
            color: Colors.red, size: 20);
      case SyncStatus.failed:
        return const Icon(Icons.error_outline, color: Colors.red, size: 20);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final tasksAsync = ref.watch(taskListProvider);
    final dateFormat = DateFormat('EEEE, MMMM dd, yyyy');
    final timeFormat = DateFormat('hh:mm a');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Task Details'),
        actions: [
          tasksAsync.when(
            data: (tasks) {
              final task = tasks.where((t) => t.id == taskId).firstOrNull;
              if (task == null) return const SizedBox.shrink();
              return IconButton(
                icon: const Icon(Icons.edit_outlined),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => TaskFormScreen(task: task),
                    ),
                  );
                },
              );
            },
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
          tasksAsync.when(
            data: (tasks) {
              final task = tasks.where((t) => t.id == taskId).firstOrNull;
              if (task == null) return const SizedBox.shrink();
              return IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.red),
                onPressed: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Delete Task'),
                      content: const Text(
                          'Are you sure you want to delete this task?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Cancel'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(context, true),
                          style:
                              TextButton.styleFrom(foregroundColor: Colors.red),
                          child: const Text('Delete'),
                        ),
                      ],
                    ),
                  );
                  if (confirm == true) {
                    await ref
                        .read(taskListProvider.notifier)
                        .deleteTask(task.id);
                    if (context.mounted) {
                      Navigator.pop(context);
                    }
                  }
                },
              );
            },
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
        ],
      ),
      body: tasksAsync.when(
        data: (tasks) {
          final taskList = tasks.where((t) => t.id == taskId).toList();
          if (taskList.isEmpty) {
            return const Center(
                child: Text('Task not found or has been deleted.'));
          }
          final task = taskList.first;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color:
                            _getPriorityColor(task.priority).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _getPriorityColor(task.priority),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${task.priority.name.toUpperCase()} PRIORITY',
                            style: TextStyle(
                              color: _getPriorityColor(task.priority),
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: () {
                        ref
                            .read(taskListProvider.notifier)
                            .toggleTaskCompletion(task);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: task.isCompleted
                              ? AppTheme.lowPriorityColor.withOpacity(0.1)
                              : theme.colorScheme.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              task.isCompleted
                                  ? Icons.check_circle
                                  : Icons.radio_button_unchecked,
                              color: task.isCompleted
                                  ? AppTheme.lowPriorityColor
                                  : theme.colorScheme.primary,
                              size: 16,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              task.isCompleted ? 'COMPLETED' : 'MARK COMPLETE',
                              style: TextStyle(
                                color: task.isCompleted
                                    ? AppTheme.lowPriorityColor
                                    : theme.colorScheme.primary,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Text(
                  task.title,
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    decoration:
                        task.isCompleted ? TextDecoration.lineThrough : null,
                    color: task.isCompleted
                        ? theme.textTheme.headlineMedium?.color
                            ?.withOpacity(0.5)
                        : null,
                  ),
                ),
                const SizedBox(height: 16),
                if (task.description.isNotEmpty) ...[
                  Text(
                    'Description',
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: theme.cardTheme.color ?? theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: theme.dividerColor.withOpacity(0.05),
                      ),
                    ),
                    child: Text(
                      task.description,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        height: 1.5,
                        color: task.isCompleted
                            ? theme.textTheme.bodyLarge?.color?.withOpacity(0.6)
                            : null,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Column(
                      children: [
                        _buildInfoRow(
                          context,
                          icon: Icons.calendar_month_outlined,
                          title: 'Due Date',
                          value: dateFormat.format(task.dueDate),
                        ),
                        const Divider(height: 24),
                        _buildInfoRow(
                          context,
                          icon: Icons.create_outlined,
                          title: 'Created At',
                          value:
                              '${dateFormat.format(task.createdAt)} at ${timeFormat.format(task.createdAt)}',
                        ),
                        const Divider(height: 24),
                        _buildInfoRow(
                          context,
                          iconWidget: _getSyncStatusIcon(task.syncStatus),
                          title: 'Sync Status',
                          value: _getSyncStatusText(task.syncStatus),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(
          child: Text('An error occurred: $err'),
        ),
      ),
    );
  }

  Widget _buildInfoRow(
    BuildContext context, {
    IconData? icon,
    Widget? iconWidget,
    required String title,
    required String value,
  }) {
    final theme = Theme.of(context);
    return Row(
      children: [
        iconWidget ?? Icon(icon, color: theme.colorScheme.primary, size: 20),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.textTheme.bodyMedium?.color?.withOpacity(0.6),
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: theme.textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
