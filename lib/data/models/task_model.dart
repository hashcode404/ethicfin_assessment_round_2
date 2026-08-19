import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/task.dart';

class TaskModel extends Task {
  const TaskModel({
    required super.id,
    super.userId = 'guest_user',
    required super.title,
    required super.description,
    required super.priority,
    required super.dueDate,
    required super.isCompleted,
    required super.createdAt,
    required super.syncStatus,
    required super.lastModifiedAt,
  });

  // Factory constructor to create a TaskModel from a Task
  factory TaskModel.fromEntity(Task task) {
    return TaskModel(
      id: task.id,
      userId: task.userId,
      title: task.title,
      description: task.description,
      priority: task.priority,
      dueDate: task.dueDate,
      isCompleted: task.isCompleted,
      createdAt: task.createdAt,
      syncStatus: task.syncStatus,
      lastModifiedAt: task.lastModifiedAt,
    );
  }

  // Convert to database map (SQLite)
  Map<String, dynamic> toLocalMap() {
    return {
      'id': id,
      'userId': userId,
      'title': title,
      'description': description,
      'priority': priority.name,
      'dueDate': dueDate.toIso8601String(),
      'isCompleted': isCompleted ? 1 : 0,
      'createdAt': createdAt.toIso8601String(),
      'syncStatus': syncStatus.name,
      'lastModifiedAt': lastModifiedAt.toIso8601String(),
    };
  }

  // Create TaskModel from SQLite database map
  factory TaskModel.fromLocalMap(Map<String, dynamic> map) {
    return TaskModel(
      id: map['id'] as String,
      userId: map['userId'] as String? ?? 'guest_user',
      title: map['title'] as String,
      description: map['description'] as String? ?? '',
      priority: TaskPriority.fromJson(map['priority'] as String? ?? 'medium'),
      dueDate: DateTime.parse(map['dueDate'] as String),
      isCompleted: (map['isCompleted'] as int) == 1,
      createdAt: DateTime.parse(map['createdAt'] as String),
      syncStatus: SyncStatus.fromJson(map['syncStatus'] as String? ?? 'synced'),
      lastModifiedAt: DateTime.parse(map['lastModifiedAt'] as String? ?? map['createdAt'] as String),
    );
  }

  // Convert to Firestore map (remote)
  Map<String, dynamic> toRemoteMap() {
    return {
      'id': id,
      'userId': userId,
      'title': title,
      'description': description,
      'priority': priority.name,
      'dueDate': Timestamp.fromDate(dueDate),
      'isCompleted': isCompleted,
      'createdAt': Timestamp.fromDate(createdAt),
      'lastModifiedAt': Timestamp.fromDate(lastModifiedAt),
    };
  }

  // Create TaskModel from Firestore map
  factory TaskModel.fromRemoteMap(Map<String, dynamic> map, {SyncStatus? syncStatus}) {
    DateTime parseDateTime(dynamic value) {
      if (value is Timestamp) {
        return value.toDate();
      } else if (value is String) {
        return DateTime.parse(value);
      } else if (value is int) {
        return DateTime.fromMillisecondsSinceEpoch(value);
      }
      return DateTime.now();
    }

    return TaskModel(
      id: map['id'] as String,
      userId: map['userId'] as String? ?? 'guest_user',
      title: map['title'] as String,
      description: map['description'] as String? ?? '',
      priority: TaskPriority.fromJson(map['priority'] as String? ?? 'medium'),
      dueDate: parseDateTime(map['dueDate']),
      isCompleted: map['isCompleted'] as bool? ?? false,
      createdAt: parseDateTime(map['createdAt']),
      syncStatus: syncStatus ?? SyncStatus.synced,
      lastModifiedAt: parseDateTime(map['lastModifiedAt'] ?? map['createdAt']),
    );
  }

  // Standard fromJson/toJson for generic use cases (like unit testing)
  factory TaskModel.fromJson(Map<String, dynamic> map) {
    DateTime parseDateTime(dynamic value) {
      if (value is Timestamp) {
        return value.toDate();
      } else if (value is String) {
        return DateTime.parse(value);
      } else if (value is int) {
        return DateTime.fromMillisecondsSinceEpoch(value);
      }
      return DateTime.now();
    }

    return TaskModel(
      id: map['id'] as String,
      userId: map['userId'] as String? ?? 'guest_user',
      title: map['title'] as String,
      description: map['description'] as String? ?? '',
      priority: TaskPriority.fromJson(map['priority'] as String? ?? 'medium'),
      dueDate: parseDateTime(map['dueDate']),
      isCompleted: map['isCompleted'] == true || map['isCompleted'] == 1,
      createdAt: parseDateTime(map['createdAt']),
      syncStatus: map['syncStatus'] != null 
          ? SyncStatus.fromJson(map['syncStatus'] as String) 
          : SyncStatus.synced,
      lastModifiedAt: parseDateTime(map['lastModifiedAt'] ?? map['createdAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'title': title,
      'description': description,
      'priority': priority.name,
      'dueDate': dueDate.toIso8601String(),
      'isCompleted': isCompleted,
      'createdAt': createdAt.toIso8601String(),
      'syncStatus': syncStatus.name,
      'lastModifiedAt': lastModifiedAt.toIso8601String(),
    };
  }
}
