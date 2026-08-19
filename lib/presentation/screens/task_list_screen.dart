import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/network/notification_service.dart';
import '../../core/network/sync_service.dart';
import '../../core/theme/app_theme.dart';
import '../../domain/entities/task.dart';
import '../providers/firebase_providers.dart';
import '../providers/auth_providers.dart';
import '../providers/task_providers.dart';
import '../providers/theme_provider.dart';
import '../widgets/task_card.dart';
import 'task_detail_screen.dart';
import 'task_form_screen.dart';

class TaskListScreen extends ConsumerStatefulWidget {
  const TaskListScreen({super.key});

  @override
  ConsumerState<TaskListScreen> createState() => _TaskListScreenState();
}

class _TaskListScreenState extends ConsumerState<TaskListScreen> {
  final TextEditingController _searchController = TextEditingController();
  StreamSubscription? _fcmSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _setupNotificationListener();
    });
  }

  void _setupNotificationListener() {
    final firebaseAvailable = ref.read(firebaseAvailableProvider);
    if (!firebaseAvailable) return;

    _fcmSubscription = ref.read(notificationServiceProvider).onForegroundMessage.listen((message) {
      if (mounted) {
        final title = message.notification?.title ?? 'Sync Alert';
        final body = message.notification?.body ?? 'A background sync event occurred.';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.notifications_active, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
                      Text(body, style: const TextStyle(fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
            behavior: SnackBarBehavior.floating,
            backgroundColor: AppTheme.primaryColor,
            duration: const Duration(seconds: 4),
          ),
        );
        ref.read(taskListProvider.notifier).loadTasks();
      }
    });
  }

  @override
  void dispose() {
    _fcmSubscription?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _handleLogout() async {
    final authState = ref.read(authStateProvider).value;
    final isGuest = ref.read(guestModeProvider);
    
    if (authState == null && isGuest) {
      // Exit Guest Mode
      ref.read(guestModeProvider.notifier).state = false;
      await ref.read(taskListProvider.notifier).loadTasks();
      return;
    }

    final rawTasksAsync = ref.read(taskListProvider);
    bool hasUnsynced = false;
    rawTasksAsync.whenData((tasks) {
      if (tasks.any((t) => t.syncStatus != SyncStatus.synced)) {
        hasUnsynced = true;
      }
    });

    if (hasUnsynced) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Unsynced Changes'),
          content: const Text(
            'You have tasks that are not synchronized with the cloud. '
            'Logging out will clear your local database and unsynced data will be lost. '
            'Are you sure you want to log out?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Log Out'),
            ),
          ],
        ),
      );
      if (confirm != true) return;
    }

    await ref.read(taskListProvider.notifier).logout();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final filteredTasksAsync = ref.watch(filteredTasksProvider);
    final rawTasksAsync = ref.watch(taskListProvider);
    final syncState = ref.watch(syncServiceProvider);
    final firebaseAvailable = ref.watch(firebaseAvailableProvider);
    final authState = ref.watch(authStateProvider).value;
    final themeMode = ref.watch(themeModeProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Task Space'),
        actions: [
          IconButton(
            icon: Icon(
              themeMode == ThemeMode.dark
                  ? Icons.light_mode_outlined
                  : (themeMode == ThemeMode.light
                      ? Icons.dark_mode_outlined
                      : Icons.brightness_auto_outlined),
            ),
            tooltip: 'Toggle Theme',
            onPressed: () {
              ref.read(themeModeProvider.notifier).toggle(context);
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.read(taskListProvider.notifier).loadTasks();
              if (firebaseAvailable) {
                ref.read(syncServiceProvider.notifier).sync();
              }
            },
            tooltip: 'Sync Now',
          ),
          if (firebaseAvailable)
            IconButton(
              icon: Icon(authState != null ? Icons.logout : Icons.login),
              tooltip: authState != null ? 'Sign Out' : 'Sign In',
              onPressed: _handleLogout,
            ),
        ],
      ),
      body: Column(
        children: [
          // Connection Status Indicator Banner
          _buildConnectionBanner(context, syncState, firebaseAvailable),
          
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                await ref.read(taskListProvider.notifier).loadTasks();
                if (firebaseAvailable) {
                  await ref.read(syncServiceProvider.notifier).sync();
                }
              },
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 12),
                    // Dashboard Stats Cards
                    rawTasksAsync.maybeWhen(
                      data: (tasks) => _buildDashboardStats(context, tasks),
                      orElse: () => const SizedBox.shrink(),
                    ),
                    const SizedBox(height: 16),
                    
                    // Search Bar
                    _buildSearchBar(context),
                    const SizedBox(height: 12),
                    
                    // Filter & Sort Controls
                    _buildFilterAndSortControls(context),
                    const SizedBox(height: 16),

                    // Task List Widget
                    filteredTasksAsync.when(
                      data: (tasks) {
                        if (tasks.isEmpty) {
                          final query = ref.read(taskSearchProvider);
                          final hasTasksAtAll = rawTasksAsync.maybeWhen(
                            data: (t) => t.isNotEmpty,
                            orElse: () => false,
                          );
                          return _buildEmptyState(context, hasTasksAtAll, query.isNotEmpty);
                        }

                        return ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: tasks.length,
                          itemBuilder: (context, index) {
                            final task = tasks[index];
                            return TaskCard(
                              task: task,
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => TaskDetailScreen(taskId: task.id),
                                  ),
                                );
                              },
                              onToggleComplete: (_) {
                                ref.read(taskListProvider.notifier).toggleTaskCompletion(task);
                              },
                              onDelete: () {
                                ref.read(taskListProvider.notifier).deleteTask(task.id);
                              },
                            );
                          },
                        );
                      },
                      loading: () => const Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 40),
                          child: CircularProgressIndicator(),
                        ),
                      ),
                      error: (error, _) => Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 32),
                          child: Column(
                            children: [
                              const Icon(Icons.error_outline, color: Colors.red, size: 48),
                              const SizedBox(height: 12),
                              Text(
                                'Error loading tasks',
                                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                error.toString(),
                                style: theme.textTheme.bodyMedium,
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 80),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const TaskFormScreen(),
            ),
          );
        },
        icon: const Icon(Icons.add),
        label: const Text('Add Task'),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
      ),
    );
  }

  Widget _buildConnectionBanner(BuildContext context, SyncState syncState, bool firebaseAvailable) {
    if (!firebaseAvailable) {
      return Container(
        width: double.infinity,
        color: Colors.amber.shade800,
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.cloud_off, color: Colors.white, size: 14),
            SizedBox(width: 8),
            Text(
              'Running in Local-Only Mode (Firebase Unconfigured)',
              style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      );
    }

    Color bannerColor;
    IconData bannerIcon;
    String bannerText;

    switch (syncState.status) {
      case SyncStateStatus.synced:
        return const SizedBox.shrink();
      case SyncStateStatus.syncing:
        bannerColor = AppTheme.primaryColor;
        bannerIcon = Icons.sync;
        bannerText = 'Syncing offline changes...';
        break;
      case SyncStateStatus.offline:
        bannerColor = Colors.grey.shade700;
        bannerIcon = Icons.signal_wifi_off;
        bannerText = 'Offline Mode - Changes saved locally';
        break;
      case SyncStateStatus.failed:
        bannerColor = AppTheme.highPriorityColor;
        bannerIcon = Icons.sync_problem;
        bannerText = 'Synchronization failed - Will retry';
        break;
    }

    return Container(
      width: double.infinity,
      color: bannerColor,
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(bannerIcon, color: Colors.white, size: 14),
          const SizedBox(width: 8),
          Text(
            bannerText,
            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
          ),
          if (syncState.status == SyncStateStatus.failed) ...[
            const SizedBox(width: 12),
            GestureDetector(
              onTap: () => ref.read(syncServiceProvider.notifier).sync(),
              child: const Text(
                'RETRY',
                style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold, decoration: TextDecoration.underline),
              ),
            ),
          ]
        ],
      ),
    );
  }

  Widget _buildDashboardStats(BuildContext context, List<Task> tasks) {
    final theme = Theme.of(context);
    final total = tasks.length;
    final completed = tasks.where((t) => t.isCompleted).length;
    final pending = total - completed;
    final pendingSync = tasks.where((t) => t.syncStatus != SyncStatus.synced).length;

    return Row(
      children: [
        _buildStatCard(context, 'Total', '$total', theme.colorScheme.primary),
        const SizedBox(width: 8),
        _buildStatCard(context, 'Completed', '$completed', AppTheme.lowPriorityColor),
        const SizedBox(width: 8),
        _buildStatCard(context, 'Pending', '$pending', AppTheme.mediumPriorityColor),
        if (pendingSync > 0) ...[
          const SizedBox(width: 8),
          _buildStatCard(context, 'Queue', '$pendingSync', Colors.orange),
        ],
      ],
    );
  }

  Widget _buildStatCard(BuildContext context, String label, String value, Color color) {
    final theme = Theme.of(context);
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.2), width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.textTheme.bodyMedium?.color?.withOpacity(0.6),
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar(BuildContext context) {
    return TextField(
      controller: _searchController,
      onChanged: (val) => ref.read(taskSearchProvider.notifier).state = val,
      decoration: InputDecoration(
        hintText: 'Search tasks by title...',
        prefixIcon: const Icon(Icons.search),
        suffixIcon: _searchController.text.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.clear),
                onPressed: () {
                  _searchController.clear();
                  ref.read(taskSearchProvider.notifier).state = '';
                },
              )
            : null,
      ),
    );
  }

  Widget _buildFilterAndSortControls(BuildContext context) {
    final theme = Theme.of(context);
    final activeFilter = ref.watch(taskFilterProvider);
    final activeSort = ref.watch(taskSortProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Filter:',
              style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: TaskFilter.values.map((filter) {
                    final isSelected = activeFilter == filter;
                    return Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ChoiceChip(
                        label: Text(filter.name.toUpperCase()),
                        selected: isSelected,
                        onSelected: (selected) {
                          if (selected) {
                            ref.read(taskFilterProvider.notifier).state = filter;
                          }
                        },
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Text(
              'Sort by:',
              style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(width: 8),
            ChoiceChip(
              label: const Text('DUE DATE'),
              selected: activeSort == TaskSort.dueDate,
              onSelected: (selected) {
                if (selected) {
                  ref.read(taskSortProvider.notifier).state = TaskSort.dueDate;
                }
              },
            ),
            const SizedBox(width: 8),
            ChoiceChip(
              label: const Text('PRIORITY'),
              selected: activeSort == TaskSort.priority,
              onSelected: (selected) {
                if (selected) {
                  ref.read(taskSortProvider.notifier).state = TaskSort.priority;
                }
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context, bool hasTasksAtAll, bool isSearching) {
    final theme = Theme.of(context);
    final title = isSearching || hasTasksAtAll ? 'No matching tasks' : 'No tasks yet';
    final subtitle = isSearching || hasTasksAtAll
        ? 'Try resetting search query or filter chips.'
        : 'Create your first task to get started.';

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isSearching || hasTasksAtAll ? Icons.search_off : Icons.task_alt,
              size: 72,
              color: theme.textTheme.bodyMedium?.color?.withOpacity(0.2),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
