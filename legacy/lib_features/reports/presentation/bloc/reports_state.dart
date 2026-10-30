import 'package:equatable/equatable.dart';
import '../../../guests/domain/models/guest_model.dart';
import '../../domain/models/report_metrics_model.dart';

abstract class ReportsState extends Equatable {
  const ReportsState();

  @override
  List<Object?> get props => [];
}

class ReportsInitialState extends ReportsState {
  const ReportsInitialState();
}

class ReportsLoadingState extends ReportsState {
  const ReportsLoadingState();
}

class ReportsLoadedState extends ReportsState {
  final ReportMetricsModel metrics;
  final List<GuestModel>? drillDownGuests;
  final String? activeDrillDownKey;

  const ReportsLoadedState({
    required this.metrics,
    this.drillDownGuests,
    this.activeDrillDownKey,
  });

  @override
  List<Object?> get props => [metrics, drillDownGuests, activeDrillDownKey];
}

class ReportsFailureState extends ReportsState {
  final String errorMessage;

  const ReportsFailureState(this.errorMessage);

  @override
  List<Object?> get props => [errorMessage];
}
