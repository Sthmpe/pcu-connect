import 'package:flutter/material.dart';
import '../../domain/entities/guest_entity.dart';
import '../constants/app_colors.dart';
import '../constants/app_sizes.dart';
import '../constants/app_text_styles.dart';
import '../utils/contact_launcher.dart';
import 'app_card.dart';
import 'brand_marks.dart';
import 'guest_status_pill.dart';
import 'status_tone.dart';

/// Compact guest row with one-tap Call and WhatsApp.
///
/// The thin left bar and the progress line carry the follow-up urgency
/// (blue new, red overdue, amber called once, green followed up).
class GuestCardWidget extends StatelessWidget {
  final GuestEntity guest;
  final VoidCallback onTap;

  /// Shows "Assigned to ..." instead of the urgency line (admin lists).
  final bool showAssignee;
  final bool showActions;

  const GuestCardWidget({
    super.key,
    required this.guest,
    required this.onTap,
    this.showAssignee = false,
    this.showActions = true,
  });

  @override
  Widget build(BuildContext context) {
    final tone = StatusTone.forUrgency(guest.urgency);
    final radius = BorderRadius.circular(AppSizes.radiusLg);
    final assignee = guest.assignedWorkerName;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: radius,
        border: Border.all(color: AppColors.line),
        boxShadow: AppShadows.card,
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(width: 3, color: tone.accent),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                        AppSizes.p12, AppSizes.p12, AppSizes.p12, AppSizes.p12),
                    child: Row(
                      children: [
                        AppAvatar(
                          initials: guest.initials,
                          size: AppSizes.avatarMd,
                          background: tone.background,
                          foreground: tone.foreground,
                        ),
                        SizedBox(width: AppSizes.p12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      guest.name,
                                      style: AppTextStyles.itemTitle,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  SizedBox(width: AppSizes.p6),
                                  GuestStatusPill(status: guest.status),
                                ],
                              ),
                              SizedBox(height: AppSizes.p4),
                              if (showAssignee)
                                Text(
                                  assignee == null || assignee.isEmpty
                                      ? '${guest.phone} · Unassigned'
                                      : '${guest.phone} · ${assignee.split(' ').first}',
                                  style: AppTextStyles.caption,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                )
                              else
                                Row(
                                  children: [
                                    Container(
                                      width: 6,
                                      height: 6,
                                      decoration: BoxDecoration(
                                        color: tone.accent,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    SizedBox(width: AppSizes.p6),
                                    Flexible(
                                      child: Text(
                                        guest.progressText,
                                        style: AppTextStyles.caption.copyWith(
                                          color: tone.foreground,
                                          fontWeight: FontWeight.w500,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                            ],
                          ),
                        ),
                        if (showActions) ...[
                          SizedBox(width: AppSizes.p8),
                          ContactIconButton(
                            tooltip: 'WhatsApp ${guest.name}',
                            icon: WhatsAppMark(
                                size: AppSizes.iconSm + 1,
                                color: AppColors.greenInk),
                            background: AppColors.greenSoft,
                            onTap: () => ContactLauncher.whatsApp(guest),
                          ),
                          SizedBox(width: AppSizes.p8),
                          ContactIconButton(
                            tooltip: 'Call ${guest.name}',
                            icon: Icon(Icons.call_rounded,
                                size: AppSizes.iconSm + 1,
                                color: AppColors.onNavy),
                            background: AppColors.navy,
                            onTap: () => ContactLauncher.call(guest),
                          ),
                        ] else
                          Icon(Icons.chevron_right_rounded,
                              color: AppColors.subtle, size: AppSizes.iconMd),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Round icon button for Call and WhatsApp in list rows.
class ContactIconButton extends StatelessWidget {
  final Widget icon;
  final String tooltip;
  final Color background;
  final VoidCallback onTap;

  const ContactIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.background,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: background,
        shape: const CircleBorder(),
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: SizedBox(
            width: AppSizes.iconButton,
            height: AppSizes.iconButton,
            child: Center(child: icon),
          ),
        ),
      ),
    );
  }
}
