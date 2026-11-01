import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_icons.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/utils/contact_launcher.dart';
import '../../../core/utils/lagos_time.dart';
import '../../../core/utils/month_utils.dart';
import '../../../core/widgets/app_controls.dart';
import '../../../core/widgets/app_display.dart';
import '../../../core/widgets/app_page.dart';
import '../../../core/widgets/app_surfaces.dart';
import '../../../core/widgets/state_views.dart';
import '../../../core/widgets/status_tone.dart';
import '../../../domain/entities/follow_up_entry.dart';
import '../../../domain/entities/guest_entity.dart';
import '../../../domain/membership_progress.dart';
import '../../../domain/repositories/i_guest_repository.dart';
import '../../guests/bloc/guests_bloc.dart';
import '../../common/whatsapp_sheet.dart';
import '../../guests/bloc/guests_state.dart';

/// Call outcomes, exactly as the Apps Script API accepts them.
const List<(String, IconData)> kFollowUpOutcomes = [
  ('Reached', AppIcons.reached),
  ('No answer', AppIcons.noAnswer),
  ('Busy', AppIcons.busy),
  ('Switched off', AppIcons.numberOff),
  ('Wrong number', AppIcons.wrongNumber),
  ('Not interested', AppIcons.notInterested),
];

/// The four shown as one-tap shortcuts on the guest screen.
const List<String> kQuickOutcomes = ['Reached', 'No answer', 'Switched off', 'Not interested'];

IconData outcomeIcon(String outcome) {
  for (final (label, icon) in kFollowUpOutcomes) {
    if (label == outcome) return icon;
  }
  return AppIcons.call;
}

class GuestDetailScreen extends StatefulWidget {
  final String guestId;

  /// Opened from the admin app: logs are saved for the assigned worker.
  final bool asAdmin;

  const GuestDetailScreen({super.key, required this.guestId, this.asAdmin = false});

  @override
  State<GuestDetailScreen> createState() => _GuestDetailScreenState();
}

