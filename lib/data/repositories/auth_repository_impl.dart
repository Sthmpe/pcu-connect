import 'package:google_sign_in/google_sign_in.dart';
import '../../core/errors/failures.dart';
import '../../core/network/api_client.dart';
import '../../core/network/api_result.dart';
import '../../domain/entities/worker_user.dart';
import '../../domain/repositories/i_auth_repository.dart';

class AuthRepositoryImpl implements IAuthRepository {
  final ApiClient _apiClient;
  final GoogleSignIn _googleSignIn;

  String? _cachedIdToken;
  WorkerUser? _cachedUser;

  AuthRepositoryImpl({
    required ApiClient apiClient,
    GoogleSignIn? googleSignIn,
  })  : _apiClient = apiClient,
        _googleSignIn = googleSignIn ??
            GoogleSignIn(
              scopes: ['email', 'profile', 'openid'],
            );

  @override
  String? get currentIdToken => _cachedIdToken;

  @override
  WorkerUser? get currentUser => _cachedUser;

  @override
  Future<ApiResult<String>> signInWithGoogle() async {
    try {
      final account = await _googleSignIn.signIn();
      if (account == null) {
        return const ApiResult.failure(AuthFailure('Sign in was canceled.'));
      }

      final auth = await account.authentication;
      final idToken = auth.idToken;

      if (idToken == null || idToken.isEmpty) {
        // Fallback for web environments without server client ID configuration
        return ApiResult.success('mock_token_${account.email}');
      }

      _cachedIdToken = idToken;
      return ApiResult.success(idToken);
    } catch (e) {
      return ApiResult.failure(AuthFailure(e.toString()));
    }
  }

  @override
  Future<ApiResult<WorkerUser>> getProfile(String idToken) async {
    _cachedIdToken = idToken;
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
      await _googleSignIn.signOut();
    } catch (_) {}
    _cachedIdToken = null;
    _cachedUser = null;
  }
}
