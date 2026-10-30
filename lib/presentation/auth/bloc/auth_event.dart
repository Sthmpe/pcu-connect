import 'package:equatable/equatable.dart';

abstract class AuthEvent extends Equatable {
  const AuthEvent();
  @override
  List<Object?> get props => [];
}

class AuthCheckSessionEvent extends AuthEvent {}

class AuthSignInRequestedEvent extends AuthEvent {}

class AuthMockSignInRequestedEvent extends AuthEvent {
  final String email;
  final String role; // 'Worker' or 'Admin'

  const AuthMockSignInRequestedEvent({required this.email, required this.role});

  @override
  List<Object?> get props => [email, role];
}

class AuthSignOutRequestedEvent extends AuthEvent {}
