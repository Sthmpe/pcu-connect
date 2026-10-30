import '../../../../core/network/firebase_service.dart';
import '../../domain/models/user_profile.dart';

class AuthRemoteDatasource {
  final FirebaseService _firebaseService;

  AuthRemoteDatasource({FirebaseService? firebaseService})
    : _firebaseService = firebaseService ?? FirebaseService();

  Future<UserProfile?> signIn({
    required String email,
    required String password,
  }) async {
    final credential = await _firebaseService.auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );

    final user = credential.user;
    if (user == null) return null;

    return fetchProfile(user.uid);
  }

  /// Resolves identity separately from access. An organization owner may
  /// sign in before they have joined a unit; everyone else needs at least one
  /// active unit membership. A future context switcher can select a different
  /// membership without changing this neutral profile model.
  Future<UserProfile?> fetchProfile(String uid) async {
    final accessSnapshots = await Future.wait([
      _firebaseService.firestore
          .collection('organization_owners')
          .where('userId', isEqualTo: uid)
          .limit(1)
          .get(),
      _firebaseService.firestore
          .collection('team_memberships')
          .where('userId', isEqualTo: uid)
          .where('active', isEqualTo: true)
          .limit(1)
          .get(),
    ]);

    final ownerSnapshot = accessSnapshots[0];
    final membershipSnapshot = accessSnapshots[1];
    final profileDoc = await _firebaseService.firestore
        .collection('profiles')
        .doc(uid)
        .get();
    final owner = ownerSnapshot.docs.isEmpty
        ? null
        : ownerSnapshot.docs.first.data();
    final membership = membershipSnapshot.docs.isEmpty
        ? null
        : membershipSnapshot.docs.first.data();

    if (owner == null && membership == null) return null;
    final profile = profileDoc.data() ?? const {};
    final scope = Map<String, dynamic>.from(
      membership?['scope'] as Map? ?? const {},
    );
    final locationIds = List<String>.from(
      scope['locationIds'] as List? ?? const [],
    );
    final unitIds = List<String>.from(scope['unitIds'] as List? ?? const []);

    return UserProfile.fromJson({
      'id': uid,
      'fullName': profile['fullName'] ?? profile['full_name'],
      'phoneE164': profile['phoneE164'] ?? profile['phone_e164'],
      'baseRole': owner != null
          ? 'organization_owner'
          : membership?['baseRole'],
      'organizationId':
          owner?['organizationId'] ??
          membership?['organizationId'] ??
          scope['organizationId'],
      'locationId':
          membership?['locationId'] ??
          (locationIds.isEmpty ? '' : locationIds.first),
      'unitId': membership?['unitId'] ?? (unitIds.isEmpty ? '' : unitIds.first),
      'availabilityStatus': membership?['availabilityStatus'] ?? 'active',
    });
  }

  Future<void> signOut() async {
    await _firebaseService.auth.signOut();
  }
}
