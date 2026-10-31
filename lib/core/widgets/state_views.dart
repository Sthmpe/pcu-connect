import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_sizes.dart';
import '../constants/app_text_styles.dart';
import 'app_feedback.dart';
import 'custom_button.dart';

/// Friendly empty state: icon in a soft circle, short title, one line of help.
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool compact;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.actionLabel,
    this.onAction,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: AppSizes.p32,
        vertical: compact ? AppSizes.p24 : AppSizes.p40,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: AppSizes.avatarLg + AppSizes.p8,
            height: AppSizes.avatarLg + AppSizes.p8,
            decoration: const BoxDecoration(
              color: AppColors.navySoft,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: AppSizes.iconLg, color: AppColors.navy),
          ),
          SizedBox(height: AppSizes.p16),
          Text(title,
              style: AppTextStyles.cardTitle, textAlign: TextAlign.center),
          if (message != null) ...[
            SizedBox(height: AppSizes.p6),
            Text(message!,
                style: AppTextStyles.secondary, textAlign: TextAlign.center),
          ],
          if (actionLabel != null && onAction != null) ...[
            SizedBox(height: AppSizes.p16),
            AppButton(
              label: actionLabel!,
              onPressed: onAction,
              variant: AppButtonVariant.tonal,
              size: AppButtonSize.small,
              expand: false,
            ),
          ],
        ],
      ),
    );
  }
}

/// Error state with a retry action.
class ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const ErrorState({super.key, required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: EmptyState(
        icon: Icons.wifi_off_rounded,
        title: 'Could not load',
        message: AppFeedback.friendlyError(message),
        actionLabel: 'Try again',
        onAction: onRetry,
      ),
    );
  }
}

/// Pulsing placeholder rows shown while the first load is in flight.
class SkeletonList extends StatefulWidget {
  final int count;
  final bool withTiles;

  const SkeletonList({super.key, this.count = 5, this.withTiles = false});

  @override
  State<SkeletonList> createState() => _SkeletonListState();
}

class _SkeletonListState extends State<SkeletonList>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _bar(double width, double height) => Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: AppColors.neutralSoft,
          borderRadius: BorderRadius.circular(AppSizes.radiusSm),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween(begin: 0.45, end: 1.0).animate(_controller),
      child: ListView(
        physics: const NeverScrollableScrollPhysics(),
        padding: EdgeInsets.all(AppSizes.gutter),
        children: [
          if (widget.withTiles) ...[
            Row(
              children: List.generate(
                3,
                (i) => Expanded(
                  child: Container(
                    height: 74,
                    margin: EdgeInsets.only(left: i == 0 ? 0 : AppSizes.p8),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(AppSizes.radiusLg),
                      border: Border.all(color: AppColors.line),
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(height: AppSizes.p24),
          ],
          for (var i = 0; i < widget.count; i++)
            Container(
              margin: EdgeInsets.only(bottom: AppSizes.p10),
              padding: EdgeInsets.all(AppSizes.p12),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppSizes.radiusLg),
                border: Border.all(color: AppColors.line),
              ),
              child: Row(
                children: [
                  Container(
                    width: AppSizes.avatarMd,
                    height: AppSizes.avatarMd,
                    decoration: const BoxDecoration(
                      color: AppColors.neutralSoft,
                      shape: BoxShape.circle,
                    ),
                  ),
                  SizedBox(width: AppSizes.p12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _bar(120, 12),
                        SizedBox(height: AppSizes.p8),
                        _bar(80, 10),
                      ],
                    ),
                  ),
                  _bar(56, 26),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Shown above lists when the data came from the offline cache.
class OfflineBanner extends StatelessWidget {
  final bool isRefreshing;

  const OfflineBanner({super.key, this.isRefreshing = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(bottom: AppSizes.p12),
      padding: EdgeInsets.symmetric(
          horizontal: AppSizes.p12, vertical: AppSizes.p8),
      decoration: BoxDecoration(
        color: AppColors.amberSoft,
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
      ),
      child: Row(
        children: [
          Icon(
            isRefreshing ? Icons.sync_rounded : Icons.cloud_off_rounded,
            size: AppSizes.iconSm,
            color: AppColors.amberInk,
          ),
          SizedBox(width: AppSizes.p8),
          Expanded(
            child: Text(
              isRefreshing
                  ? 'Showing saved data while we refresh'
                  : 'Showing saved data. You may be offline.',
              style: AppTextStyles.caption.copyWith(
                color: AppColors.amberInk,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
