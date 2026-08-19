enum TaskPriority {
  low,
  medium,
  high;

  String toJson() => name;

  static TaskPriority fromJson(String value) {
    return TaskPriority.values.firstWhere(
      (e) => e.name == value.toLowerCase(),
      orElse: () => TaskPriority.medium,
    );
  }
}

enum SyncStatus {
  synced,
  pendingCreate,
  pendingUpdate,
  pendingDelete,
  failed;

  String toJson() => name;

  static SyncStatus fromJson(String value) {
    return SyncStatus.values.firstWhere(
      (e) => e.name == value,
      orElse: () => SyncStatus.synced,
    );
  }
}

class Task {
  final String id;
  final String userId;
  final String title;
  final String description;
  final TaskPriority priority;
  final DateTime dueDate;
  final bool isCompleted;
  final DateTime createdAt;
  final SyncStatus syncStatus;
  final DateTime lastModifiedAt;

  const Task({
    required this.id,
    this.userId = 'guest_user',
    required this.title,
    required this.description,
    required this.priority,
    required this.dueDate,
    required this.isCompleted,
    required this.createdAt,
    required this.syncStatus,
    required this.lastModifiedAt,
  });

  Task copyWith({
    String? id,
    String? userId,
    String? title,
    String? description,
    TaskPriority? priority,
    DateTime? dueDate,
    bool? isCompleted,
    DateTime? createdAt,
    SyncStatus? syncStatus,
    DateTime? lastModifiedAt,
  }) {
    return Task(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      description: description ?? this.description,
      priority: priority ?? this.priority,
      dueDate: dueDate ?? this.dueDate,
      isCompleted: isCompleted ?? this.isCompleted,
      createdAt: createdAt ?? this.createdAt,
      syncStatus: syncStatus ?? this.syncStatus,
      lastModifiedAt: lastModifiedAt ?? this.lastModifiedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Task &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          userId == other.userId &&
          title == other.title &&
          description == other.description &&
          priority == other.priority &&
          dueDate == other.dueDate &&
          isCompleted == other.isCompleted &&
          createdAt == other.createdAt &&
          syncStatus == other.syncStatus &&
          lastModifiedAt == other.lastModifiedAt;

  @override
  int get hashCode =>
      id.hashCode ^
      userId.hashCode ^
      title.hashCode ^
      description.hashCode ^
      priority.hashCode ^
      dueDate.hashCode ^
      isCompleted.hashCode ^
      createdAt.hashCode ^
      syncStatus.hashCode ^
      lastModifiedAt.hashCode;
}
