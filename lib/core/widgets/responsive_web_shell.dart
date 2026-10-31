import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../constants/app_colors.dart';
import '../constants/app_sizes.dart';
import '../constants/app_text_styles.dart';

/// Keeps the whole app phone shaped.
///
/// Narrow viewports get the app full screen. Wider ones (tablet, laptop) get
/// a centred phone frame. Either way ScreenUtil is configured from the frame
/// width, never the browser window, `.sp` never scales text past its design
/// size, and the text scaler is clamped so Flutter web text is not oversized.
/// Used once, in GetMaterialApp.builder, so dialogs, sheets and snackbars stay
/// inside the frame too.
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

  static MediaQueryData _clampText(MediaQueryData media) => media.copyWith(
        textScaler: media.textScaler.clamp(
          minScaleFactor: kIsWeb ? 0.75 : 0.85,
          maxScaleFactor: kIsWeb ? 0.9 : 1.05,
        ),
      );

  static Widget _centred(Widget child) => DefaultTextHeightBehavior(
        textHeightBehavior: AppTextStyles.centeredHeight,
        child: child,
      );

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final screen = media.size;
    final framed = screen.width > _frameBreakpoint;

    if (!framed) {
      _configureScale(screen.width);
      return MediaQuery(data: _clampText(media), child: _centred(child));
    }

    final roomy = screen.height >= 640;
    const width = AppSizes.frameWidth;
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
            data: _clampText(media).copyWith(
              size: Size(width, height),
              padding: EdgeInsets.zero,
              viewPadding: EdgeInsets.zero,
              viewInsets: EdgeInsets.zero,
            ),
            child: _centred(child),
          ),
        ),
      ),
    );
  }
}
