import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/network/firebase_service.dart';
import '../../../guests/domain/models/guest_model.dart';
import '../../domain/models/report_metrics_model.dart';

class ReportsRemoteDatasource {
  final FirebaseService _firebaseService;

  ReportsRemoteDatasource({FirebaseService? firebaseService})
    : _firebaseService = firebaseService ?? FirebaseService();

  Query _baseQuery({
    required String locationId,
    DateTime? startDate,
    DateTime? endDate,
  }) {
    Query query = _firebaseService.firestore
        .collection('contacts')
        .where('locationId', isEqualTo: locationId);

    if (startDate != null) {
      query = query.where(
        'receivedAt',
        isGreaterThanOrEqualTo: Timestamp.fromDate(startDate),
      );
    }
    if (endDate != null) {
      query = query.where(
        'receivedAt',
        isLessThanOrEqualTo: Timestamp.fromDate(endDate),
      );
    }
    return query;
  }

  Future<ReportMetricsModel> getMetrics({
    required String locationId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final snapshot = await _baseQuery(
      locationId: locationId,
      startDate: startDate,
      endDate: endDate,
    ).get();

    int received = snapshot.docs.length;
    int contacted = 0;
    int retained = 0;
    int converts = 0;
    int workers = 0;

    for (final doc in snapshot.docs) {
      final row = doc.data() as Map<String, dynamic>;
      final stage = row['currentStage'] as String? ?? 'received';
      final intakeType = row['intakeType'] as String? ?? 'contact';

      if (row['contactedAt'] != null || stage == 'contacted') contacted++;
      if (row['retainedAt'] != null || stage == 'retained') retained++;
      if (intakeType == 'convert') converts++;
      if (row['becameOperatorAt'] != null || stage == 'operator') workers++;
    }

    return ReportMetricsModel.fromCounts(
      received: received,
      contacted: contacted,
      retained: retained,
      converts: converts,
      workers: workers,
    );
  }

  Future<List<GuestModel>> getDrillDownContacts({
    required String locationId,
    required String metricKey,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    Query query = _baseQuery(
      locationId: locationId,
      startDate: startDate,
      endDate: endDate,
    );

    switch (metricKey) {
      case 'contacted':
        query = query.where('contactedAt', isNull: false);
        break;
      case 'retained':
        query = query.where('retainedAt', isNull: false);
        break;
      case 'converts':
        query = query.where('intakeType', isEqualTo: 'convert');
        break;
      case 'workers':
        query = query.where('becameOperatorAt', isNull: false);
        break;
      case 'received':
      default:
        break;
    }

    final snapshot = await query.get();
    return snapshot.docs
        .map(
          (doc) => GuestModel.fromJson({
            'id': doc.id,
            ...doc.data() as Map<String, dynamic>,
          }),
        )
        .toList();
  }
}
