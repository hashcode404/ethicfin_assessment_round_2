import 'package:firebase_auth/firebase_auth.dart';
import '../../core/errors/exceptions.dart';

abstract class AuthRepository {
  Future<User?> signInWithEmail(String email, String password);
  Future<User?> signUpWithEmail(String email, String password);
  Future<void> signOut();
  Stream<User?> get authStateChanges;
  User? get currentUser;
}

class AuthRepositoryImpl implements AuthRepository {
  final FirebaseAuth _firebaseAuth;

  AuthRepositoryImpl({FirebaseAuth? firebaseAuth})
      : _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance;

  @override
  Stream<User?> get authStateChanges => _firebaseAuth.authStateChanges();

  @override
  User? get currentUser => _firebaseAuth.currentUser;

  @override
  Future<User?> signInWithEmail(String email, String password) async {
    try {
      final credential = await _firebaseAuth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return credential.user;
    } on FirebaseAuthException catch (e) {
      throw _mapAuthException(e);
    } catch (e) {
      throw AuthException('Failed to sign in: $e');
    }
  }

  @override
  Future<User?> signUpWithEmail(String email, String password) async {
    try {
      final credential = await _firebaseAuth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      return credential.user;
    } on FirebaseAuthException catch (e) {
      throw _mapAuthException(e);
    } catch (e) {
      throw AuthException('Failed to create account: $e');
    }
  }

  @override
  Future<void> signOut() async {
    try {
      await _firebaseAuth.signOut();
    } catch (e) {
      throw AuthException('Failed to sign out: $e');
    }
  }

  AppException _mapAuthException(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return const AuthException('No user found for that email address.', 'user-not-found');
      case 'wrong-password':
        return const AuthException('Incorrect password provided.', 'wrong-password');
      case 'email-already-in-use':
        return const AuthException('An account already exists for that email.', 'email-already-in-use');
      case 'invalid-email':
        return const AuthException('The email address is invalid.', 'invalid-email');
      case 'weak-password':
        return const AuthException('The password provided is too weak.', 'weak-password');
      case 'user-disabled':
        return const AuthException('This user account has been disabled.', 'user-disabled');
      case 'network-request-failed':
        return const NetworkException('Network error occurred. Please check your connection.');
      default:
        return AuthException(e.message ?? 'Authentication error occurred.', e.code);
    }
  }
}
