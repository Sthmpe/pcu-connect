import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_icons.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/routing/app_routes.dart';
import '../../core/widgets/app_controls.dart';
import 'notifications_cubit.dart';

/// Bell with the unread count; opens the notification list.
class NotificationBell extends StatelessWidget {
  const NotificationBell({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<NotificationsCubit, NotificationsState>(
      builder: (context, state) {
        if (!state.available) return const SizedBox.shrink();
        final unread = state.unread;
        return Stack(
          clipBehavior: Clip.none,
          children: [
            AppIconButton(
              icon: AppIcons.bell,
              tooltip: unread == 0 ? 'Notifications' : 'Notifications, $unread unread',
              onTap: () => Navigator.of(context).pushNamed(AppRoutes.notifications),
            ),
            if (unread > 0)
              Positioned(
                right: -2,
                top: -2,
                child: IgnorePointer(
                  child: Container(
                    constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                    padding: const EdgeInsets.symmetric(horizontal: 5),
                    decoration: BoxDecoration(
                      color: AppColors.gold,
                      borderRadius: BorderRadius.circular(9),
                      border: Border.all(color: AppColors.bg, width: 2),
                    ),
                    alignment: Alignment.center,
                    child: Text(unread > 9 ? '9+' : '$unread',
                        style: AppTextStyles.centered(AppTextStyles.captionStrong)
                            .copyWith(color: AppColors.navy, fontSize: 10)),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