class _GuestDetailScreenState extends State<GuestDetailScreen> {
  List<FollowUpEntry>? _history;
  bool _historyFailed = false;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final result = await context.read<IGuestRepository>().fetchGuestDetail(widget.guestId);
    if (!mounted) return;
    setState(() {
      _historyFailed = result.isFailure;
      if (result.isSuccess) _history = result.data!.history;
    });
  }

  Future<void> _log(GuestEntity guest, [String? outcome]) async {
    await Navigator.of(context).pushNamed(
      AppRoutes.logFollowUp,
      arguments: LogFollowUpArgs(guest.id, initialOutcome: outcome),
    );
    if (mounted) _loadHistory();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BlocBuilder<GuestsBloc, GuestsState>(
        builder: (context, state) {
          // From whichever month it was opened in (the cache holds every loaded month).
          final GuestEntity? guest = state.find(widget.guestId);

          if (guest == null) {
            return Column(
              children: [
                const AppTopBar(),
                Expanded(
                  child: state.months.values.every((m) => m.status != MonthStatus.loading)
                      ? const Center(
                          child: EmptyState(
                              icon: AppIcons.search, message: 'We could not find this guest.'),
                        )
                      : const SkeletonPage(rows: 3),
                ),
              ],
            );
          }

          final g = guest;
          final assignee = (g.assignedWorkerName ?? '').trim();
          final canLog = !widget.asAdmin || assignee.isNotEmpty;
          final logLabel = widget.asAdmin
              ? 'Log a follow-up for ${firstNameOf(assignee)}'
              : 'Log follow-up';

          return Column(
            children: [
              const AppTopBar(),
              Expanded(
                child: PageList(
                  children: [
                    _Profile(guest: g, assignee: widget.asAdmin ? assignee : null),
                    SizedBox(height: AppSizes.s24),
                    _ContactActions(guest: g),
                    SizedBox(height: AppSizes.s32),
                    if (canLog)
                      _OutcomeCard(onPick: (o) => _log(g, o))
                    else
                      AppCard(
                        child: Text(
                          'Assign this guest to a worker before logging a follow-up.',
                          style: AppTextStyles.bodyMuted,
                        ),
                      ),
                    SectionLabel('Road to membership'),
                    _MembershipCard(guest: g),
                    SectionLabel('Details'),
                    _DetailsCard(guest: g),
                    SectionLabel('History'),
                    _HistoryCard(
                      history: _history,
                      failed: _historyFailed,
                      onRetry: _loadHistory,
                    ),
                  ],
                ),
              ),
              if (canLog)
                Padding(
                  padding: EdgeInsets.fromLTRB(AppSizes.gutter, AppSizes.s8, AppSizes.gutter,
                      AppSizes.s16 + MediaQuery.paddingOf(context).bottom),
                  child: AppButton(label: logLabel, icon: AppIcons.log, onPressed: () => _log(g)),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _Profile extends StatelessWidget {
  final GuestEntity guest;
  final String? assignee;

  const _Profile({required this.guest, this.assignee});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        AppAvatar(name: guest.name, size: AppSizes.avatarLg),
        SizedBox(height: AppSizes.s16),
        Text(guest.name, style: AppTextStyles.title, textAlign: TextAlign.center),
        SizedBox(height: AppSizes.s4),
        // Long-press the number to copy it.
        GestureDetector(
          onLongPress: () => ContactLauncher.copyPhone(guest),
          child: Text(
            assignee == null
                ? guest.phone
                : '${guest.phone} · ${assignee!.isEmpty ? 'Not assigned' : 'With ${firstNameOf(assignee!)}'}',
            style: AppTextStyles.bodyMuted,
          ),
        ),
        SizedBox(height: AppSizes.s16),
        AppPill(label: guest.status, tone: StatusTone.forStatus(guest.status)),
      ],
    );
  }
}

class _ContactActions extends StatelessWidget {
  final GuestEntity guest;

  const _ContactActions({required this.guest});

  @override
  Widget build(BuildContext context) {
    Widget action(String label, IconData icon, Color bg, Color fg, VoidCallback onTap) =>
        Semantics(
          button: true,
          label: label,
          child: SizedBox(
            width: 88,
            child: Column(
              children: [
                Material(
                  color: bg,
                  shape: const CircleBorder(),
                  elevation: bg == AppColors.surface ? 0.5 : 0,
                  shadowColor: AppColors.navy.withValues(alpha: 0.2),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: onTap,
                    child: SizedBox(
                      width: AppSizes.s48 + AppSizes.s8,
                      height: AppSizes.s48 + AppSizes.s8,
                      child: Icon(icon, size: AppSizes.iconLg, color: fg),
                    ),
                  ),
                ),
                SizedBox(height: AppSizes.s8),
                Text(label, style: AppTextStyles.caption.copyWith(color: AppColors.inkSoft)),
              ],
            ),
          ),
        );

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        action('Call', AppIcons.call, AppColors.navy, AppColors.onNavy,
            () => ContactLauncher.call(guest)),
        SizedBox(width: AppSizes.s16),
        action('WhatsApp', AppIcons.whatsapp, AppColors.surface, AppColors.greenInk,
            () => showWhatsAppSheet(context, guest)),
      ],
    );
  }
}

/// After the call: one tap opens the log with the outcome chosen.
class _OutcomeCard extends StatelessWidget {
  final ValueChanged<String> onPick;

  const _OutcomeCard({required this.onPick});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: EdgeInsets.fromLTRB(AppSizes.s16, AppSizes.s16, AppSizes.s16, AppSizes.s8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: AppSizes.s8),
            child: Text('How did the call go?', style: AppTextStyles.bodyStrong),
          ),
          SizedBox(height: AppSizes.s4),
          Wrap(
            spacing: AppSizes.s8,
            children: [
              for (final label in kQuickOutcomes) QuickOutcomeChip(label: label, onTap: () => onPick(label)),
            ],
          ),
        ],
      ),
    );
  }
}

