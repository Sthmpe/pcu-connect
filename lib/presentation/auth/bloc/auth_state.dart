import 'package:equatable/equatable.dart';
import '../../../domain/entities/worker_user.dart';

abstract class AuthState extends Equatable {
  const AuthState();
  @override
  List<Object?> get props => [];
}

class AuthInitialState extends AuthState {}

class AuthLoadingState extends AuthState {}

class AuthAuthenticatedState extends AuthState {
  final WorkerUser user;
  final String idToken;

  const AuthAuthenticatedState({required this.user, required this.idToken});

  @override
  List<Object?> get props => [user, idToken];
}

class AuthUnauthorizedState extends AuthState {
  final String message;

  const AuthUnauthorizedState(this.message);

  @override
  List<Object?> get props => [message];
}

class AuthUnauthenticatedState extends AuthState {}

class AuthFailureState extends AuthState {
  final String message;

  const AuthFailureState(this.message);

  @override
  List<Object?> get props => [message];
}
