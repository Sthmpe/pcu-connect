import '../models/delegation_member_model.dart';
import '../models/membership_model.dart';

abstract class IAccessControlRepository {
  Future<MembershipModel?> fetchOwnMembership({required String unitId});

  Future<DelegationPageResult> fetchDelegationPage({
    required String unitId,
    String? cursor,
    int limit = 50,
  });

  Future<void> grantMembership({
    required String recipientUserId,
    required String unitId,
    required String baseRole,
    required String permissionPreset,
    required Set<String> permissions,
    String? reason,
  });

  Future<void> revokeMembership({required String membershipId, String? reason});
}
