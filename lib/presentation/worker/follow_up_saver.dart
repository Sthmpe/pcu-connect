import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get/get.dart';
import '../../core/storage/member_celebrations.dart';
import '../../core/widgets/confetti.dart';
import '../../core/widgets/app_feedback.dart';
import '../../core/widgets/status_tone.dart';
import '../../domain/milestones.dart';
import '../../domain/repositories/i_guest_repository.dart';
import '../auth/bloc/auth_bloc.dart';
import '../auth/bloc/auth_state.dart';
import '../common/insights_cubits.dart';
import '../common/install_prompt_cubit.dart';
import '../guests/bloc/guests_bloc.dart';
import '../guests/bloc/guests_event.dart';

/// Saves a follow-up (IGuestRepository.logFollowUp: one Firestore batch, or
/// the Apps Script action), then refreshes what shows it and says how many
/// points it earned. Used by the full form and the "How did the call go?"
/// sheet. On success [close] runs first (pop the form or sheet), then the
/// points dialog shows. True when saved.
Future<bool> saveFollowUp(
  BuildContext context, {
  required String guestId,
  required String outcome,
  String note = '',
  bool attendedSunday = false,
  DateTime? sundayDate,
  bool attendedWednesday = false,
  DateTime? wednesdayDate,
  String team = '',
  VoidCallback? close,
}) async {
  final guests = context.read<GuestsBloc>();
  final guest = guests.state.find(guestId);
  final guestName = guest?.name ?? 'this guest';
  final auth = context.read<AuthBloc>().state;
  final isAdmin = auth is AuthAuthenticatedState && auth.user.isAdmin;
  final assignee = (guest?.assignedWorkerName ?? '').trim();
  final creditedTo = isAdmin && assignee.isNotEmpty ? firstNameOf(assignee) : null;
  final ranking = context.read<RankingCubit>();
  final dashboard = context.read<DashboardCubit>();
  final team0 = context.read<TeamCubit>();
  // Optional (not provided in some tests).
  final install = _maybeRead<InstallPromptCubit>(context);
  final celebrations = _maybeRead<MemberCelebrations>(context);
  final statusBefore = guest?.status ?? '';

  final result = await context.read<IGuestRepository>().logFollowUp(
        guestId: guestId,
        outcome: outcome,
        note: note,
        attendedSunday: attendedSunday,
        sundayDate: sundayDate,
        attendedWednesday: attendedWednesday,
        wednesdayDate: wednesdayDate,
        team: team,
      );

  if (result.isFailure) {
    AppFeedback.error('Not saved', result.failure?.message ?? 'Please try again.');
    return false;
  }
  final points = (result.data?['pointsEarned'] as num?)?.toInt() ?? 0;
  final pendingSync = result.data?['pendingSync'] == true;
  // Firestore lists are live; the Apps Script source is fetched again.
  guests.add(const RefreshMonthsEvent());
  if (ranking.state.data != null) ranking.load();
  if (dashboard.state.data != null) dashboard.load();
  if (team0.state.data != null) team0.load();
  // The first save on this device may offer "Add to Home Screen".
  if (install != null) unawaited(install.saved());
  close?.call();
  AppFeedback.pointsEarned(points: points, guestName: guestName, creditedTo: creditedTo, pendingSync: pendingSync);

  // Gold confetti the first time a guest becomes a member through this worker's follow-ups.
  final guestJson = result.data?['guest'];
  final statusAfter =
      (result.data?['status'] ?? (guestJson is Map ? guestJson['status'] : null) ?? '').toString();
  if (!isAdmin &&
      celebrations != null &&
      Milestones.becameMember(before: statusBefore, after: statusAfter) &&
      await celebrations.claim(guestId)) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final overlay = Get.key.currentState?.overlay;
      if (overlay != null) showGoldConfetti(overlay);
    });
  }
  return true;
}

T? _maybeRead<T>(BuildContext context) {
  try {
    return context.read<T>();
  } on ProviderNotFoundException {
    return null;
  }
}
