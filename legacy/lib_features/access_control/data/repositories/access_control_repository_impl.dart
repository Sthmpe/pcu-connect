import '../../domain/models/delegation_member_model.dart';
import '../../domain/models/membership_model.dart';
import '../../domain/repositories/i_access_control_repository.dart';
import '../datasources/access_control_remote_datasource.dart';

class AccessControlRepositoryImpl implements IAccessControlRepository {
  final AccessControlRemoteDatasource _remoteDatasource;

  AccessControlRepositoryImpl({AccessControlRemoteDatasource? remoteDatasource})
    : _remoteDatasource = remoteDatasource ?? AccessControlRemoteDatasource();

  @override
  Future<MembershipModel?> fetchOwnMembership({required String unitId}) {
    return _remoteDatasource.fetchOwnMembership(unitId: unitId);
  }

  @override
  Future<DelegationPageResult> fetchDelegationPage({
    required String unitId,
    String? cursor,
    int limit = 50,
  }) {
    return _remoteDatasource.fetchDelegationPage(
      unitId: unitId,
      cursor: cursor,
      limit: limit,
    );
  }

  @override
  Future<void> grantMembership({
    required String recipientUserId,
    required String unitId,
    required String baseRole,
    required String permissionPreset,
    required Set<String> permissions,
    String? reason,
  }) {
    return _remoteDatasource.grantMembership(
      recipientUserId: recipientUserId,
      unitId: unitId,
      baseRole: baseRole,
      permissionPreset: permissionPreset,
      permissions: permissions,
      reason: reason,
    );
  }

  @override
  Future<void> revokeMembership({
    required String membershipId,
    String? reason,
  }) {
    return _remoteDatasource.revokeMembership(
      membershipId: membershipId,
      reason: reason,
    );
  }
}
