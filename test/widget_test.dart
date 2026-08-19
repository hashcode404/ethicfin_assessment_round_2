import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ethicfin_assessment_round_2/presentation/screens/task_list_screen.dart';
import 'package:ethicfin_assessment_round_2/presentation/providers/firebase_providers.dart';
import 'package:ethicfin_assessment_round_2/presentation/providers/task_providers.dart';
import 'package:ethicfin_assessment_round_2/domain/repositories/task_repository.dart';
import 'package:ethicfin_assessment_round_2/domain/entities/task.dart';

class FakeTaskRepository implements TaskRepository {
  @override
  Future<List<Task>> getTasks() async {
    return [];
  }

  @override
  Future<void> createTask(Task task) async {}

  @override
  Future<void> updateTask(Task task) async {}

  @override
  Future<void> deleteTask(String taskId) async {}

  @override
  Future<void> syncPendingTasks() async {}
}

void main() {
  testWidgets('TaskSpace App Title and UI Smoke Test', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          firebaseAvailableProvider.overrideWithValue(false),
          taskRepositoryProvider.overrideWithValue(FakeTaskRepository()),
        ],
        child: const MaterialApp(
          home: TaskListScreen(),
        ),
      ),
    );

    // Wait for the widgets to render and async operations to resolve
    await tester.pumpAndSettle();

    // Verify app title is displayed
    expect(find.text('Task Space'), findsOneWidget);

    // Verify Add Task FAB is displayed
    expect(find.text('Add Task'), findsOneWidget);

    // Verify Filter Chip is displayed
    expect(find.text('ALL'), findsOneWidget);
  });
}
