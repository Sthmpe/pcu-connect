import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

/// Gold confetti over everything for a moment, then gone. Nothing when the
/// device asks for less motion.
void showGoldConfetti(OverlayState overlay, {Duration duration = const Duration(milliseconds: 2200)}) {
  if (MediaQuery.maybeDisableAnimationsOf(overlay.context) ?? false) return;
  late OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => GoldConfetti(duration: duration, onDone: () => entry.remove()),
  );
  overlay.insert(entry);
}

class GoldConfetti extends StatefulWidget {
  final Duration duration;
  final VoidCallback onDone;
  final int pieces;

  const GoldConfetti({super.key, required this.duration, required this.onDone, this.pieces = 90});

  @override
  State<GoldConfetti> createState() => _GoldConfettiState();
}

class _GoldConfettiState extends State<GoldConfetti> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: widget.duration)
    ..addStatusListener((s) {
      if (s == AnimationStatus.completed) widget.onDone();
    })
    ..forward();
  late final List<_Piece> _pieces = List.generate(widget.pieces, (i) => _Piece(math.Random(i * 7919 + 17)));

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: ExcludeSemantics(
        child: AnimatedBuilder(
          animation: _c,
          builder: (_, _) => CustomPaint(size: Size.infinite, painter: _ConfettiPainter(_pieces, _c.value)),
        ),
      ),
    );
  }
}

class _Piece {
  static const colors = [AppColors.gold, AppColors.goldInk, AppColors.goldSoft];
  final double x, delay, speed, drift, spin, size;
  final Color color;

  _Piece(math.Random r)
      : x = r.nextDouble(),
        delay = r.nextDouble() * 0.3,
        speed = 0.8 + r.nextDouble() * 0.6,
        drift = (r.nextDouble() - 0.5) * 0.25,
        spin = (r.nextDouble() - 0.5) * 12,
        size = 6 + r.nextDouble() * 6,
        color = colors[r.nextInt(colors.length)];
}

class _ConfettiPainter extends CustomPainter {
  final List<_Piece> pieces;
  final double t;
  _ConfettiPainter(this.pieces, this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    for (final p in pieces) {
      final local = ((t - p.delay) / (1 - p.delay)).clamp(0.0, 1.0);
      if (local <= 0) continue;
      final y = -20 + local * p.speed * (size.height + 40);
      final x = (p.x + p.drift * local) * size.width;
      paint.color = p.color.withValues(alpha: local > 0.8 ? (1 - local) * 5 : 1);
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(p.spin * local);
      canvas.drawRect(Rect.fromCenter(center: Offset.zero, width: p.size, height: p.size * 0.5), paint);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => old.t != t;
}
