import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../constants/app_colors.dart';
import '../constants/app_sizes.dart';

/// Keeps the whole app phone shaped.
///
/// On narrow viewports the app fills the screen. On wider ones (tablet,
/// laptop) it is drawn inside a centred phone frame. Either way ScreenUtil is
/// configured from the frame width, never the browser window, and text is
/// never scaled above its design size. Used once, in GetMaterialApp.builder,
/// so dialogs, sheets and snackbars also stay inside the frame.
class ResponsiveWebShell extends StatelessWidget {
  final Widget child;

  const ResponsiveWebShell({super.key, required this.child});

  static const double _frameBreakpoint = 520;
  static const double _frameMargin = 24;

  static double resolveFontSize(num fontSize, ScreenUtil su) =>
      fontSize * su.scaleText.clamp(0.92, 1.0);

  static void _configureScale(double width) {
    final design = AppSizes.designSize;
    // Height follows the design aspect ratio, so width alone drives scaling.
    ScreenUtil.configure(
      data: MediaQueryData(
        size: Size(width, width * design.height / design.width),
      ),
      designSize: design,
      minTextAdapt: true,
      splitScreenMode: false,
      fontSizeResolver: resolveFontSize,
    );
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final screen = media.size;
    final framed = screen.width > _frameBreakpoint;

    if (!framed) {
      _configureScale(screen.width);
      return child;
    }

    final roomy = screen.height >= 640;
    final width = AppSizes.frameWidth;
    final height = roomy
        ? math.min(screen.height - _frameMargin * 2, AppSizes.frameMaxHeight)
        : screen.height;
    final radius = roomy ? AppSizes.frameRadius : 0.0;

    _configureScale(width);

    return ColoredBox(
      color: AppColors.desktopBackground,
      child: Center(
        child: Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: AppColors.bg,
            borderRadius: BorderRadius.circular(radius),
            boxShadow: AppShadows.frame,
          ),
          clipBehavior: Clip.antiAlias,
          child: MediaQuery(
            data: media.copyWith(
              size: Size(width, height),
              padding: EdgeInsets.zero,
              viewPadding: EdgeInsets.zero,
              viewInsets: EdgeInsets.zero,
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}
