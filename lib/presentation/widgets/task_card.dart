import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_theme.dart';
import '../../domain/entities/task.dart';

class TaskCard extends StatelessWidget {
  final Task task;
  final VoidCallback onTap;
  final ValueChanged<bool?> onToggleComplete;
  final VoidCallback onDelete;

  const TaskCard({
    super.key,
    required this.task,
    required this.onTap,
    required this.onToggleComplete,
    required this.onDelete,
  });

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

  Widget _getSyncIcon(SyncStatus status) {
    switch (status) {
      case SyncStatus.synced:
        return const Tooltip(
          message: 'Synced',
          child: Icon(Icons.cloud_done, color: Colors.green, size: 18),
        );
      case SyncStatus.pendingCreate:
      case SyncStatus.pendingUpdate:
        return const Tooltip(
          message: 'Pending sync',
          child: Icon(Icons.cloud_upload_outlined, color: Colors.orange, size: 18),
        );
      case SyncStatus.pendingDelete:
        return const Tooltip(
          message: 'Deleting remote...',
          child: Icon(Icons.delete_sweep_outlined, color: Colors.red, size: 18),
        );
      case SyncStatus.failed:
        return const Tooltip(
          message: 'Sync failed',
          child: Icon(Icons.error_outline, color: Colors.red, size: 18),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateFormat = DateFormat('MMM dd, yyyy');

    return Dismissible(
      key: Key(task.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: Colors.red.shade400,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      confirmDismiss: (direction) async {
        return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Delete Task'),
            content: const Text('Are you sure you want to delete this task?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('Delete'),
              ),
            ],
          ),
        );
      },
      onDismissed: (_) => onDelete(),
      child: Card(
        margin: const EdgeInsets.only(bottom: 12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Completion Checkbox
                Transform.scale(
                  scale: 1.1,
                  child: Checkbox(
                    value: task.isCompleted,
                    onChanged: onToggleComplete,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                    activeColor: AppTheme.primaryColor,
                  ),
                ),
                const SizedBox(width: 8),
                // Task details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        task.title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          decoration: task.isCompleted
                              ? TextDecoration.lineThrough
                              : TextDecoration.none,
                          color: task.isCompleted
                              ? theme.textTheme.bodyMedium?.color?.withOpacity(0.5)
                              : theme.textTheme.titleMedium?.color,
                        ),
                      ),
                      if (task.description.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          task.description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: task.isCompleted
                                ? theme.textTheme.bodyMedium?.color?.withOpacity(0.4)
                                : theme.textTheme.bodyMedium?.color,
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          // Priority Badge
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: _getPriorityColor(task.priority).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              task.priority.name.toUpperCase(),
                              style: TextStyle(
                                color: _getPriorityColor(task.priority),
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          // Due Date
                          Icon(
                            Icons.calendar_month,
                            size: 14,
                            color: theme.textTheme.bodyMedium?.color?.withOpacity(0.6),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            dateFormat.format(task.dueDate),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.textTheme.bodyMedium?.color?.withOpacity(0.6),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // Sync Icon and Arrow
                Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _getSyncIcon(task.syncStatus),
                    const SizedBox(height: 24),
                    Icon(
                      Icons.chevron_right,
                      color: theme.textTheme.bodyMedium?.color?.withOpacity(0.4),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
