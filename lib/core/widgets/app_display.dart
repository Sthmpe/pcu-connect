import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_sizes.dart';
import '../constants/app_text_styles.dart';
import 'status_tone.dart';

/// Initials avatar.
class AppAvatar extends StatelessWidget {
  final String name;
  final double size;
  final Color background;
  final Color foreground;

  const AppAvatar({
    super.key,
    required this.name,
    required this.size,
    this.background = AppColors.navySoft,
    this.foreground = AppColors.navy,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: background, shape: BoxShape.circle),
      child: Text(
        initialsOf(name),
        style: AppTextStyles.bodyStrong.copyWith(
          color: foreground,
          fontSize: size * 0.36,
          height: 1,
        ),
      ),
    );
  }
}

class StatusDot extends StatelessWidget {
  final Color color;
  final double size;

  const StatusDot(this.color, {super.key, this.size = 8});

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      );
}

/// Soft tinted label with a leading dot.
class AppPill extends StatelessWidget {
  final String label;
  final StatusTone tone;

  const AppPill({super.key, required this.label, required this.tone});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: AppSizes.s8 + 2, vertical: AppSizes.s4),
      decoration: BoxDecoration(
        color: tone.background,
        borderRadius: BorderRadius.circular(AppSizes.radiusFull),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          StatusDot(tone.dot, size: 6),
          SizedBox(width: AppSizes.s8 - 2),
          Text(label, style: AppTextStyles.captionStrong.copyWith(color: tone.foreground)),
        ],
      ),
    );
  }
}

/// Animated circular progress.
class ProgressRing extends StatelessWidget {
  final double value;
  final double size;
  final double stroke;
  final Color color;
  final Color trackColor;
  final Widget? child;

  const ProgressRing({
    super.key,
    required this.value,
    required this.size,
    this.stroke = 8,
    this.color = AppColors.gold,
    this.trackColor = AppColors.sunken,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value.clamp(0.0, 1.0)),
      duration: AppDurations.slow,
      curve: AppDurations.curve,
      builder: (context, v, inner) => SizedBox(
        width: size,
        height: size,
        child: CustomPaint(
          painter: _RingPainter(v, stroke, color, trackColor),
          child: Center(child: inner),
        ),
      ),
      child: child,
    );
  }
}

class _RingPainter extends CustomPainter {
  final double value;
  final double stroke;
  final Color color;
  final Color track;

  _RingPainter(this.value, this.stroke, this.color, this.track);

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromCircle(
      center: size.center(Offset.zero),
      radius: (size.shortestSide - stroke) / 2,
    );
    final base = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, 0, math.pi * 2, false, base..color = track);
    if (value > 0) {
      canvas.drawArc(rect, -math.pi / 2, math.pi * 2 * value, false,
          base..color = color);
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.value != value || old.color != color || old.track != track;
}

/// A row of equal segments, the first [filled] coloured.
class SegmentBar extends StatelessWidget {
  final int total;
  final int filled;
  final Color color;

  const SegmentBar({
    super.key,
    required this.total,
    required this.filled,
    this.color = AppColors.green,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < total; i++) ...[
          if (i > 0) SizedBox(width: AppSizes.s4),
          Expanded(
            child: AnimatedContainer(
              duration: AppDurations.normal,
              height: 6,
              decoration: BoxDecoration(
                color: i < filled ? color : AppColors.sunken,
                borderRadius: BorderRadius.circular(AppSizes.radiusFull),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// Thin animated progress bar.
class AppProgressBar extends StatelessWidget {
  final double value;
  final Color color;

  const AppProgressBar({super.key, required this.value, this.color = AppColors.navy});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppSizes.radiusFull),
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: value.clamp(0.0, 1.0)),
        duration: AppDurations.slow,
        curve: AppDurations.curve,
        builder: (context, v, _) => LinearProgressIndicator(
          value: v,
          minHeight: 6,
          backgroundColor: AppColors.sunken,
          valueColor: AlwaysStoppedAnimation<Color>(color),
        ),
      ),
    );
  }
}
