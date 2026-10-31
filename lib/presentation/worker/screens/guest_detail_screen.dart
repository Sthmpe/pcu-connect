import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/utils/contact_launcher.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_header.dart';
import '../../../core/widgets/brand_marks.dart';
import '../../../core/widgets/custom_button.dart';
import '../../../core/widgets/guest_status_pill.dart';
import '../../../core/widgets/state_views.dart';
import '../../../core/widgets/status_tone.dart';
import '../../../domain/entities/guest_entity.dart';
import '../../guests/bloc/guests_bloc.dart';
import '../../guests/bloc/guests_state.dart';

/// Outcomes offered after a call. Values match the Apps Script API.
const List<(String, IconData, StatusTone)> kFollowUpOutcomes = [
  ('Reached', Icons.check_circle_rounded, StatusTone.green),
  ('No answer', Icons.phone_missed_rounded, StatusTone.amber),
  ('Number off', Icons.phone_disabled_rounded, StatusTone.red),
  ('Not interested', Icons.do_not_disturb_on_rounded, StatusTone.neutral),
];

class GuestDetailScreen extends StatelessWidget {
  final String guestId;

  /// Admins view guests without logging follow-ups.
  final bool readOnly;

  const GuestDetailScreen({
    super.key,
    required this.guestId,
    this.readOnly = false,
  });

