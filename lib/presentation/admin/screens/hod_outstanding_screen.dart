import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/config/app_config.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_icons.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/utils/lagos_time.dart';
import '../../../core/widgets/app_controls.dart';
import '../../../core/widgets/app_display.dart';
import '../../../core/widgets/app_page.dart';
import '../../../core/widgets/app_surfaces.dart';
import '../../../core/widgets/attention.dart';
import '../../../core/widgets/guest_row.dart';
import '../../../core/widgets/state_views.dart';
import '../../../core/widgets/status_tone.dart';
import '../../../data/firestore/message_templates_repository.dart';
import '../../../data/firestore/nudge_repository.dart';
import '../../../data/repositories/redistribute_repository.dart';
import '../../../domain/attention_rules.dart';
import '../../../domain/message_templates.dart';
import '../../../domain/nudge.dart';
import '../../../domain/today_rules.dart';
import '../../common/insights_cubits.dart';
import '../../guests/bloc/guests_bloc.dart';
import '../../guests/bloc/guests_event.dart';
import '../../guests/bloc/guests_state.dart';
import '../../guests/widgets/watch_months.dart';
import '../../worker/screens/today_tab.dart';
import '../widgets/nudge_sheet.dart';
import '../widgets/redistribute_sheet.dart';

/// The months the HOD's outstanding view watches: since go-live (as Today).
List<String> hodOutstandingMonths() => TodayRules.months(since: AppConfig.chaseFrom, today: LagosTime.today());

/// Every worker with outstanding guests, from the guest cache (all months since go-live).
List<WorkerAttention> hodOutstanding(GuestsState state) =>
    AttentionRules.build(guests: state.guestsIn(hodOutstandingMonths()), since: AppConfig.chaseFrom, today: LagosTime.today());

/// Watches the months the outstanding view needs, then builds with the list.
class HodOutstandingBuilder extends StatelessWidget {
  final Widget Function(BuildContext context, GuestsState state, List<WorkerAttention> workers) builder;

  const HodOutstandingBuilder({super.key, required this.builder});

  @override
  Widget build(BuildContext context) {
    return WatchMonths(
      months: hodOutstandingMonths(),
      child: BlocBuilder<GuestsBloc, GuestsState>(
        builder: (context, state) => builder(context, state, hodOutstanding(state)),
      ),
    );
  }
}

/// HOD: workers with outstanding guests, each with count, oldest wait and
/// when they were last nudged. Tapping one opens their guests and the actions.
class HodOutstandingScreen extends StatefulWidget {
  const HodOutstandingScreen({super.key});

  static Future<void> open(BuildContext context) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => const HodOutstandingScreen()));

  @override
  State<HodOutstandingScreen> createState() => _HodOutstandingScreenState();
}

class _HodOutstandingScreenState extends State<HodOutstandingScreen> {
  late final Stream<NudgeHistory> _history = context.read<INudgeRepository>().history();

