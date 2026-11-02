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

/// A plain red count badge (no ripple or wave). With [count] 0 it shows nothing.
class CountBadge extends StatelessWidget {
  final int count;
  final double size;

  const CountBadge({super.key, required this.count, this.size = 18});

  @override
  Widget build(BuildContext context) {
    if (count == 0) return const SizedBox.shrink();
    return Container(
      constraints: BoxConstraints(minWidth: size, minHeight: size),
      padding: const EdgeInsets.symmetric(horizontal: 5),
      decoration: BoxDecoration(
        color: AppColors.red,
        borderRadius: BorderRadius.circular(size / 2),
        border: Border.all(color: AppColors.surface, width: 2),
      ),
      alignment: Alignment.center,
      child: Text(
        count > 99 ? '99+' : '$count',
        style: AppTextStyles.centered(AppTextStyles.captionStrong).copyWith(color: AppColors.surface, fontSize: 10),
      ),
    );
  }
}
