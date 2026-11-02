import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/config/app_config.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_icons.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/utils/lagos_time.dart';
import '../../../core/widgets/app_display.dart';
import '../../../core/widgets/app_surfaces.dart';
import '../../../data/firestore/nudge_repository.dart';
import '../../../data/firestore/message_templates_repository.dart';
import '../../../domain/attention_rules.dart';
import '../../../domain/nudge.dart';
import '../../common/insights_cubits.dart';
import '../../../core/widgets/state_views.dart';
import '../../guests/bloc/guests_bloc.dart';
import '../../guests/bloc/guests_event.dart';
import '../../guests/bloc/guests_state.dart';
import '../../guests/widgets/watch_months.dart';
import '../screens/hod_outstanding_screen.dart';
import 'nudge_sheet.dart';

/// Dashboard: workers with outstanding guests (Today's rule), longest wait
/// first. Read-only: a tap opens that worker's guests still to call. Nothing
/// is ever reassigned from here.
class NeedsAttentionCard extends StatefulWidget {
  /// The Dashboard's month: workers with outstanding guests who first visited then.
  final String month;

  const NeedsAttentionCard({super.key, required this.month});

  @override
  State<NeedsAttentionCard> createState() => _NeedsAttentionCardState();
}

class _NeedsAttentionCardState extends State<NeedsAttentionCard> {
  late final INudgeRepository _nudges = context.read<INudgeRepository>();
  late final Stream<NudgeHistory> _history = _nudges.history();

  @override
  void initState() {
    super.initState();
    // Phones for Nudge on WhatsApp come from the team (the Workers tab).
    context.read<TeamCubit>().ensureLoaded();
  }


  @override
  Widget build(BuildContext context) {
    final today = LagosTime.today();
    final months = [widget.month];
    return WatchMonths(
      months: months,
      child: BlocBuilder<GuestsBloc, GuestsState>(
        builder: (context, state) {
          final failure = state.failureFor(months);
          if (failure != null) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SectionLabel('Needs attention'),
                ErrorState(message: failure, onRetry: () => context.read<GuestsBloc>().add(WatchMonthsEvent(months))),
              ],
            );
          }
          final list = AttentionRules.build(guests: state.guestsIn(months), since: AppConfig.chaseFrom, today: today);
          if (list.isEmpty) return const SizedBox.shrink();
          return StreamBuilder<NudgeHistory>(
            stream: _history,
            builder: (context, history) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SectionLabel('Needs attention'),
                GroupedCard(
                  dividerIndent: AppSizes.s16 * 2 + AppSizes.avatarSm,
                  children: [
                    for (final w in list)
                      NeedsAttentionRow(
                        worker: w,
                        lastNudge: history.data?.last(w.workerEmail),
                        onNudge: w.workerEmail.isEmpty
                            ? null
                            : () => showNudgeSheet(context, w, _nudges,
                                phone: phoneFor(context, w.workerEmail), templates: context.read<IMessageTemplatesRepository>()),
                      ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class NeedsAttentionRow extends StatelessWidget {
  final WorkerAttention worker;

  /// The latest nudge on any channel ("Last nudged 2 h ago on WhatsApp").
  final NudgeLog? lastNudge;
  final VoidCallback? onNudge;

  const NeedsAttentionRow({super.key, required this.worker, this.lastNudge, this.onNudge});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      // One place for this worker: their outstanding guests, Nudge, WhatsApp and Redistribute.
      onTap: () => WorkerOutstandingScreen.open(context, worker.workerEmail.isEmpty ? worker.workerName : worker.workerEmail),
      child: Container(
        constraints: BoxConstraints(minHeight: AppSizes.touch + AppSizes.s8),
        padding: EdgeInsets.symmetric(horizontal: AppSizes.s16, vertical: AppSizes.s8),
        child: Row(
          children: [
            AppAvatar(name: worker.workerName, size: AppSizes.avatarSm),
            SizedBox(width: AppSizes.s16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    worker.line,
                    style: AppTextStyles.body.copyWith(color: worker.urgent ? AppColors.redInk : null),
                  ),
                  if (lastNudge != null) ...[
                    SizedBox(height: AppSizes.s4),
                    Text(lastNudgedLine(lastNudge!), style: AppTextStyles.caption),
                  ],
                ],
              ),
            ),
            if (onNudge != null) ...[
              SizedBox(width: AppSizes.s8),
              TextButton(
                onPressed: onNudge,
                child: Text('Nudge', style: AppTextStyles.captionStrong.copyWith(color: AppColors.navy)),
              ),
            ] else
              Icon(AppIcons.chevronRight, size: AppSizes.iconMd, color: AppColors.subtle),
          ],
        ),
      ),
    );
  }
}