  @override
  void initState() {
    super.initState();
    context.read<TeamCubit>().ensureLoaded();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          const AppTopBar(title: 'Outstanding'),
          Expanded(
            child: HodOutstandingBuilder(
              builder: (context, state, workers) {
                final months = hodOutstandingMonths();
                final failure = state.failureFor(months);
                if (failure != null) {
                  return ErrorState(message: failure, onRetry: () => context.read<GuestsBloc>().add(WatchMonthsEvent(months)));
                }
                if (state.waitingFor(months)) return const SkeletonPage(rows: 4);
                if (workers.isEmpty) {
                  return const Center(
                    child: EmptyState(icon: AppIcons.done, message: 'No guest is waiting for a first call. Lovely work.'),
                  );
                }
                return StreamBuilder<NudgeHistory>(
                  stream: _history,
                  builder: (context, history) => PageList(
                    children: [
                      Text('Never called, and waiting more than 3 days since their visit. Tap a worker to nudge or '
                          'redistribute.', style: AppTextStyles.bodyMuted),
                      SizedBox(height: AppSizes.s16),
                      GroupedCard(
                        dividerIndent: AppSizes.s16 * 2 + AppSizes.avatarMd,
                        children: [
                          for (final w in workers)
                            HodWorkerRow(
                              worker: w,
                              lastNudge: history.data?.last(w.workerEmail),
                              onTap: () => WorkerOutstandingScreen.open(context, w.workerEmail.isEmpty ? w.workerName : w.workerEmail),
                            ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// One worker: avatar with a gentle pulsing red mark, count, oldest wait, last nudged.
class HodWorkerRow extends StatelessWidget {
  final WorkerAttention worker;
  final NudgeLog? lastNudge;
  final VoidCallback onTap;

  const HodWorkerRow({super.key, required this.worker, this.lastNudge, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: AppSizes.s16, vertical: AppSizes.s8 + 4),
        child: Row(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                AppAvatar(name: worker.workerName, size: AppSizes.avatarMd),
                Positioned(
                  right: -6,
                  top: -6,
                  child: Semantics(label: 'Outstanding', child: const PulseDot(size: 10)),
                ),
              ],
            ),
            SizedBox(width: AppSizes.s16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(worker.line,
                      style: AppTextStyles.bodyStrong.copyWith(color: worker.urgent ? AppColors.redInk : AppColors.ink)),
                  SizedBox(height: AppSizes.s4),
                  Text(lastNudge == null ? 'Not nudged yet' : lastNudgedLine(lastNudge!), style: AppTextStyles.caption),
                ],
              ),
            ),
            Icon(AppIcons.chevronRight, size: AppSizes.iconMd, color: AppColors.subtle),
          ],
        ),
      ),
    );
  }
}

/// One worker's outstanding guests, with Nudge, Nudge on WhatsApp and Redistribute.
class WorkerOutstandingScreen extends StatefulWidget {
  /// The worker's email (or name when the guests do not carry the email).
  final String worker;

  const WorkerOutstandingScreen({super.key, required this.worker});

  static Future<void> open(BuildContext context, String worker) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => WorkerOutstandingScreen(worker: worker)));

  @override
  State<WorkerOutstandingScreen> createState() => _WorkerOutstandingScreenState();
}

class _WorkerOutstandingScreenState extends State<WorkerOutstandingScreen> {
  late final INudgeRepository _nudges = context.read<INudgeRepository>();
  late final Stream<NudgeHistory> _history = _nudges.history();
  String _template = MessageTemplates.defaults[MessageTemplates.nudgeId]!;

  @override
  void initState() {
    super.initState();
    context.read<TeamCubit>().ensureLoaded();
    try {
      context.read<IMessageTemplatesRepository>().watch().listen((list) {
        if (mounted) _template = MessageTemplates.nudgeText(list);
      });
    } on ProviderNotFoundException {
      // Defaults stay.
    }
  }

  WorkerAttention? _find(List<WorkerAttention> workers) {
    final key = widget.worker.trim().toLowerCase();
    for (final w in workers) {
      if (w.workerEmail == key || w.workerName.trim().toLowerCase() == key) return w;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: HodOutstandingBuilder(
        builder: (context, state, workers) {
          final w = _find(workers);
          final first = w == null ? '' : w.workerName.replaceFirst(RegExp(r'^TEST\s+'), '').split(RegExp(r'\s+')).first;
          return Column(
            children: [
              AppTopBar(title: w == null ? 'Outstanding' : "$first's outstanding"),
              Expanded(
                child: w == null
                    ? (state.waitingFor(hodOutstandingMonths())
                        ? const SkeletonPage(rows: 3)
                        : const Center(
                            child: EmptyState(icon: AppIcons.done, message: 'Nothing outstanding here now. Lovely work.')))
                    : StreamBuilder<NudgeHistory>(
                        stream: _history,
                        builder: (context, history) {
                          final last = history.data?.last(w.workerEmail);
                          return PageList(
                            children: [
                              Text(w.line,
                                  style: AppTextStyles.bodyStrong.copyWith(color: w.urgent ? AppColors.redInk : AppColors.ink)),
                              SizedBox(height: AppSizes.s4),
                              Text(last == null ? 'Not nudged yet' : lastNudgedLine(last), style: AppTextStyles.caption),
                              SizedBox(height: AppSizes.s16),
                              Row(
                                children: [
                                  Expanded(
                                    child: AppButton(
                                      label: 'Nudge',
                                      icon: AppIcons.bellRing,
                                      variant: AppButtonVariant.navy,
                                      onPressed: w.workerEmail.isEmpty
                                          ? null
                                          : () => showNudgeSheet(context, w, _nudges,
                                              phone: phoneFor(context, w.workerEmail),
                                              templates: context.read<IMessageTemplatesRepository>()),
                                    ),
                                  ),
                                  SizedBox(width: AppSizes.s8),
                                  Expanded(
                                    child: AppButton(
                                      label: 'WhatsApp',
                                      icon: AppIcons.whatsapp,
                                      variant: AppButtonVariant.outline,
                                      onPressed: w.workerEmail.isEmpty
                                          ? null
                                          : () => nudgeOnWhatsApp(
                                                worker: w,
                                                phone: phoneFor(context, w.workerEmail),
                                                template: _template,
                                                repo: _nudges,
                                              ),
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: AppSizes.s8),
                              AppButton(
                                label: 'Redistribute',
                                icon: AppIcons.team,
                                variant: AppButtonVariant.secondary,
                                onPressed: w.workerEmail.isEmpty
                                    ? null
                                    : () => showRedistributeSheet(context,
                                        repo: context.read<IRedistributeRepository>(),
                                        workerEmail: w.workerEmail,
                                        workerName: w.workerName),
                              ),
                              SectionLabel('Waiting for a first call · ${w.outstanding}'),
                              GroupedCard(
                                dividerIndent: AppSizes.s16 * 2 + AppSizes.avatarMd,
                                children: [
                                  for (final i in w.items)
                                    GuestRow(
                                      guest: i.guest,
                                      outstanding: true,
                                      line: todayLine(i),
                                      pill: todayPill(i.section),
                                      pillTone: StatusTone.red,
                                      onTap: () => Navigator.of(context).pushNamed(AppRoutes.guestDetail,
                                          arguments: GuestDetailArgs(i.guest.id, asAdmin: true)),
                                    ),
                                ],
                              ),
                            ],
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}
