import 'package:firebase_auth/firebase_auth.dart';
import '../../core/errors/failures.dart';
import '../../core/network/api_client.dart';
import '../../core/network/api_result.dart';
import '../../domain/entities/worker_user.dart';
import '../../domain/repositories/i_auth_repository.dart';

class AuthRepositoryImpl implements IAuthRepository {
  final ApiClient _apiClient;
  final FirebaseAuth? _auth;

  /// When set (Firestore mode), the role comes from here instead of the
  /// Apps Script `me` action. Mock sessions still use the API.
  final Future<ApiResult<WorkerUser>> Function()? _profileLoader;

  String? _cachedIdToken;
  WorkerUser? _cachedUser;
  bool _isMock = false;

  AuthRepositoryImpl({
    required ApiClient apiClient,
    FirebaseAuth? auth,
    Future<ApiResult<WorkerUser>> Function()? profileLoader,
  })  : _apiClient = apiClient,
        _auth = auth,
        _profileLoader = profileLoader;

  // Resolved lazily so tests that never sign in do not need Firebase.
  FirebaseAuth get _firebaseAuth => _auth ?? FirebaseAuth.instance;

  @override
  String? get currentIdToken => _cachedIdToken;

  @override
  WorkerUser? get currentUser => _cachedUser;

  @override
  Future<ApiResult<String>> signInWithGoogle() async {
    try {
      final provider = GoogleAuthProvider()
        ..addScope('email')
        ..addScope('profile');
      final credential = await _firebaseAuth.signInWithPopup(provider);
      final token = await credential.user?.getIdToken();
      if (token == null || token.isEmpty) {
        return const ApiResult.failure(
          AuthFailure('Could not get a sign-in token. Please try again.'),
        );
      }
      _isMock = false;
      _cachedIdToken = token;
      return ApiResult.success(token);
    } on FirebaseAuthException catch (e) {
      if (e.code == 'popup-closed-by-user' ||
          e.code == 'cancelled-popup-request') {
        return const ApiResult.failure(AuthFailure('Sign in was canceled.'));
      }
      if (e.code == 'popup-blocked') {
        return const ApiResult.failure(AuthFailure('Your browser blocked the sign-in window. Allow pop-ups and try again.'));
      }
      if (e.code == 'network-request-failed') {
        return const ApiResult.failure(AuthFailure('We could not reach Google. Check your connection and try again.'));
      }
      return ApiResult.failure(AuthFailure(e.message ?? 'Sign in did not work. Please try again.'));
    } catch (_) {
      return const ApiResult.failure(AuthFailure('Sign in did not work. Please try again.'));
    }
  }

  @override
  Future<String?> restoreSession() async {
    try {
      // Firebase restores its persisted session asynchronously on web.
      final user = await _firebaseAuth.authStateChanges().first;
      if (user == null) return null;
      final token = await user.getIdToken();
      _isMock = false;
      _cachedIdToken = token;
      return token;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<String?> getIdToken({bool forceRefresh = false}) async {
    if (_isMock) return forceRefresh ? null : _cachedIdToken;
    try {
      final user = _firebaseAuth.currentUser;
      if (user == null) return forceRefresh ? null : _cachedIdToken;
      final token = await user.getIdToken(forceRefresh);
      _cachedIdToken = token;
      return token;
    } catch (_) {
      return null;
    }
  }

  @override
  void useMockSession(String email) {
    _isMock = true;
    _cachedIdToken = 'mock_token_$email';
  }

  @override
  Future<ApiResult<WorkerUser>> getProfile(String idToken) async {
    _cachedIdToken = idToken;
    final loader = _profileLoader;
    if (loader != null && !_isMock) {
      final profile = await loader();
      if (profile.isSuccess) _cachedUser = profile.data;
      return profile;
    }
    final result = await _apiClient.postAction(
      action: 'me',
      idToken: idToken,
    );

    if (result.isSuccess) {
      try {
        final data = result.data;
        if (data is Map<String, dynamic>) {
          final user = WorkerUser.fromJson(data);
          if (!user.active) {
            return const ApiResult.failure(
              AuthFailure('Your account is inactive. Please contact your HOD.'),
            );
          }
          _cachedUser = user;
          return ApiResult.success(user);
        } else {
          return const ApiResult.failure(
            ServerFailure('Invalid profile response format.'),
          );
        }
      } catch (e) {
        return ApiResult.failure(ServerFailure(e.toString()));
      }
    } else {
      return ApiResult.failure(result.failure!);
    }
  }

  @override
  Future<void> signOut() async {
    try {
      if (!_isMock) await _firebaseAuth.signOut();
    } catch (_) {}
    _isMock = false;
    _cachedIdToken = null;
    _cachedUser = null;
  }
}
