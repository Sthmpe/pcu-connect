import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/repositories/i_reports_repository.dart';
import 'reports_event.dart';
import 'reports_state.dart';

class ReportsBloc extends Bloc<ReportsEvent, ReportsState> {
  final IReportsRepository _reportsRepository;

  ReportsBloc({required IReportsRepository reportsRepository})
    : _reportsRepository = reportsRepository,
      super(const ReportsInitialState()) {
    on<LoadReportMetricsEvent>(_onLoadReportMetrics);
    on<LoadDrillDownContactsEvent>(_onLoadDrillDownContacts);
  }

  Future<void> _onLoadReportMetrics(
    LoadReportMetricsEvent event,
    Emitter<ReportsState> emit,
  ) async {
    emit(const ReportsLoadingState());
    try {
      final metrics = await _reportsRepository.fetchMetrics(
        locationId: event.locationId,
        startDate: event.startDate,
        endDate: event.endDate,
      );
      emit(ReportsLoadedState(metrics: metrics));
    } catch (e) {
      emit(ReportsFailureState(e.toString()));
    }
  }

  Future<void> _onLoadDrillDownContacts(
    LoadDrillDownContactsEvent event,
    Emitter<ReportsState> emit,
  ) async {
    final currentState = state;
    if (currentState is ReportsLoadedState) {
      try {
        final drillDownGuests = await _reportsRepository.fetchDrillDownContacts(
          locationId: event.locationId,
          metricKey: event.metricKey,
          startDate: event.startDate,
          endDate: event.endDate,
        );
        emit(
          ReportsLoadedState(
            metrics: currentState.metrics,
            drillDownGuests: drillDownGuests,
            activeDrillDownKey: event.metricKey,
          ),
        );
      } catch (e) {
        emit(ReportsFailureState(e.toString()));
      }
    }
  }
}
