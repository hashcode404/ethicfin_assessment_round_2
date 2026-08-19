import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ethicfin_assessment_round_2/domain/entities/task.dart';
import 'package:ethicfin_assessment_round_2/data/models/task_model.dart';

void main() {
  group('TaskModel Tests', () {
    final testDate = DateTime(2026, 8, 20, 12, 0);
    
    final taskModel = TaskModel(
      id: 'task-123',
      title: 'Test Task',
      description: 'Test Description',
      priority: TaskPriority.high,
      dueDate: testDate,
      isCompleted: false,
      createdAt: testDate,
      syncStatus: SyncStatus.pendingCreate,
      lastModifiedAt: testDate,
    );

    test('toJson and fromJson symmetry', () {
      final json = taskModel.toJson();
      expect(json['id'], 'task-123');
      expect(json['title'], 'Test Task');
      expect(json['priority'], 'high');
      expect(json['syncStatus'], 'pendingCreate');

      final parsed = TaskModel.fromJson(json);
      expect(parsed, equals(taskModel));
    });

    test('toLocalMap and fromLocalMap symmetry (SQLite)', () {
      final localMap = taskModel.toLocalMap();
      expect(localMap['id'], 'task-123');
      expect(localMap['isCompleted'], 0); // Boolean mapped to 0
      expect(localMap['priority'], 'high');

      final parsed = TaskModel.fromLocalMap(localMap);
      expect(parsed.id, taskModel.id);
      expect(parsed.isCompleted, taskModel.isCompleted);
      expect(parsed.priority, taskModel.priority);
      expect(parsed.syncStatus, taskModel.syncStatus);
    });

    test('toRemoteMap and fromRemoteMap compatibility (Firestore)', () {
      final remoteMap = taskModel.toRemoteMap();
      expect(remoteMap['id'], 'task-123');
      expect(remoteMap['dueDate'], isA<Timestamp>());
      expect(remoteMap['isCompleted'], false);

      final parsed = TaskModel.fromRemoteMap(remoteMap, syncStatus: SyncStatus.synced);
      expect(parsed.id, taskModel.id);
      expect(parsed.dueDate, taskModel.dueDate);
      expect(parsed.isCompleted, taskModel.isCompleted);
      expect(parsed.syncStatus, SyncStatus.synced);
    });
  });
}
