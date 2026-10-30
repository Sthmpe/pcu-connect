import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

/// Centers the application inside a 390-430px mobile frame on desktop web,
/// and expands naturally to full-screen on mobile viewports.
class ResponsiveWebShell extends StatelessWidget {
  final Widget child;
  final double maxWidth;

  const ResponsiveWebShell({
    super.key,
    required this.child,
    this.maxWidth = 430.0,
  });

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb) return child;

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth <= maxWidth) {
          return child;
        }

        return Container(
          color: AppColors.desktopBackground,
          alignment: Alignment.center,
          child: Container(
            width: maxWidth,
            constraints: const BoxConstraints(maxHeight: 844),
            decoration: BoxDecoration(
              color: AppColors.bg,
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: AppColors.navy.withValues(alpha: 0.25),
                  blurRadius: 50,
                  offset: const Offset(0, 20),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: child,
          ),
        );
      },
    );
  }
}
