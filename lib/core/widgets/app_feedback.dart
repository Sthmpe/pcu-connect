import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../constants/app_colors.dart';
import '../constants/app_icons.dart';
import '../constants/app_sizes.dart';
import '../constants/app_text_styles.dart';
import 'app_controls.dart';

/// Snackbars and dialogs. GetX is used here and nowhere else.
abstract class AppFeedback {
  static void success(String title, String message) =>
      _snack(title, message, AppIcons.reached, AppColors.green, AppColors.greenSoft);

  static void error(String title, String message) => _snack(
      title, friendlyError(message), AppIcons.error, AppColors.red, AppColors.redSoft);

  /// Turns transport errors into plain language.
  static String friendlyError(String message) {
    final m = message.toLowerCase();
    if (m.contains('failed to fetch') ||
        m.contains('clientexception') ||
        m.contains('socketexception') ||
        m.contains('timeout') ||
        m.contains('timed out') ||
        m.startsWith('http ')) {
      return 'We could not reach the server. Check your connection and try again.';
    }
    if (m.contains('please sign in') || m.contains('unauthenticated')) {
      return 'Your session has ended. Please sign in again.';
    }
    return message;
  }

  static void _snack(
      String title, String message, IconData icon, Color color, Color tint) {
    if (Get.isSnackbarOpen) Get.closeCurrentSnackbar();
    Get.snackbar(
      title,
      message,
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: AppColors.surface,
      icon: Padding(
        padding: const EdgeInsets.only(left: 16),
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(color: tint, shape: BoxShape.circle),
          child: Icon(icon, color: color, size: 18),
        ),
      ),
      shouldIconPulse: false,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      borderRadius: 16,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      duration: const Duration(seconds: 3),
      animationDuration: AppDurations.normal,
      boxShadows: AppShadows.raised,
      titleText: Padding(
        padding: const EdgeInsets.only(left: 8),
        child: Text(title, style: AppTextStyles.bodyStrong),
      ),
      messageText: Padding(
        padding: const EdgeInsets.only(left: 8),
        child: Text(message, style: AppTextStyles.caption),
      ),
    );
  }

  /// Yes or no question. Resolves to true when confirmed.
  static Future<bool> confirm({
    required String title,
    required String message,
    required String confirmLabel,
    bool destructive = false,
  }) async {
    final result = await Get.dialog<bool>(
      _DialogShell(
        title: title,
        message: message,
        actions: [
          Expanded(
            child: AppButton(
              label: 'Cancel',
              variant: AppButtonVariant.secondary,
              onPressed: () => Get.back(result: false),
            ),
          ),
          SizedBox(width: AppSizes.s8),
          Expanded(
            child: AppButton(
              label: confirmLabel,
              variant: destructive ? AppButtonVariant.danger : AppButtonVariant.primary,
              onPressed: () => Get.back(result: true),
            ),
          ),
        ],
      ),
      barrierColor: AppColors.scrim,
    );
    return result ?? false;
  }

  /// Simple notice with one button.
  static Future<void> notice({required String title, required String message}) {
    return Get.dialog<void>(
      _DialogShell(
        icon: AppIcons.lock,
        title: title,
        message: message,
        actions: [
          Expanded(child: AppButton(label: 'Got it', onPressed: () => Get.back())),
        ],
      ),
      barrierColor: AppColors.scrim,
    );
  }

  /// Shown after a follow-up is saved.
  /// [creditedTo] is set when an admin logged it for a worker.
  static Future<void> pointsEarned({
    required int points,
    required String guestName,
    String? creditedTo,
  }) {
    return Get.dialog<void>(
      _PointsDialog(points: points, guestName: guestName, creditedTo: creditedTo),
      barrierColor: AppColors.scrim,
    );
  }
}

class _DialogShell extends StatelessWidget {
  final IconData? icon;
  final String title;
  final String message;
  final List<Widget> actions;

  const _DialogShell({
    this.icon,
    required this.title,
    required this.message,
    required this.actions,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: EdgeInsets.symmetric(horizontal: AppSizes.s24),
      child: Padding(
        padding: EdgeInsets.all(AppSizes.s24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (icon != null) ...[
              Icon(icon, size: AppSizes.iconLg, color: AppColors.inkSoft),
              SizedBox(height: AppSizes.s16),
            ],
            Text(title, style: AppTextStyles.title),
            SizedBox(height: AppSizes.s8),
            Text(message, style: AppTextStyles.bodyMuted),
            SizedBox(height: AppSizes.s24),
            Row(children: actions),
          ],
        ),
      ),
    );
  }
}

class _PointsDialog extends StatelessWidget {
  final int points;
  final String guestName;
  final String? creditedTo;

  const _PointsDialog({required this.points, required this.guestName, this.creditedTo});

  @override
  Widget build(BuildContext context) {
    final hasPoints = points > 0;
    return Dialog(
      insetPadding: EdgeInsets.symmetric(horizontal: AppSizes.s24),
      child: Padding(
        padding: EdgeInsets.all(AppSizes.s24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.7, end: 1),
              duration: AppDurations.normal,
              curve: Curves.easeOutBack,
              builder: (context, s, child) => Transform.scale(scale: s, child: child),
              child: Container(
                width: AppSizes.s48 + AppSizes.s8,
                height: AppSizes.s48 + AppSizes.s8,
                decoration: const BoxDecoration(
                  color: AppColors.greenSoft,
                  shape: BoxShape.circle,
                ),
                child: Icon(AppIcons.check, color: AppColors.greenInk, size: AppSizes.iconLg),
              ),
            ),
            SizedBox(height: AppSizes.s16),
            if (hasPoints)
              TweenAnimationBuilder<int>(
                tween: IntTween(begin: 0, end: points),
                duration: AppDurations.slow,
                builder: (context, v, _) =>
                    Text('+$v points', style: AppTextStyles.display),
              )
            else
              Text('Saved', style: AppTextStyles.display),
            SizedBox(height: AppSizes.s8),
            Text(
              creditedTo == null
                  ? 'Follow-up for $guestName is saved.'
                  : 'Saved for $guestName. The points go to $creditedTo.',
              style: AppTextStyles.bodyMuted,
              textAlign: TextAlign.center,
            ),
            SizedBox(height: AppSizes.s24),
            AppButton(label: 'Done', onPressed: () => Get.back()),
          ],
        ),
      ),
    );
  }
}
