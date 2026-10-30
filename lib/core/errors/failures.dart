import 'package:equatable/equatable.dart';

/// Senior-Grade Domain Failure Hierarchy
abstract class Failure extends Equatable {
  final String message;
  final String? code;

  const Failure(this.message, [this.code]);

  @override
  List<Object?> get props => [message, code];
}

class ServerFailure extends Failure {
  const ServerFailure(super.message, [super.code]);
}

class AuthFailure extends Failure {
  const AuthFailure(super.message, [super.code]);
}

class NetworkFailure extends Failure {
  const NetworkFailure([super.message = 'No internet connection available.']);
}

class SecurityFailure extends Failure {
  const SecurityFailure([
    super.message = 'Access denied or insufficient permissions.',
  ]);
}

class ValidationFailure extends Failure {
  const ValidationFailure(super.message);
}
