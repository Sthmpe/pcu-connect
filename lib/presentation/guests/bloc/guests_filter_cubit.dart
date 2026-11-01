import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/utils/month_utils.dart';

class GuestsFilter extends Equatable {
  final String month;
  final String chip; // 'all' | 'call' | 'fu' | 'mem' | 'team'

  const GuestsFilter({required this.month, this.chip = 'all'});

  @override
  List<Object?> get props => [month, chip];
}

/// The month and chip of ONE Guests screen. Each screen has its own
/// instance, so the worker's Guests tab, the HOD's Guests tab and the
/// one-worker guests screen never share a selection with each other,
/// with Today or with the Dashboard.
class GuestsFilterCubit extends Cubit<GuestsFilter> {
  GuestsFilterCubit({String? month}) : super(GuestsFilter(month: month ?? MonthUtils.current()));

  void selectMonth(String month) => emit(GuestsFilter(month: month, chip: state.chip));

  void selectChip(String chip) => emit(GuestsFilter(month: state.month, chip: chip));

  /// Used when the Dashboard sends the HOD to a list ("See who is waiting").
  void show({required String month, required String chip}) => emit(GuestsFilter(month: month, chip: chip));
}
