import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/config/app_config.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_icons.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/utils/lagos_time.dart';
import '../../../core/widgets/app_display.dart';
import '../../../core/widgets/app_surfaces.dart';
import '../../../data/firestore/nudge_repository.dart';
import '../../../domain/attention_rules.dart';
import '../../../domain/today_rules.dart';
import '../../guests/bloc/guests_bloc.dart';
import '../../guests/bloc/guests_state.dart';
import '../../guests/widgets/watch_months.dart';
import 'nudge_sheet.dart';

/// Dashboard: workers with outstanding guests (Today's rule), longest wait
/// first. Read-only: a tap opens that worker's guests still to call. Nothing
/// is ever reassigned from here.
class NeedsAttentionCard extends StatefulWidget {
  const NeedsAttentionCard({super.key});

  @override
  State<NeedsAttentionCard> createState() => _NeedsAttentionCardState();
}

class _NeedsAttentionCardState extends State<NeedsAttentionCard> {
  late final INudgeRepository _nudges = context.read<INudgeRepository>();
  late final Stream<Map<String, DateTime>> _recent = _nudges.recent();

  @override
  Widget build(BuildContext context) {
    final today = LagosTime.today();
    final months = TodayRules.months(since: AppConfig.chaseFrom, today: today);
    return WatchMonths(
      months: months,
      child: BlocBuilder<GuestsBloc, GuestsState>(
        builder: (context, state) {
          final list = AttentionRules.build(guests: state.guestsIn(months), since: AppConfig.chaseFrom, today: today);
          if (list.isEmpty) return const SizedBox.shrink();
          return StreamBuilder<Map<String, DateTime>>(
            stream: _recent,
            builder: (context, recent) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SectionLabel('Needs attention'),
                GroupedCard(
                  dividerIndent: AppSizes.s16 * 2 + AppSizes.avatarSm,
                  children: [
                    for (final w in list)
                      NeedsAttentionRow(
                        worker: w,
                        nudgedAt: recent.data?[w.workerEmail],
                        onNudge: w.workerEmail.isEmpty ? null : () => showNudgeSheet(context, w, _nudges),
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

  /// When they were last nudged, if in the last 24 hours.
  final DateTime? nudgedAt;
  final VoidCallback? onNudge;

  const NeedsAttentionRow({super.key, required this.worker, this.nudgedAt, this.onNudge});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => Navigator.of(context).pushNamed(
        AppRoutes.workerGuests,
        arguments: WorkerGuestsArgs(worker.workerName, month: worker.oldestMonth),
      ),
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
                  if (nudgedAt != null) ...[
                    SizedBox(height: AppSizes.s4),
                    Text(nudgedLine(nudgedAt!), style: AppTextStyles.caption),
                  ],
                ],
              ),
            ),
            if (onNudge != null && nudgedAt == null) ...[
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
