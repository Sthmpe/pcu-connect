import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/network/firebase_service.dart';
import '../../domain/models/call_interaction_model.dart';

class CallRemoteDatasource {
  final FirebaseService _firebaseService;

  CallRemoteDatasource({FirebaseService? firebaseService})
    : _firebaseService = firebaseService ?? FirebaseService();

  Future<void> submitInteraction(CallInteractionModel interaction) async {
    final firestore = _firebaseService.firestore;
    final batch = firestore.batch();

    final interactionRef = firestore.collection('interactions').doc();
    batch.set(interactionRef, {
      ...interaction.toJson(),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    if (interaction.nextFollowUpAt != null) {
      final followUpRef = firestore.collection('follow_ups').doc();
      batch.set(followUpRef, {
        'contactId': interaction.contactId,
        'organizationId': interaction.organizationId,
        'locationId': interaction.locationId,
        'unitId': interaction.unitId,
        'assignmentId': interaction.assignmentId,
        'interactionId': interactionRef.id,
        'ownerId': interaction.operatorId,
        'dueAt': interaction.nextFollowUpAt,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }

    // "Contacted" is a leadership-defined qualifying outcome (spec section 8)
    // - only a connected call counts, never a bare attempt.
    if (interaction.outcome == 'connected') {
      final contactRef = firestore
          .collection('contacts')
          .doc(interaction.contactId);
      batch.update(contactRef, {
        'currentStage': 'contacted',
        'contactedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }

    await batch.commit();
  }
}