  void _log(BuildContext context, GuestEntity guest, [String? outcome]) {
    Navigator.of(context).pushNamed(
      AppRoutes.logFollowUp,
      arguments: LogFollowUpArgs(guest.id, initialOutcome: outcome),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: BlocBuilder<GuestsBloc, GuestsState>(
        builder: (context, state) {
          GuestEntity? guest;
          if (state is GuestsLoadedState) {
            for (final g in state.allGuests) {
              if (g.id == guestId) guest = g;
            }
          }

          if (guest == null) {
            return Column(
              children: [
                AppHeader(
                  title: 'Guest',
                  onBack: () => Navigator.pop(context),
                ),
                Expanded(
                  child: state is GuestsLoadedState
                      ? const Center(
                          child: EmptyState(
                            icon: Icons.person_search_rounded,
                            title: 'Guest not found',
                            message: 'This guest is not in the current list.',
                          ),
                        )
                      : const SkeletonList(count: 3),
                ),
              ],
            );
          }

          final g = guest;
          return Column(
            children: [
              _DetailHeader(guest: g),
              Expanded(
                child: ListView(
                  padding: EdgeInsets.fromLTRB(
                      AppSizes.gutter, AppSizes.p16, AppSizes.gutter, AppSizes.p24),
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: AppButton(
                            label: 'Call',
                            icon: Icons.call_rounded,
                            onPressed: () => ContactLauncher.call(g),
                          ),
                        ),
                        SizedBox(width: AppSizes.p10),
                        Expanded(
                          child: AppButton(
                            label: 'WhatsApp',
                            variant: AppButtonVariant.whatsapp,
                            leading: WhatsAppMark(
                                size: AppSizes.iconMd, color: AppColors.greenInk),
                            onPressed: () => ContactLauncher.whatsApp(g),
                          ),
                        ),
                      ],
                    ),
                    if (!readOnly) ...[
                      SizedBox(height: AppSizes.p16),
                      _QuickOutcomeCard(onPick: (o) => _log(context, g, o)),
                    ],
                    SizedBox(height: AppSizes.p12),
                    _MembershipCard(guest: g),
                    SizedBox(height: AppSizes.p12),
                    _ActivityCard(guest: g),
                    SizedBox(height: AppSizes.p16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.info_outline_rounded,
                            size: AppSizes.iconXs, color: AppColors.muted),
                        SizedBox(width: AppSizes.p6),
                        Text('Guest details are managed by the HOD',
                            style: AppTextStyles.caption),
                      ],
                    ),
                  ],
                ),
              ),
              if (!readOnly)
                BottomActionBar(
                  child: AppButton(
                    label: 'Log follow-up',
                    icon: Icons.edit_note_rounded,
                    variant: AppButtonVariant.accent,
                    onPressed: () => _log(context, g),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _DetailHeader extends StatelessWidget {
  final GuestEntity guest;

  const _DetailHeader({required this.guest});

  @override
  Widget build(BuildContext context) {
    final details = [
      guest.phone,
      if (guest.month.isNotEmpty) 'came ${guest.month}',
    ].join(' · ');

    return AppHeader(
      rounded: true,
      onBack: () => Navigator.pop(context),
      child: Row(
        children: [
          AppAvatar(
            initials: guest.initials,
            size: AppSizes.avatarLg,
            background: AppColors.gold,
            foreground: AppColors.navy,
          ),
          SizedBox(width: AppSizes.p12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(guest.name,
                    style: AppTextStyles.detailTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                SizedBox(height: AppSizes.p4),
                Text(details,
                    style: AppTextStyles.screenSubtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          SizedBox(width: AppSizes.p8),
          GuestStatusPill(status: guest.status),
        ],
      ),
    );
  }
}

/// After the call: one tap on the outcome opens the log with it chosen.
class _QuickOutcomeCard extends StatelessWidget {
  final ValueChanged<String> onPick;

  const _QuickOutcomeCard({required this.onPick});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('How did the call go?', style: AppTextStyles.cardTitle),
          SizedBox(height: AppSizes.p2),
          Text('Pick the outcome to log it quickly.',
              style: AppTextStyles.caption),
          SizedBox(height: AppSizes.p12),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: AppSizes.p8,
            crossAxisSpacing: AppSizes.p8,
            childAspectRatio: 3.6,
            children: [
              for (final (label, icon, tone) in kFollowUpOutcomes)
                Material(
                  color: tone.background,
                  borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                  child: InkWell(
                    onTap: () => onPick(label),
                    borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: AppSizes.p10),
                      child: Row(
                        children: [
                          Icon(icon, size: AppSizes.iconSm, color: tone.foreground),
                          SizedBox(width: AppSizes.p8),
                          Flexible(
                            child: Text(
                              label,
                              style: AppTextStyles.secondaryStrong
                                  .copyWith(color: tone.foreground),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MembershipCard extends StatelessWidget {
  final GuestEntity guest;

  const _MembershipCard({required this.guest});

  @override
  Widget build(BuildContext context) {
    final isMember = guest.status == 'Member';
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('Road to membership', style: AppTextStyles.cardTitle),
              ),
              if (isMember)
                const AppPill(label: 'Member', tone: StatusTone.gold, showDot: true)
              else if (guest.month.isNotEmpty)
                Text(guest.month, style: AppTextStyles.caption),
            ],
          ),
          SizedBox(height: AppSizes.p12),
          _AttendanceRow(
            label: 'Sundays',
            attended: guest.sundayAttendance,
            target: 4,
          ),
          SizedBox(height: AppSizes.p10),
          _AttendanceRow(
            label: 'Wednesdays',
            attended: guest.wednesdayAttendance,
            target: 2,
          ),
          SizedBox(height: AppSizes.p12),
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(
                horizontal: AppSizes.p10, vertical: AppSizes.p8),
            decoration: BoxDecoration(
              color: AppColors.surfaceMuted,
              borderRadius: BorderRadius.circular(AppSizes.radiusSm),
            ),
            child: Text(
              'Member after 4 Sundays, or 3 Sundays and 2 Wednesdays, in one month.',
              style: AppTextStyles.caption,
            ),
          ),
        ],
      ),
    );
  }
}

class _AttendanceRow extends StatelessWidget {
  final String label;
  final int attended;
  final int target;

  const _AttendanceRow({
    required this.label,
    required this.attended,
    required this.target,
  });

  @override
  Widget build(BuildContext context) {
    final dot = AppSizes.p24 + AppSizes.p2;
    return Row(
      children: [
        Expanded(
          child: RichText(
            text: TextSpan(
              style: AppTextStyles.secondary,
              children: [
                TextSpan(text: '$label  '),
                TextSpan(
                  text: '${attended.clamp(0, target)} of $target',
                  style: AppTextStyles.secondaryStrong,
                ),
              ],
            ),
          ),
        ),
        for (var i = 0; i < target; i++)
          Container(
            width: dot,
            height: dot,
            margin: EdgeInsets.only(left: AppSizes.p6),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: i < attended ? AppColors.green : AppColors.surface,
              shape: BoxShape.circle,
              border: Border.all(
                color: i < attended ? AppColors.green : AppColors.lineStrong,
              ),
            ),
            child: i < attended
                ? Icon(Icons.check_rounded,
                    size: AppSizes.iconXs, color: AppColors.onNavy)
                : Text('${i + 1}', style: AppTextStyles.caption),
          ),
      ],
    );
  }
}

class _ActivityCard extends StatelessWidget {
  final GuestEntity guest;

  const _ActivityCard({required this.guest});

  @override
  Widget build(BuildContext context) {
    final tone = StatusTone.forUrgency(guest.urgency);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Follow-up', style: AppTextStyles.cardTitle),
          SizedBox(height: AppSizes.p6),
          InfoRow(
            icon: Icons.flag_rounded,
            label: 'Progress',
            value: guest.progressText,
            valueColor: tone.foreground,
          ),
          InfoRow(
            icon: Icons.history_rounded,
            label: 'Follow-ups logged',
            value: '${guest.followUpCount}',
          ),
          InfoRow(
            icon: Icons.groups_rounded,
            label: 'Team',
            value: guest.teamJoined.isEmpty ? 'Not yet' : guest.teamJoined,
            valueColor: guest.teamJoined.isEmpty ? AppColors.muted : AppColors.greenInk,
          ),
          if (guest.lastFeedback.isNotEmpty) ...[
            SizedBox(height: AppSizes.p8),
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(AppSizes.p12),
              decoration: BoxDecoration(
                color: AppColors.surfaceMuted,
                borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                border: const Border(
                  left: BorderSide(color: AppColors.gold, width: 3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    guest.lastFeedbackDate.isEmpty
                        ? 'LAST FEEDBACK'
                        : 'LAST FEEDBACK · ${guest.lastFeedbackDate.toUpperCase()}',
                    style: AppTextStyles.overline,
                  ),
                  SizedBox(height: AppSizes.p4),
                  Text(guest.lastFeedback, style: AppTextStyles.body),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
