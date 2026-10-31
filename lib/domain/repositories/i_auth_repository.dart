import '../../core/network/api_result.dart';
import '../entities/worker_user.dart';

abstract class IAuthRepository {
  /// Sign in with Google through Firebase Auth and return a Firebase ID token
  Future<ApiResult<String>> signInWithGoogle();

  /// Restore a persisted Firebase session. Returns a fresh ID token, or null
  /// when nobody is signed in.
  Future<String?> restoreSession();

  /// Fetch worker profile from Apps Script / Sheet backend using ID token
  Future<ApiResult<WorkerUser>> getProfile(String idToken);

  /// Returns the current ID token. With [forceRefresh] a new token is
  /// requested from Firebase. Returns null when there is no session or the
  /// token cannot be refreshed (for example a mock session).
  Future<String?> getIdToken({bool forceRefresh = false});

  /// Debug and test builds only: act as [email] using a mock token.
  void useMockSession(String email);

  /// Sign out (calls FirebaseAuth.signOut)
  Future<void> signOut();

  /// Currently cached ID token
  String? get currentIdToken;

  /// Currently authenticated user
  WorkerUser? get currentUser;
}
