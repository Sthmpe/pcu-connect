import '../../core/network/api_result.dart';
import '../entities/worker_user.dart';

abstract class IAuthRepository {
  /// Sign in with Google Web (or OAuth credential) and obtain ID token
  Future<ApiResult<String>> signInWithGoogle();

  /// Fetch worker profile from Apps Script / Sheet backend using ID token
  Future<ApiResult<WorkerUser>> getProfile(String idToken);

  /// Sign out
  Future<void> signOut();

  /// Currently cached ID token
  String? get currentIdToken;

  /// Currently authenticated user
  WorkerUser? get currentUser;
}
