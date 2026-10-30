import '../../../guests/domain/models/guest_model.dart';
import '../../domain/models/report_metrics_model.dart';
import '../../domain/repositories/i_reports_repository.dart';
import '../datasources/reports_remote_datasource.dart';

class ReportsRepositoryImpl implements IReportsRepository {
  final ReportsRemoteDatasource _remoteDatasource;

  ReportsRepositoryImpl({ReportsRemoteDatasource? remoteDatasource})
    : _remoteDatasource = remoteDatasource ?? ReportsRemoteDatasource();

  @override
  Future<ReportMetricsModel> fetchMetrics({
    required String locationId,
    DateTime? startDate,
    DateTime? endDate,
  }) {
    return _remoteDatasource.getMetrics(
      locationId: locationId,
      startDate: startDate,
      endDate: endDate,
    );
  }

  @override
  Future<List<GuestModel>> fetchDrillDownContacts({
    required String locationId,
    required String metricKey,
    DateTime? startDate,
    DateTime? endDate,
  }) {
    return _remoteDatasource.getDrillDownContacts(
      locationId: locationId,
      metricKey: metricKey,
      startDate: startDate,
      endDate: endDate,
    );
  }
}
