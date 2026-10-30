import 'package:equatable/equatable.dart';

abstract class ReportsEvent extends Equatable {
  const ReportsEvent();

  @override
  List<Object?> get props => [];
}

class LoadReportMetricsEvent extends ReportsEvent {
  final String locationId;
  final DateTime? startDate;
  final DateTime? endDate;

  const LoadReportMetricsEvent({
    required this.locationId,
    this.startDate,
    this.endDate,
  });

  @override
  List<Object?> get props => [locationId, startDate, endDate];
}

class LoadDrillDownContactsEvent extends ReportsEvent {
  final String locationId;
  final String metricKey;
  final DateTime? startDate;
  final DateTime? endDate;

  const LoadDrillDownContactsEvent({
    required this.locationId,
    required this.metricKey,
    this.startDate,
    this.endDate,
  });

  @override
  List<Object?> get props => [locationId, metricKey, startDate, endDate];
}
