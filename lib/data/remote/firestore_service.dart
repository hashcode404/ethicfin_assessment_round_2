import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/errors/exceptions.dart';
import '../../domain/entities/task.dart';
import '../models/task_model.dart';

class FirestoreService {
  final FirebaseFirestore _firestore;

  FirestoreService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _tasksCollection =>
      _firestore.collection('tasks');

  Future<void> setTask(Task task) async {
    try {
      final model = task is TaskModel ? task : TaskModel.fromEntity(task);
      await _tasksCollection
          .doc(task.id)
          .set(model.toRemoteMap())
          .timeout(const Duration(seconds: 10));
    } on FirebaseException catch (e) {
      throw _mapFirebaseException(e);
    } on TimeoutException {
      throw const NetworkException('Connection timeout while saving task');
    } catch (e) {
      throw RemoteException('Failed to save task to remote: $e');
    }
  }

  Future<void> deleteTask(String id) async {
    try {
      await _tasksCollection
          .doc(id)
          .delete()
          .timeout(const Duration(seconds: 10));
    } on FirebaseException catch (e) {
      throw _mapFirebaseException(e);
    } on TimeoutException {
      throw const NetworkException('Connection timeout while deleting task');
    } catch (e) {
      throw RemoteException('Failed to delete task from remote: $e');
    }
  }

  Future<TaskModel?> getTask(String id) async {
    try {
      final doc = await _tasksCollection
          .doc(id)
          .get()
          .timeout(const Duration(seconds: 10));
      if (doc.exists && doc.data() != null) {
        return TaskModel.fromRemoteMap(doc.data()!);
      }
      return null;
    } on FirebaseException catch (e) {
      throw _mapFirebaseException(e);
    } on TimeoutException {
      throw const NetworkException('Connection timeout while fetching task');
    } catch (e) {
      throw RemoteException('Failed to fetch task from remote: $e');
    }
  }

  Future<List<TaskModel>> fetchTasks(String userId) async {
    try {
      final querySnapshot = await _tasksCollection
          .where('userId', isEqualTo: userId)
          .get()
          .timeout(const Duration(seconds: 15));
      return querySnapshot.docs
          .map((doc) => TaskModel.fromRemoteMap(doc.data()))
          .toList();
    } on FirebaseException catch (e) {
      throw _mapFirebaseException(e);
    } on TimeoutException {
      throw const NetworkException('Connection timeout while fetching tasks');
    } catch (e) {
      throw RemoteException('Failed to fetch tasks from remote: $e');
    }
  }

  AppException _mapFirebaseException(FirebaseException e) {
    switch (e.code) {
      case 'permission-denied':
        return RemoteException('Permission denied: You do not have access to this resource.', e.code);
      case 'unavailable':
        return const NetworkException('Firestore service is temporarily unavailable. Check your internet connection.');
      case 'deadline-exceeded':
        return const NetworkException('The operation took too long. Please try again.');
      default:
        return RemoteException(e.message ?? 'An error occurred with the remote database.', e.code);
    }
  }
}
