import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../constants/app_colors.dart';
import '../constants/app_sizes.dart';
import '../constants/app_text_styles.dart';
import 'custom_button.dart';

/// Snackbars and dialogs. GetX is used here and nowhere else.
abstract class AppFeedback {
  static void success(String title, String message) =>
      _snack(title, message, Icons.check_circle_rounded, AppColors.green);

  static void error(String title, String message) =>
      _snack(title, friendlyError(message), Icons.error_rounded, AppColors.red);

  /// Turns transport errors into plain language.
  static String friendlyError(String message) {
    final m = message.toLowerCase();
    if (m.contains('failed to fetch') ||
        m.contains('clientexception') ||
        m.contains('socketexception') ||
        m.contains('timed out') ||
        m.contains('timeout')) {
      return 'Could not reach the server. Check your internet connection and try again.';
    }
    return message;
  }

  static void info(String title, String message) =>
      _snack(title, message, Icons.info_rounded, AppColors.gold);

  static void _snack(String title, String message, IconData icon, Color accent) {
    if (Get.isSnackbarOpen) Get.closeCurrentSnackbar();
    Get.snackbar(
      title,
      message,
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: AppColors.navy,
      colorText: AppColors.onNavy,
      icon: Icon(icon, color: accent, size: 22),
      shouldIconPulse: false,
      margin: const EdgeInsets.all(12),
      borderRadius: 14,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      duration: const Duration(seconds: 3),
      animationDuration: AppDurations.slow,
      boxShadows: AppShadows.raised,
      titleText: Text(title,
          style: AppTextStyles.bodyStrong.copyWith(color: AppColors.onNavy)),
      messageText: Text(message,
          style: AppTextStyles.secondary.copyWith(color: AppColors.onNavyMuted)),
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
        icon: destructive ? Icons.warning_amber_rounded : Icons.help_rounded,
        iconColor: destructive ? AppColors.red : AppColors.navy,
        iconBackground: destructive ? AppColors.redSoft : AppColors.navySoft,
        title: title,
        message: message,
        actions: [
          Expanded(
            child: AppButton(
              label: 'Cancel',
              variant: AppButtonVariant.outline,
              onPressed: () => Get.back(result: false),
            ),
          ),
          SizedBox(width: AppSizes.p12),
          Expanded(
            child: AppButton(
              label: confirmLabel,
              variant: destructive
                  ? AppButtonVariant.danger
                  : AppButtonVariant.primary,
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
  static Future<void> notice({
    required String title,
    required String message,
    IconData icon = Icons.lock_rounded,
  }) {
    return Get.dialog<void>(
      _DialogShell(
        icon: icon,
        iconColor: AppColors.amberInk,
        iconBackground: AppColors.amberSoft,
        title: title,
        message: message,
        actions: [
          Expanded(
            child: AppButton(label: 'OK', onPressed: () => Get.back()),
          ),
        ],
      ),
      barrierColor: AppColors.scrim,
    );
  }

  /// Shown after a follow-up is saved.
  static Future<void> pointsEarned({required int points, required String guestName}) {
    return Get.dialog<void>(
      _PointsDialog(points: points, guestName: guestName),
      barrierColor: AppColors.scrim,
    );
  }
}

class _DialogShell extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBackground;
  final String title;
  final String message;
  final List<Widget> actions;

  const _DialogShell({
    required this.icon,
    required this.iconColor,
    required this.iconBackground,
    required this.title,
    required this.message,
    required this.actions,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: EdgeInsets.symmetric(horizontal: AppSizes.p24),
      child: Padding(
        padding: EdgeInsets.all(AppSizes.p20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration:
                  BoxDecoration(color: iconBackground, shape: BoxShape.circle),
              child: Icon(icon, color: iconColor, size: 24),
            ),
            SizedBox(height: AppSizes.p12),
            Text(title,
                style: AppTextStyles.sectionTitle, textAlign: TextAlign.center),
            SizedBox(height: AppSizes.p6),
            Text(message,
                style: AppTextStyles.secondary, textAlign: TextAlign.center),
            SizedBox(height: AppSizes.p20),
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

  const _PointsDialog({required this.points, required this.guestName});

  @override
  Widget build(BuildContext context) {
    final hasPoints = points > 0;
    return Dialog(
      insetPadding: EdgeInsets.symmetric(horizontal: AppSizes.p24),
      child: Padding(
        padding: EdgeInsets.all(AppSizes.p24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.6, end: 1),
              duration: AppDurations.slow,
              curve: Curves.easeOutBack,
              builder: (context, scale, child) =>
                  Transform.scale(scale: scale, child: child),
              child: Container(
                width: 64,
                height: 64,
                decoration: const BoxDecoration(
                  color: AppColors.goldSoft,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  hasPoints ? Icons.emoji_events_rounded : Icons.check_rounded,
                  color: AppColors.goldInk,
                  size: 32,
                ),
              ),
            ),
            SizedBox(height: AppSizes.p16),
            if (hasPoints)
              TweenAnimationBuilder<int>(
                tween: IntTween(begin: 0, end: points),
                duration: const Duration(milliseconds: 600),
                builder: (context, v, _) => Text(
                  '+$v points',
                  style: AppTextStyles.numberLg.copyWith(color: AppColors.navy),
                ),
              )
            else
              Text('Follow-up saved', style: AppTextStyles.sectionTitle),
            SizedBox(height: AppSizes.p6),
            Text(
              hasPoints
                  ? 'Follow-up for $guestName saved. Keep it going!'
                  : 'The record for $guestName is up to date.',
              style: AppTextStyles.secondary,
              textAlign: TextAlign.center,
            ),
            SizedBox(height: AppSizes.p20),
            AppButton(
              label: 'Done',
              variant: AppButtonVariant.accent,
              onPressed: () => Get.back(),
            ),
          ],
        ),
      ),
    );
  }
}
