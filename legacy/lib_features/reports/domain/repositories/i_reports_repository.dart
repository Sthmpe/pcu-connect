import '../../../guests/domain/models/guest_model.dart';
import '../models/report_metrics_model.dart';

abstract class IReportsRepository {
  Future<ReportMetricsModel> fetchMetrics({
    required String locationId,
    DateTime? startDate,
    DateTime? endDate,
  });

  Future<List<GuestModel>> fetchDrillDownContacts({
    required String locationId,
    required String metricKey,
    DateTime? startDate,
    DateTime? endDate,
  });
}
