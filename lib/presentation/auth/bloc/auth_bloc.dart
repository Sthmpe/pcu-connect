import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../domain/entities/worker_user.dart';
import '../../../domain/repositories/i_auth_repository.dart';
import 'auth_event.dart';
import 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final IAuthRepository _authRepository;

  AuthBloc({required IAuthRepository authRepository})
      : _authRepository = authRepository,
        super(AuthInitialState()) {
    on<AuthCheckSessionEvent>(_onCheckSession);
    on<AuthSignInRequestedEvent>(_onSignInRequested);
    on<AuthMockSignInRequestedEvent>(_onMockSignInRequested);
    on<AuthSignOutRequestedEvent>(_onSignOutRequested);
  }

  Future<void> _onCheckSession(
    AuthCheckSessionEvent event,
    Emitter<AuthState> emit,
  ) async {
    final token = _authRepository.currentIdToken;
    final user = _authRepository.currentUser;

    if (token != null && user != null) {
      if (!user.active) {
        emit(const AuthUnauthorizedState(
            'Your account is inactive. Please contact your HOD.'));
      } else {
        emit(AuthAuthenticatedState(user: user, idToken: token));
      }
    } else {
      emit(AuthUnauthenticatedState());
    }
  }

  Future<void> _onSignInRequested(
    AuthSignInRequestedEvent event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoadingState());
    final tokenResult = await _authRepository.signInWithGoogle();

    if (tokenResult.isFailure) {
      emit(AuthFailureState(tokenResult.failure!.message));
      return;
    }

    final idToken = tokenResult.data!;
    final profileResult = await _authRepository.getProfile(idToken);

    if (profileResult.isFailure) {
      final msg = profileResult.failure!.message;
      if (msg.contains('No access') || msg.contains('inactive')) {
        emit(AuthUnauthorizedState(msg));
      } else {
        emit(AuthFailureState(msg));
      }
      return;
    }

    final user = profileResult.data!;
    emit(AuthAuthenticatedState(user: user, idToken: idToken));
  }

  Future<void> _onMockSignInRequested(
    AuthMockSignInRequestedEvent event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoadingState());
    // For local dev/test fast-switching between Worker (David) and Admin (Opeyemi)
    final user = WorkerUser(
      id: event.role == 'Admin' ? 'W001' : 'W005',
      name: event.role == 'Admin' ? 'Opeyemi Olanite' : 'David Olanite',
      email: event.email,
      phone: '0803 555 0100',
      role: event.role,
      active: true,
    );
    emit(AuthAuthenticatedState(user: user, idToken: 'mock_token_${event.email}'));
  }

  Future<void> _onSignOutRequested(
    AuthSignOutRequestedEvent event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoadingState());
    await _authRepository.signOut();
    emit(AuthUnauthenticatedState());
  }
}
