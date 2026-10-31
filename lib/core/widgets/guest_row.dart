import 'package:flutter/material.dart';
import '../../domain/entities/guest_entity.dart';
import '../constants/app_colors.dart';
import '../constants/app_icons.dart';
import '../constants/app_sizes.dart';
import '../constants/app_text_styles.dart';
import '../utils/contact_launcher.dart';
import 'app_controls.dart';
import 'app_display.dart';
import 'status_tone.dart';

/// One guest inside a GroupedCard: avatar, name, status dot and line, and
/// subtle Call and WhatsApp buttons.
class GuestRow extends StatelessWidget {
  final GuestEntity guest;
  final VoidCallback onTap;

  /// Admin lists show who the guest is assigned to and no contact buttons.
  final bool adminView;

  const GuestRow({
    super.key,
    required this.guest,
    required this.onTap,
    this.adminView = false,
  });

  @override
  Widget build(BuildContext context) {
    final tone = StatusTone.forUrgency(guest.urgency);
    final assignee = guest.assignedWorkerName ?? '';
    final line = adminView
        ? (assignee.isEmpty ? 'Not assigned' : 'With ${firstNameOf(assignee)}')
        : guestProgressLine(guest);

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
            AppSizes.s16, AppSizes.s8 + 4, AppSizes.s8, AppSizes.s8 + 4),
        child: Row(
          children: [
            AppAvatar(name: guest.name, size: AppSizes.avatarMd),
            SizedBox(width: AppSizes.s16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(guest.name,
                      style: AppTextStyles.bodyStrong,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  SizedBox(height: AppSizes.s4),
                  Row(
                    children: [
                      StatusDot(tone.dot),
                      SizedBox(width: AppSizes.s8),
                      Flexible(
                        child: Text(
                          adminView ? '${guest.status} · $line' : line,
                          style: AppTextStyles.caption,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (adminView)
              Padding(
                padding: EdgeInsets.only(right: AppSizes.s8),
                child: Icon(AppIcons.chevronRight,
                    size: AppSizes.iconMd, color: AppColors.subtle),
              )
            else ...[
              AppIconButton(
                icon: AppIcons.whatsapp,
                tooltip: 'WhatsApp ${guest.name}',
                foreground: AppColors.greenInk,
                onTap: () => ContactLauncher.whatsApp(guest),
              ),
              AppIconButton(
                icon: AppIcons.call,
                tooltip: 'Call ${guest.name}',
                foreground: AppColors.navy,
                onTap: () => ContactLauncher.call(guest),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
