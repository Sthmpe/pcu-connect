import 'dart:math' as math;

import 'package:flutter/material.dart';

/// WhatsApp style mark: a speech bubble ring with a handset inside.
class WhatsAppMark extends StatelessWidget {
  final double size;
  final Color color;

  const WhatsAppMark({super.key, required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _BubblePainter(color),
        child: Center(
          child: Icon(Icons.call_rounded, size: size * 0.5, color: color),
        ),
      ),
    );
  }
}

class _BubblePainter extends CustomPainter {
  final Color color;

  _BubblePainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.width * 0.09;
    final center = size.center(Offset.zero);
    final radius = size.width / 2 - stroke / 2;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;

    // Ring with a gap at the lower left where the tail sits.
    canvas.drawArc(Rect.fromCircle(center: center, radius: radius),
        math.pi * 0.80, math.pi * 1.80, false, paint);

    final tail = Path()
      ..moveTo(center.dx + radius * math.cos(math.pi * 0.80),
          center.dy + radius * math.sin(math.pi * 0.80))
      ..lineTo(size.width * 0.06, size.height * 0.96)
      ..lineTo(center.dx + radius * math.cos(math.pi * 0.62),
          center.dy + radius * math.sin(math.pi * 0.62));
    canvas.drawPath(tail, paint..strokeJoin = StrokeJoin.round);
  }

  @override
  bool shouldRepaint(_BubblePainter old) => old.color != color;
}

/// The four color Google "G".
class GoogleMark extends StatelessWidget {
  final double size;

  const GoogleMark({super.key, required this.size});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _GooglePainter()),
    );
  }
}

class _GooglePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.width * 0.2;
    final rect = Rect.fromCircle(
      center: size.center(Offset.zero),
      radius: size.width / 2 - stroke / 2,
    );
    Paint arc(Color c) => Paint()
      ..color = c
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;

    const deg = math.pi / 180;
    canvas.drawArc(rect, -40 * deg, -100 * deg, false, arc(const Color(0xFFEA4335)));
    canvas.drawArc(rect, -140 * deg, -90 * deg, false, arc(const Color(0xFFFBBC05)));
    canvas.drawArc(rect, 130 * deg, -90 * deg, false, arc(const Color(0xFF34A853)));
    canvas.drawArc(rect, 40 * deg, -40 * deg, false, arc(const Color(0xFF4285F4)));

    // The bar of the G.
    canvas.drawRect(
      Rect.fromLTWH(size.width / 2, size.height / 2 - stroke / 2,
          size.width / 2 - stroke * 0.05, stroke),
      Paint()..color = const Color(0xFF4285F4),
    );
  }

  @override
  bool shouldRepaint(_GooglePainter old) => false;
}