/// One quick outcome as a chip with a 48px touch target. Gold when [selected].
class QuickOutcomeChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const QuickOutcomeChip({super.key, required this.label, required this.onTap, this.selected = false});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Padding(
          // 36px chip plus 6px above and below makes a 48px target.
          padding: EdgeInsets.symmetric(vertical: (AppSizes.touch - AppSizes.chipHeight - AppSizes.s4) / 2),
          child: IntrinsicWidth(
            child: Container(
              height: AppSizes.chipHeight + AppSizes.s4,
              padding: EdgeInsets.symmetric(horizontal: AppSizes.s16 - 4),
              decoration: BoxDecoration(
                color: selected ? AppColors.gold : AppColors.sunken,
                borderRadius: BorderRadius.circular(AppSizes.radiusFull),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(outcomeIcon(label), size: AppSizes.iconSm, color: selected ? AppColors.navy : AppColors.inkSoft),
                  SizedBox(width: AppSizes.s8 - 2),
                  Text(label,
                      style: AppTextStyles.centered(AppTextStyles.caption)
                          .copyWith(color: selected ? AppColors.navy : AppColors.ink)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Road to membership: this month's Sundays and Wednesdays as dots, filled
/// when attended, and what is still needed (MembershipProgress).
class _MembershipCard extends StatelessWidget {
  final GuestEntity guest;

  const _MembershipCard({required this.guest});

  @override
  Widget build(BuildContext context) {
    final progress = MembershipProgress.of(
      today: LagosTime.today(),
      sundayDates: guest.sundayDates,
      wednesdayDates: guest.wednesdayDates,
      status: guest.status,
    );

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(MonthUtils.label(progress.month), style: AppTextStyles.caption),
          SizedBox(height: AppSizes.s8),
          MembershipDots(label: 'Sun', days: progress.sundays),
          SizedBox(height: AppSizes.s8),
          MembershipDots(label: 'Wed', days: progress.wednesdaysInMonth),
          SizedBox(height: AppSizes.s16),
          Text(progress.line, style: AppTextStyles.bodyStrong),
          if (guest.status != 'Member') ...[
            SizedBox(height: AppSizes.s4),
            Text('4 Sundays, or 3 Sundays and 2 Wednesdays, in one month.', style: AppTextStyles.caption),
          ],
        ],
      ),
    );
  }
}

/// One row of the mini calendar: a dot per service day, filled when attended.
class MembershipDots extends StatelessWidget {
  final String label;
  final List<ServiceDay> days;

  const MembershipDots({super.key, required this.label, required this.days});

  @override
  Widget build(BuildContext context) {
    const size = 30.0;
    return Row(
      children: [
        SizedBox(width: AppSizes.s48, child: Text(label, style: AppTextStyles.caption)),
        for (final d in days)
          Padding(
            padding: EdgeInsets.only(right: AppSizes.s8),
            child: Semantics(
              label: '${LagosTime.fullDate(d.day)}, ${d.attended ? 'attended' : 'not attended'}',
              child: ExcludeSemantics(
                child: Container(
                  width: size,
                  height: size,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: d.attended ? AppColors.navy : Colors.transparent,
                    shape: BoxShape.circle,
                    border: Border.all(color: d.attended ? AppColors.navy : AppColors.lineStrong, width: 1.5),
                  ),
                  child: Text(
                    '${d.dayOfMonth}',
                    style: AppTextStyles.centered(AppTextStyles.caption).copyWith(
                      color: d.attended ? AppColors.onNavy : (d.past ? AppColors.subtle : AppColors.ink),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _DetailsCard extends StatelessWidget {
  final GuestEntity guest;

  const _DetailsCard({required this.guest});

  @override
  Widget build(BuildContext context) {
    final tone = StatusTone.forUrgency(guest.urgency);
    return GroupedCard(
      children: [
        InfoTile(
          label: 'Progress',
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              StatusDot(tone.dot),
              SizedBox(width: AppSizes.s8),
              Text(guestProgressLine(guest),
                  style: AppTextStyles.body.copyWith(color: AppColors.muted)),
            ],
          ),
        ),
        InfoTile(
          label: 'First visit',
          value: guest.serviceDate.isEmpty ? MonthUtils.label(guest.month) : LagosTime.fullDate(guest.serviceDate),
        ),
        InfoTile(label: 'Team', value: guest.teamJoined.isEmpty ? 'Not yet' : guest.teamJoined),
      ],
    );
  }
}

/// Newest first. Admin entries keep the worker's name and get a small label.
class _HistoryCard extends StatelessWidget {
  final List<FollowUpEntry>? history;
  final bool failed;
  final VoidCallback onRetry;

  const _HistoryCard({required this.history, required this.failed, required this.onRetry});

  static String _day(String ymd) {
    final d = DateTime.tryParse(ymd);
    return d == null ? ymd : DateFormat('d MMM').format(d);
  }

  @override
  Widget build(BuildContext context) {
    final list = history;
    if (list == null) {
      if (failed) {
        return AppCard(
          child: Row(
            children: [
              Expanded(child: Text('History did not load.', style: AppTextStyles.bodyMuted)),
              AppButton(
                label: 'Retry',
                variant: AppButtonVariant.secondary,
                expand: false,
                onPressed: onRetry,
              ),
            ],
          ),
        );
      }
      return const Skeleton(child: SkeletonBox(height: 120, radius: 20));
    }
    if (list.isEmpty) {
      return AppCard(
        child: Text('No follow-ups yet. The first call is the most important one.',
            style: AppTextStyles.bodyMuted),
      );
    }

    return GroupedCard(
      dividerIndent: AppSizes.s16 * 2 + AppSizes.avatarSm,
      children: [
        for (final e in list)
          Padding(
            padding: EdgeInsets.all(AppSizes.s16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: AppSizes.avatarSm,
                  height: AppSizes.avatarSm,
                  decoration: const BoxDecoration(color: AppColors.sunken, shape: BoxShape.circle),
                  child: Icon(outcomeIcon(e.outcome), size: AppSizes.iconSm, color: AppColors.inkSoft),
                ),
                SizedBox(width: AppSizes.s16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(child: Text(e.outcome, style: AppTextStyles.bodyStrong)),
                          Text(_day(e.date), style: AppTextStyles.caption),
                        ],
                      ),
                      SizedBox(height: AppSizes.s4 / 2),
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: AppSizes.s8,
                        runSpacing: AppSizes.s4,
                        children: [
                          Text(
                            [
                              if (e.workerName.isNotEmpty) firstNameOf(e.workerName),
                              if (e.attendedSunday) 'came Sunday',
                              if (e.attendedWednesday) 'came Wednesday',
                              if (e.team.isNotEmpty) 'joined ${e.team}',
                            ].join(' · '),
                            style: AppTextStyles.caption,
                          ),
                          if (e.loggedByAdmin)
                            Tooltip(
                              message: e.loggedByName.isEmpty
                                  ? 'Saved by an admin'
                                  : 'Saved by ${e.loggedByName}',
                              child: Container(
                                padding: EdgeInsets.symmetric(
                                    horizontal: AppSizes.s8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.navySoft,
                                  borderRadius: BorderRadius.circular(AppSizes.radiusFull),
                                ),
                                child: Text('Logged by admin',
                                    style: AppTextStyles.centered(AppTextStyles.caption)
                                        .copyWith(color: AppColors.navy)),
                              ),
                            ),
                          if (e.pendingSync)
                            Tooltip(
                              message: 'Saved on this phone. It will sync when you are back online.',
                              child: Container(
                                padding: EdgeInsets.symmetric(
                                    horizontal: AppSizes.s8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.sunken,
                                  borderRadius: BorderRadius.circular(AppSizes.radiusFull),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(AppIcons.offline, size: 12, color: AppColors.inkSoft),
                                    SizedBox(width: AppSizes.s4),
                                    Text('Waiting to sync',
                                        style: AppTextStyles.centered(AppTextStyles.caption)),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                      if (e.note.isNotEmpty) ...[
                        SizedBox(height: AppSizes.s8),
                        Text(e.note, style: AppTextStyles.body),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
