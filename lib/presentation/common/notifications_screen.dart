import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_icons.dart';
import '../../core/constants/app_sizes.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/utils/lagos_time.dart';
import '../../core/widgets/app_page.dart';
import '../../core/widgets/app_surfaces.dart';
import '../../core/widgets/state_views.dart';
import '../../core/routing/app_routes.dart';
import '../../domain/entities/app_notification.dart';
import '../auth/bloc/auth_bloc.dart';
import '../auth/bloc/auth_state.dart';
import 'notifications_cubit.dart';

/// The notification list. Opening it marks everything as read.
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<NotificationsCubit>().markAllRead();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          const AppTopBar(title: 'Notifications'),
          Expanded(
            child: BlocBuilder<NotificationsCubit, NotificationsState>(
              builder: (context, state) {
                if (state.failed && state.items.isEmpty) {
                  return ErrorState(
                    message: 'We could not load your notifications. Try again.',
                    onRetry: context.read<NotificationsCubit>().retry,
                  );
                }
                if (!state.loaded) return const SkeletonPage(rows: 4);
                if (state.items.isEmpty) {
                  return const Center(
                    child: EmptyState(icon: AppIcons.bell, message: 'No notifications yet.'),
                  );
                }
                final (today, earlier) = groupNotifications(state.items);
                final auth = context.read<AuthBloc>().state;
                final asAdmin = auth is AuthAuthenticatedState && auth.user.isAdmin;
                void open(AppNotification n) => Navigator.of(
                  context,
                ).pushNamed(AppRoutes.guestDetail, arguments: GuestDetailArgs(n.guestId!, asAdmin: asAdmin));
                Widget group(String label, List<AppNotification> items) => Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SectionLabel(label),
                    GroupedCard(
                      dividerIndent: AppSizes.s16 * 2 + AppSizes.iconMd,
                      children: [
                        for (final n in items) _NotificationRow(n, onTap: n.guestId == null ? null : () => open(n)),
                      ],
                    ),
                  ],
                );
                return PageList(
                  children: [
                    if (today.isNotEmpty) group('Today', today),
                    if (earlier.isNotEmpty) group('Earlier', earlier),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Splits notifications (newest first) into Today and Earlier, by the Lagos
/// day. One still waiting for its server time counts as today.
(List<AppNotification>, List<AppNotification>) groupNotifications(List<AppNotification> items, [DateTime? clock]) {
  final today = LagosTime.today(clock);
  bool isToday(AppNotification n) => n.createdAt == null || LagosTime.day(n.createdAt!) == today;
  return (items.where(isToday).toList(), items.where((n) => !isToday(n)).toList());
}

class _NotificationRow extends StatelessWidget {
  final AppNotification n;

  /// Opens the guest the notice is about.
  final VoidCallback? onTap;
  const _NotificationRow(this.n, {this.onTap});

  IconData get _icon {
    if (n.guestId != null) return AppIcons.guests;
    if (n.tag == 'daily-reminder') return AppIcons.busy;
    if (n.tag.startsWith('sync')) return AppIcons.sync;
    return AppIcons.bell;
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.all(AppSizes.s16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(_icon, size: AppSizes.iconMd, color: AppColors.inkSoft),
            SizedBox(width: AppSizes.s16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: Text(n.title, style: n.read ? AppTextStyles.body : AppTextStyles.bodyStrong)),
                      Text(timeAgo(n.createdAt), style: AppTextStyles.caption),
                    ],
                  ),
                  if (n.body.isNotEmpty) ...[
                    SizedBox(height: AppSizes.s4),
                    Text(n.body, style: AppTextStyles.bodyMuted),
                  ],
                ],
              ),
            ),
            if (!n.read) ...[
              SizedBox(width: AppSizes.s8),
              Padding(
                padding: EdgeInsets.only(top: AppSizes.s8),
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(color: AppColors.gold, shape: BoxShape.circle),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// "Just now", "5 min ago", "2 h ago", "Yesterday", or a Lagos date.
String timeAgo(DateTime? at, [DateTime? clock]) {
  if (at == null) return '';
  final now = clock ?? DateTime.now();
  final diff = now.difference(at);
  if (diff.inMinutes < 1) return 'Just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
  if (LagosTime.day(at) == LagosTime.today(now)) return '${diff.inHours} h ago';
  if (LagosTime.daysBetween(LagosTime.day(at), LagosTime.today(now)) == 1) return 'Yesterday';
  return DateFormat('d MMM').format(at.toUtc().add(LagosTime.offset));
}
