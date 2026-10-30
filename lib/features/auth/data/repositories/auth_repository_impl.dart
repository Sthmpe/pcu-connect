import '../../../../core/network/firebase_service.dart';
import '../../domain/models/user_profile.dart';
import '../../domain/repositories/i_auth_repository.dart';
import '../datasources/auth_remote_datasource.dart';

class AuthRepositoryImpl implements IAuthRepository {
  final AuthRemoteDatasource _remoteDatasource;
  final FirebaseService _firebaseService;

  AuthRepositoryImpl({
    AuthRemoteDatasource? remoteDatasource,
    FirebaseService? firebaseService,
  }) : _remoteDatasource = remoteDatasource ?? AuthRemoteDatasource(),
       _firebaseService = firebaseService ?? FirebaseService();

  @override
  Future<UserProfile?> signInWithEmail({
    required String email,
    required String password,
  }) async {
    return _remoteDatasource.signIn(email: email, password: password);
  }

  @override
  Future<void> signOut() async {
    await _remoteDatasource.signOut();
  }

  @override
  Future<UserProfile?> getCurrentUserProfile() async {
    final user = _firebaseService.currentUser;
    if (user == null) return null;
    return _remoteDatasource.fetchProfile(user.uid);
  }
}
