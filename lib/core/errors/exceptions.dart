abstract class AppException implements Exception {
  final String message;
  final String? code;

  const AppException(this.message, [this.code]);

  @override
  String toString() => message;
}

class NetworkException extends AppException {
  const NetworkException([super.message = 'No internet connection', super.code]);
}

class DatabaseException extends AppException {
  const DatabaseException(super.message, [super.code]);
}

class RemoteException extends AppException {
  const RemoteException(super.message, [super.code]);
}

class ValidationException extends AppException {
  const ValidationException(super.message, [super.code]);
}

class AuthException extends AppException {
  const AuthException(super.message, [super.code]);
}
