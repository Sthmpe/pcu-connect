import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_text_styles.dart';

/// True when the device asks for less motion: every attention animation
/// then holds still.
bool reduceMotion(BuildContext context) => MediaQuery.maybeDisableAnimationsOf(context) ?? false;

/// A small red dot that breathes gently (a soft pulse, never a flash): work
/// is waiting on this row. It takes the space of a plain dot of [size]; the
/// soft halo draws around it without moving anything.
class PulseDot extends StatefulWidget {
  final double size;
  final Color color;

  const PulseDot({super.key, this.size = 8, this.color = AppColors.red});

  @override
  State<PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<PulseDot> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1800));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (reduceMotion(context)) {
      _c.stop();
      _c.value = 0;
    } else if (!_c.isAnimating) {
      _c.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.size;
    return SizedBox(
      width: s,
      height: s,
      child: OverflowBox(
        maxWidth: s * 2,
        maxHeight: s * 2,
        child: AnimatedBuilder(
          animation: _c,
          builder: (_, _) {
            final t = Curves.easeInOut.transform(_c.value);
            return Stack(
              alignment: Alignment.center,
              children: [
                // Soft halo that swells and fades.
                Container(
                  width: s * (1.2 + 0.7 * t),
                  height: s * (1.2 + 0.7 * t),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: widget.color.withValues(alpha: 0.22 * (1 - t) + 0.06),
                  ),
                ),
                Container(
                  width: s,
                  height: s,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: widget.color),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// A red count badge with soft rings that ripple out from it, to catch the
/// eye without flashing. With [count] 0 it shows nothing.
class RippleBadge extends StatefulWidget {
  final int count;
  final double size;

  const RippleBadge({super.key, required this.count, this.size = 18});

  @override
  State<RippleBadge> createState() => _RippleBadgeState();
}

class _RippleBadgeState extends State<RippleBadge> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 2400));

  void _sync() {
    if (widget.count == 0 || reduceMotion(context)) {
      _c.stop();
      _c.value = 0;
    } else if (!_c.isAnimating) {
      _c.repeat();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(RippleBadge old) {
    super.didUpdateWidget(old);
    _sync();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.count == 0) return const SizedBox.shrink();
    final s = widget.size;
    final still = reduceMotion(context);
    final badge = Container(
      constraints: BoxConstraints(minWidth: s, minHeight: s),
      padding: const EdgeInsets.symmetric(horizontal: 5),
      decoration: BoxDecoration(
        color: AppColors.red,
        borderRadius: BorderRadius.circular(s / 2),
        border: Border.all(color: AppColors.surface, width: 2),
      ),
      alignment: Alignment.center,
      child: Text(
        widget.count > 99 ? '99+' : '${widget.count}',
        style: AppTextStyles.centered(AppTextStyles.captionStrong).copyWith(color: AppColors.surface, fontSize: 10),
      ),
    );
    if (still) return badge;
    return AnimatedBuilder(
      animation: _c,
      builder: (_, child) => CustomPaint(painter: _RipplePainter(_c.value, s), child: child),
      child: badge,
    );
  }
}

/// Two rings, half a cycle apart, growing from the badge and fading out.
class _RipplePainter extends CustomPainter {
  final double t;
  final double base;
  _RipplePainter(this.t, this.base);

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    for (final phase in [0.0, 0.5]) {
      final p = (t + phase) % 1.0;
      final radius = base / 2 + p * base * 0.9;
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2 * (1 - p) + 0.5
        ..color = AppColors.red.withValues(alpha: math.max(0, 0.45 * (1 - p)));
      canvas.drawCircle(center, radius, paint);
    }
  }

  @override
  bool shouldRepaint(_RipplePainter old) => old.t != t;
}
