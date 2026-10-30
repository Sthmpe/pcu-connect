import '../network/firebase_service.dart';
import 'app_terminology.dart';

/// `organizations/{organizationId}` stores an optional `terminology` map.
/// Reading this is intentionally cheap (one doc get, cached by the cubit
/// for the session) since every screen touches labels via terminology.
class TerminologyRepository {
  final FirebaseService _firebaseService;

  TerminologyRepository({FirebaseService? firebaseService})
    : _firebaseService = firebaseService ?? FirebaseService();

  Future<AppTerminology> fetchForOrganization(String organizationId) async {
    if (organizationId.isEmpty) return AppTerminology.defaults;

    final doc = await _firebaseService.firestore
        .collection('organizations')
        .doc(organizationId)
        .get();
    if (!doc.exists) return AppTerminology.defaults;

    final data = doc.data();
    final terminologyJson = data?['terminology'] as Map<String, dynamic>?;
    return AppTerminology.fromJson(terminologyJson);
  }
}
