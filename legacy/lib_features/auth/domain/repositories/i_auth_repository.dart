import '../models/user_profile.dart';

abstract class IAuthRepository {
  Future<UserProfile?> signInWithEmail({
    required String email,
    required String password,
  });

  Future<void> signOut();

  Future<UserProfile?> getCurrentUserProfile();
}
