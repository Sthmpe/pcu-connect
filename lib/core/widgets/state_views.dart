import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_icons.dart';
import '../constants/app_sizes.dart';
import '../constants/app_text_styles.dart';
import 'app_controls.dart';
import 'app_feedback.dart';

/// Icon, one line, one action.
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  const EmptyState({
    super.key,
    required this.icon,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: AppSizes.s32, vertical: AppSizes.s40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: AppSizes.s48 + AppSizes.s8,
            height: AppSizes.s48 + AppSizes.s8,
            decoration: const BoxDecoration(
              color: AppColors.sunken,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: AppSizes.iconLg, color: AppColors.inkSoft),
          ),
          SizedBox(height: AppSizes.s16),
          Text(message, style: AppTextStyles.bodyMuted, textAlign: TextAlign.center),
          if (actionLabel != null && onAction != null) ...[
            SizedBox(height: AppSizes.s16),
            AppButton(
              label: actionLabel!,
              onPressed: onAction,
              variant: AppButtonVariant.secondary,
              expand: false,
            ),
          ],
        ],
      ),
    );
  }
}

class ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const ErrorState({super.key, required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: EmptyState(
        icon: AppIcons.offline,
        message: AppFeedback.friendlyError(message),
        actionLabel: 'Try again',
        onAction: onRetry,
      ),
    );
  }
}

/// Shimmer driver shared by skeleton boxes below it.
class Skeleton extends StatefulWidget {
  final Widget child;

  const Skeleton({super.key, required this.child});

  @override
  State<Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<Skeleton> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1300),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) => ShaderMask(
        blendMode: BlendMode.srcATop,
        shaderCallback: (rect) => LinearGradient(
          begin: Alignment(-1.5 + _c.value * 3, 0),
          end: Alignment(-0.5 + _c.value * 3, 0),
          colors: const [AppColors.sunken, Color(0xFFF9FAFB), AppColors.sunken],
        ).createShader(rect),
        child: child,
      ),
      child: widget.child,
    );
  }
}

class SkeletonBox extends StatelessWidget {
  final double? width;
  final double height;
  final double? radius;

  const SkeletonBox({super.key, this.width, required this.height, this.radius});

  @override
  Widget build(BuildContext context) => Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: AppColors.sunken,
          borderRadius: BorderRadius.circular(radius ?? AppSizes.radiusSm),
        ),
      );
}

/// Placeholder for a page: optional hero block, then a card of rows.
class SkeletonPage extends StatelessWidget {
  final bool hero;
  final int rows;

  const SkeletonPage({super.key, this.hero = false, this.rows = 5});

  @override
  Widget build(BuildContext context) {
    return Skeleton(
      child: ListView(
        physics: const NeverScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(
            AppSizes.gutter, AppSizes.s8, AppSizes.gutter, AppSizes.s32),
        children: [
          if (hero) ...[
            SkeletonBox(height: 168, radius: AppSizes.radiusLg),
            SizedBox(height: AppSizes.s24),
          ],
          Container(
            padding: EdgeInsets.all(AppSizes.s16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppSizes.radiusLg),
            ),
            child: Column(
              children: [
                for (var i = 0; i < rows; i++)
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: AppSizes.s8),
                    child: Row(
                      children: [
                        SkeletonBox(
                            width: AppSizes.avatarMd,
                            height: AppSizes.avatarMd,
                            radius: AppSizes.radiusFull),
                        SizedBox(width: AppSizes.s16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SkeletonBox(width: 120, height: 12),
                              SizedBox(height: AppSizes.s8),
                              SkeletonBox(width: 180, height: 10),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
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
      margin: EdgeInsets.only(bottom: AppSizes.s16),
      padding: EdgeInsets.symmetric(horizontal: AppSizes.s16, vertical: AppSizes.s8 + 2),
      decoration: BoxDecoration(
        color: AppColors.amberSoft,
        borderRadius: BorderRadius.circular(AppSizes.radiusSm),
      ),
      child: Row(
        children: [
          Icon(isRefreshing ? AppIcons.retry : AppIcons.offline,
              size: AppSizes.iconSm, color: AppColors.amberInk),
          SizedBox(width: AppSizes.s8),
          Expanded(
            child: Text(
              isRefreshing ? 'Updating…' : 'You are seeing saved data',
              style: AppTextStyles.caption.copyWith(color: AppColors.amberInk),
            ),
          ),
        ],
      ),
    );
  }
}
