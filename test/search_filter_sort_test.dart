import 'package:flutter_test/flutter_test.dart';
import 'package:ethicfin_assessment_round_2/domain/entities/task.dart';

void main() {
  group('Search, Filter, and Sort Tests', () {
    final baseTime = DateTime(2026, 8, 20, 10, 0);

    final tasks = [
      Task(
        id: '1',
        title: 'Meeting with Team',
        description: '',
        priority: TaskPriority.medium,
        dueDate: baseTime.add(const Duration(days: 2)), // Due in 2 days
        isCompleted: false,
        createdAt: baseTime,
        syncStatus: SyncStatus.synced,
        lastModifiedAt: baseTime,
      ),
      Task(
        id: '2',
        title: 'Buy groceries',
        description: '',
        priority: TaskPriority.low,
        dueDate: baseTime.add(const Duration(days: 1)), // Due in 1 day
        isCompleted: true,
        createdAt: baseTime,
        syncStatus: SyncStatus.synced,
        lastModifiedAt: baseTime,
      ),
      Task(
        id: '3',
        title: 'Submit assessment',
        description: '',
        priority: TaskPriority.high,
        dueDate: baseTime.add(const Duration(days: 3)), // Due in 3 days
        isCompleted: false,
        createdAt: baseTime,
        syncStatus: SyncStatus.synced,
        lastModifiedAt: baseTime,
      ),
    ];

    // Simulates the search, filter, sort logic from filteredTasksProvider
    List<Task> processTasks(
      List<Task> input, {
      required String query,
      required String filter,
      required String sortBy,
    }) {
      var result = List<Task>.from(input);

      // 1. Search
      if (query.isNotEmpty) {
        result = result
            .where((t) => t.title.toLowerCase().contains(query.toLowerCase()))
            .toList();
      }

      // 2. Filter
      if (filter == 'completed') {
        result = result.where((t) => t.isCompleted).toList();
      } else if (filter == 'pending') {
        result = result.where((t) => !t.isCompleted).toList();
      }

      // 3. Sort
      if (sortBy == 'dueDate') {
        result.sort((a, b) => a.dueDate.compareTo(b.dueDate));
      } else if (sortBy == 'priority') {
        result.sort((a, b) {
          final priorityA = a.priority == TaskPriority.high ? 2 : (a.priority == TaskPriority.medium ? 1 : 0);
          final priorityB = b.priority == TaskPriority.high ? 2 : (b.priority == TaskPriority.medium ? 1 : 0);
          return priorityB.compareTo(priorityA); // High first
        });
      }

      return result;
    }

    test('Search by title (case-insensitive)', () {
      // Searching "MEETING" should match "Meeting with Team"
      final searchResult = processTasks(tasks, query: 'MEETING', filter: 'all', sortBy: 'dueDate');
      expect(searchResult.length, 1);
      expect(searchResult.first.id, '1');

      // Searching "e" should match all three tasks since they contain "e"
      final searchResult2 = processTasks(tasks, query: 'e', filter: 'all', sortBy: 'dueDate');
      expect(searchResult2.length, 3);
      expect(searchResult2.any((t) => t.id == '1'), true);
      expect(searchResult2.any((t) => t.id == '2'), true);
      expect(searchResult2.any((t) => t.id == '3'), true);
    });

    test('Filter by completion status', () {
      // Completed filter
      final completed = processTasks(tasks, query: '', filter: 'completed', sortBy: 'dueDate');
      expect(completed.length, 1);
      expect(completed.first.id, '2');

      // Pending filter
      final pending = processTasks(tasks, query: '', filter: 'pending', sortBy: 'dueDate');
      expect(pending.length, 2);
      expect(pending.any((t) => t.id == '1'), true);
      expect(pending.any((t) => t.id == '3'), true);
    });

    test('Sort by nearest due date', () {
      final sorted = processTasks(tasks, query: '', filter: 'all', sortBy: 'dueDate');
      expect(sorted.length, 3);
      expect(sorted[0].id, '2'); // Due in 1 day
      expect(sorted[1].id, '1'); // Due in 2 days
      expect(sorted[2].id, '3'); // Due in 3 days
    });

    test('Sort by priority (High -> Medium -> Low)', () {
      final sorted = processTasks(tasks, query: '', filter: 'all', sortBy: 'priority');
      expect(sorted.length, 3);
      expect(sorted[0].id, '3'); // High priority
      expect(sorted[1].id, '1'); // Medium priority
      expect(sorted[2].id, '2'); // Low priority
    });

    test('Composed Search -> Filter -> Sort', () {
      // Search: "t", Filter: "pending", Sort: "priority"
      // "Meeting with Team" (medium priority, matches "t")
      // "Submit assessment" (high priority, matches "t")
      // "Buy groceries" (is completed, filtered out)
      // Sorted by priority: "Submit assessment" (high) then "Meeting with Team" (medium)
      final result = processTasks(tasks, query: 't', filter: 'pending', sortBy: 'priority');
      expect(result.length, 2);
      expect(result[0].id, '3'); // Submit assessment
      expect(result[1].id, '1'); // Meeting with Team
    });
  });
}
