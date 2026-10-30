import '../../../../core/network/edge_function_client.dart';
import '../../../../core/network/firebase_service.dart';
import '../../domain/models/delegation_member_model.dart';
import '../../domain/models/membership_model.dart';

class AccessControlException implements Exception {
  final String message;

  const AccessControlException(this.message);

  @override
  String toString() => message;
}

/// Own-membership reads use Firestore directly. Cross-user membership reads and
/// every authority-changing write go through manage-access, which verifies the
/// Firebase token and returns only a sanitized unit-scoped projection.
class AccessControlRemoteDatasource {
  final FirebaseService _firebaseService;
  final EdgeFunctionClient _edgeFunctionClient;

  AccessControlRemoteDatasource({
    FirebaseService? firebaseService,
    EdgeFunctionClient? edgeFunctionClient,
  }) : _firebaseService = firebaseService ?? FirebaseService(),
       _edgeFunctionClient = edgeFunctionClient ?? EdgeFunctionClient();

  Future<MembershipModel?> fetchOwnMembership({required String unitId}) async {
    final uid = _firebaseService.currentUser?.uid;
    if (uid == null) return null;

    final document = await _firebaseService.firestore
        .collection('team_memberships')
        .doc([unitId, uid].join('_'))
        .get();
    if (!document.exists) return null;
    return MembershipModel.fromJson(document.id, document.data()!);
  }

  Future<DelegationPageResult> fetchDelegationPage({
    required String unitId,
    String? cursor,
    int limit = 50,
  }) async {
    final idToken = await _requireIdToken();
    final result = await _edgeFunctionClient.invoke(
      'manage-access',
      body: {
        'action': 'list',
        'firebaseIdToken': idToken,
        'unitId': unitId,
        'limit': limit,
        'cursor': ?cursor,
      },
    );

    return result.when(
      success: (data) {
        final rawMembers = data['members'] as List? ?? const [];
        final rawPermissions =
            data['delegablePermissions'] as List? ?? const [];
        return DelegationPageResult(
          members: rawMembers
              .whereType<Map>()
              .map(
                (member) => DelegationMemberModel.fromJson(
                  Map<String, dynamic>.from(member),
                ),
              )
              .toList(growable: false),
          delegablePermissions: Set.unmodifiable(
            rawPermissions.whereType<String>(),
          ),
          nextCursor: data['nextCursor'] as String?,
        );
      },
      failure: (failure) => throw AccessControlException(failure.message),
    );
  }

  Future<void> grantMembership({
    required String recipientUserId,
    required String unitId,
    required String baseRole,
    required String permissionPreset,
    required Set<String> permissions,
    String? reason,
  }) async {
    final idToken = await _requireIdToken();
    final result = await _edgeFunctionClient.invoke(
      'manage-access',
      body: {
        'action': 'grant',
        'firebaseIdToken': idToken,
        'recipientUserId': recipientUserId,
        'unitId': unitId,
        'baseRole': baseRole,
        'permissionPreset': permissionPreset,
        'permissions': permissions.toList(growable: false),
        'reason': ?reason,
      },
    );
    result.when(
      success: (_) {},
      failure: (failure) => throw AccessControlException(failure.message),
    );
  }

  Future<void> revokeMembership({
    required String membershipId,
    String? reason,
  }) async {
    final idToken = await _requireIdToken();
    final result = await _edgeFunctionClient.invoke(
      'manage-access',
      body: {
        'action': 'revoke',
        'firebaseIdToken': idToken,
        'membershipId': membershipId,
        'reason': ?reason,
      },
    );
    result.when(
      success: (_) {},
      failure: (failure) => throw AccessControlException(failure.message),
    );
  }

  Future<String> _requireIdToken() async {
    final token = await _firebaseService.currentUser?.getIdToken();
    if (token == null || token.isEmpty) {
      throw const AccessControlException(
        'Your session has expired. Sign in again.',
      );
    }
    return token;
  }
}
