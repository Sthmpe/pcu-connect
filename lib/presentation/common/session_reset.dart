import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../guests/bloc/guests_bloc.dart';
import '../guests/bloc/guests_event.dart';
import 'insights_cubits.dart';
import 'notifications_cubit.dart';
import 'push_cubit.dart';

/// Clears everything that belongs to the signed-in person (guests and their
/// live listeners, ranking, dashboard, team, notifications, push listener). Called on sign-in
/// and on sign-out, so a second person on the same device, or the same person
/// with a new role, never sees the first one's data.
void resetSessionState(BuildContext context) {
  context.read<GuestsBloc>().add(const ResetGuestsEvent());
  context.read<RankingCubit>().reset();
  context.read<DashboardCubit>().reset();
  context.read<TeamCubit>().reset();
  context.read<NotificationsCubit>().stop();
  context.read<PushCubit>().reset();
}
