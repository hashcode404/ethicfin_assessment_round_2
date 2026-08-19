import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../domain/entities/task.dart';
import '../providers/task_providers.dart';

class TaskFormScreen extends ConsumerStatefulWidget {
  final Task? task;

  const TaskFormScreen({super.key, this.task});

  @override
  ConsumerState<TaskFormScreen> createState() => _TaskFormScreenState();
}

class _TaskFormScreenState extends ConsumerState<TaskFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  late TaskPriority _priority;
  late DateTime _dueDate;

  bool get _isEditMode => widget.task != null;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.task?.title ?? '');
    _descriptionController = TextEditingController(text: widget.task?.description ?? '');
    _priority = widget.task?.priority ?? TaskPriority.medium;
    _dueDate = widget.task?.dueDate ?? DateTime.now().add(const Duration(days: 1));
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _selectDueDate(BuildContext context) async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _dueDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );

    if (pickedDate != null && pickedDate != _dueDate) {
      setState(() {
        _dueDate = DateTime(
          pickedDate.year,
          pickedDate.month,
          pickedDate.day,
          _dueDate.hour,
          _dueDate.minute,
        );
      });
    }
  }

  Future<void> _saveTask() async {
    if (!_formKey.currentState!.validate()) return;

    final title = _titleController.text.trim();
    final description = _descriptionController.text.trim();

    if (_isEditMode) {
      final updatedTask = widget.task!.copyWith(
        title: title,
        description: description,
        priority: _priority,
        dueDate: _dueDate,
      );
      await ref.read(taskListProvider.notifier).updateTask(updatedTask);
    } else {
      await ref.read(taskListProvider.notifier).createTask(
            title: title,
            description: description,
            priority: _priority,
            dueDate: _dueDate,
          );
    }

    if (mounted) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateFormat = DateFormat('EEEE, MMMM dd, yyyy');

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditMode ? 'Edit Task' : 'New Task'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _titleController,
                style: theme.textTheme.bodyLarge?.copyWith(fontSize: 18, fontWeight: FontWeight.bold),
                decoration: const InputDecoration(
                  labelText: 'Task Title *',
                  hintText: 'What needs to be done?',
                  alignLabelWithHint: true,
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Title is required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _descriptionController,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  hintText: 'Add extra details here...',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Priority',
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Row(
                children: TaskPriority.values.map((priority) {
                  final isSelected = _priority == priority;
                  Color priorityColor;
                  switch (priority) {
                    case TaskPriority.high:
                      priorityColor = Colors.red;
                      break;
                    case TaskPriority.medium:
                      priorityColor = Colors.amber.shade700;
                      break;
                    case TaskPriority.low:
                      priorityColor = Colors.green;
                      break;
                  }

                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: OutlinedButton(
                        onPressed: () {
                          setState(() {
                            _priority = priority;
                          });
                        },
                        style: OutlinedButton.styleFrom(
                          backgroundColor: isSelected ? priorityColor.withOpacity(0.12) : null,
                          side: BorderSide(
                            color: isSelected ? priorityColor : theme.dividerColor.withOpacity(0.2),
                            width: isSelected ? 2 : 1,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: Text(
                          priority.name.toUpperCase(),
                          style: TextStyle(
                            color: isSelected ? priorityColor : theme.textTheme.bodyMedium?.color?.withOpacity(0.7),
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 28),
              Text(
                'Due Date',
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              InkWell(
                onTap: () => _selectDueDate(context),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  decoration: BoxDecoration(
                    color: theme.cardTheme.color ?? theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: theme.dividerColor.withOpacity(0.1),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.calendar_month, color: theme.colorScheme.primary),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          dateFormat.format(_dueDate),
                          style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
                        ),
                      ),
                      Text(
                        'Change',
                        style: TextStyle(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saveTask,
                  child: Text(_isEditMode ? 'Save Changes' : 'Create Task'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
