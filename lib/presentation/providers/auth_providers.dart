import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/auth_repository.dart';
import 'firebase_providers.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final firebaseAvailable = ref.watch(firebaseAvailableProvider);
  if (firebaseAvailable) {
    return AuthRepositoryImpl();
  } else {
    // If Firebase is unavailable, return a dummy/local repository
    return DummyAuthRepository();
  }
});

final authStateProvider = StreamProvider<User?>((ref) {
  final repo = ref.watch(authRepositoryProvider);
  return repo.authStateChanges;
});

final guestModeProvider = StateProvider<bool>((ref) => false);

final currentUserIdProvider = Provider<String>((ref) {
  final authState = ref.watch(authStateProvider).value;
  final isGuest = ref.watch(guestModeProvider);
  
  if (authState != null) {
    return authState.uid;
  }
  
  if (isGuest) {
    return 'guest_user';
  }
  
  return 'guest_user';
});

class DummyAuthRepository implements AuthRepository {
  @override
  Stream<User?> get authStateChanges => Stream.value(null);

  @override
  User? get currentUser => null;

  @override
  Future<User?> signInWithEmail(String email, String password) async {
    throw UnimplementedError('Firebase is not configured.');
  }

  @override
  Future<User?> signUpWithEmail(String email, String password) async {
    throw UnimplementedError('Firebase is not configured.');
  }

  @override
  Future<void> signOut() async {}
}
