import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/repositories/task_repository.dart';
import 'network_info.dart';

enum SyncStateStatus {
  synced,
  syncing,
  failed,
  offline
}

class SyncState {
  final SyncStateStatus status;
  final String? errorMessage;
  final DateTime? lastSyncTime;

  const SyncState({
    required this.status,
    this.errorMessage,
    this.lastSyncTime,
  });

  SyncState copyWith({
    SyncStateStatus? status,
    String? errorMessage,
    DateTime? lastSyncTime,
  }) {
    return SyncState(
      status: status ?? this.status,
      errorMessage: errorMessage ?? this.errorMessage,
      lastSyncTime: lastSyncTime ?? this.lastSyncTime,
    );
  }
}

class SyncService extends StateNotifier<SyncState> {
  final TaskRepository _taskRepository;
  final NetworkInfo _networkInfo;
  StreamSubscription? _connectivitySubscription;
  bool _isFirstLoad = true;

  SyncService({
    required TaskRepository taskRepository,
    required NetworkInfo networkInfo,
  })  : _taskRepository = taskRepository,
        _networkInfo = networkInfo,
        super(const SyncState(status: SyncStateStatus.synced)) {
    _initConnectivityListener();
  }

  void _initConnectivityListener() {
    _connectivitySubscription = _networkInfo.onConnectivityChanged.listen((results) async {
      final isOffline = results.contains(ConnectivityResult.none);
      
      if (isOffline) {
        state = state.copyWith(status: SyncStateStatus.offline);
      } else {
        // If we transition from offline to online, or on first startup when online, trigger sync
        if (state.status == SyncStateStatus.offline || _isFirstLoad) {
          _isFirstLoad = false;
          await sync();
        } else {
          state = state.copyWith(status: SyncStateStatus.synced);
        }
      }
    });

    // Check initial connection status
    _networkInfo.isConnected.then((connected) {
      if (!connected) {
        state = state.copyWith(status: SyncStateStatus.offline);
      } else {
        sync();
      }
    });
  }

  Future<void> sync() async {
    if (state.status == SyncStateStatus.offline) {
      // Re-verify actual connection
      final connected = await _networkInfo.isConnected;
      if (!connected) return;
    }

    state = state.copyWith(status: SyncStateStatus.syncing);
    try {
      await _taskRepository.syncPendingTasks();
      state = state.copyWith(
        status: SyncStateStatus.synced,
        lastSyncTime: DateTime.now(),
        errorMessage: null,
      );
    } catch (e) {
      state = state.copyWith(
        status: SyncStateStatus.failed,
        errorMessage: e.toString(),
      );
    }
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    super.dispose();
  }
}
