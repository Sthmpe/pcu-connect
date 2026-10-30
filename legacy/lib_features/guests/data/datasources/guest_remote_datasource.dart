import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/network/firebase_service.dart';
import '../../domain/models/guest_model.dart';

class GuestRemoteDatasource {
  final FirebaseService _firebaseService;

  GuestRemoteDatasource({FirebaseService? firebaseService})
    : _firebaseService = firebaseService ?? FirebaseService();

  Future<List<GuestModel>> getAssignedGuests({
    required String operatorId,
    String? stageFilter,
  }) async {
    Query query = _firebaseService.firestore
        .collection('contacts')
        .where('assignedOperatorId', isEqualTo: operatorId);

    if (stageFilter != null && stageFilter.isNotEmpty && stageFilter != 'all') {
      query = query.where('currentStage', isEqualTo: stageFilter);
    }

    final snapshot = await query.orderBy('receivedAt', descending: true).get();
    return snapshot.docs
        .map(
          (doc) => GuestModel.fromJson({
            'id': doc.id,
            ...doc.data() as Map<String, dynamic>,
          }),
        )
        .toList();
  }

  Future<List<GuestModel>> getAllUnitContacts({
    required String unitId,
    String? stageFilter,
  }) async {
    Query query = _firebaseService.firestore
        .collection('contacts')
        .where('unitId', isEqualTo: unitId);

    if (stageFilter != null && stageFilter.isNotEmpty && stageFilter != 'all') {
      query = query.where('currentStage', isEqualTo: stageFilter);
    }

    final snapshot = await query.orderBy('receivedAt', descending: true).get();
    return snapshot.docs
        .map(
          (doc) => GuestModel.fromJson({
            'id': doc.id,
            ...doc.data() as Map<String, dynamic>,
          }),
        )
        .toList();
  }

  Future<GuestModel?> getContactDetail(String contactId) async {
    final doc = await _firebaseService.firestore
        .collection('contacts')
        .doc(contactId)
        .get();
    if (!doc.exists) return null;
    return GuestModel.fromJson({'id': doc.id, ...doc.data()!});
  }

  /// Permitted worker journey-field updates only - matches the field
  /// allowlist enforced in firestore.rules `/contacts/{contactId}` update rule.
  Future<void> updateContactStage({
    required String contactId,
    required String currentStage,
    DateTime? contactedAt,
    DateTime? returnedAt,
  }) async {
    await _firebaseService.firestore
        .collection('contacts')
        .doc(contactId)
        .update({
          'currentStage': currentStage,
          if (contactedAt != null)
            'contactedAt': Timestamp.fromDate(contactedAt),
          if (returnedAt != null) 'returnedAt': Timestamp.fromDate(returnedAt),
          'updatedAt': FieldValue.serverTimestamp(),
        });
  }
}
