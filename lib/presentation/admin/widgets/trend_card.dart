import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/network/api_result.dart';
import '../../../core/utils/month_utils.dart';
import '../../../core/widgets/app_surfaces.dart';
import '../../../core/widgets/state_views.dart';
import '../../../data/firestore/trend_repository.dart';

/// Dashboard: the last twelve months, a navy line for guests and a gold line
/// for members. Hidden when there is no trend source (Apps Script mode) or no
/// connection.
class TrendCard extends StatefulWidget {
  const TrendCard({super.key});

  @override
  State<TrendCard> createState() => _TrendCardState();
}

class _TrendCardState extends State<TrendCard> {
  Future<ApiResult<List<MonthCount>>>? _load;
  ITrendRepository? _repo;

  @override
  void initState() {
    super.initState();
    try {
      _repo = context.read<ITrendRepository>();
    } on ProviderNotFoundException {
      _repo = null;
    }
    _load = _repo?.load(MonthUtils.recent(12).reversed.toList());
  }

  void _retry() => setState(() => _load = _repo?.load(MonthUtils.recent(12).reversed.toList()));

  @override
  Widget build(BuildContext context) {
    final load = _load;
    if (load == null) return const SizedBox.shrink();
    return FutureBuilder<ApiResult<List<MonthCount>>>(
      future: load,
      builder: (context, snap) {
        final result = snap.data;
        if (result != null && result.isFailure) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SectionLabel('Last 12 months'),
              ErrorState(message: result.failure!.message, onRetry: _retry),
            ],
          );
        }
        final data = result?.data;
        if (data == null || data.every((m) => m.guests == 0)) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SectionLabel('Last 12 months'),
            AppCard(child: TrendChart(months: data)),
          ],
        );
      },
    );
  }
}

/// "October 2026: 116 guests, 2 members" for the bubble and screen readers.
String trendBubbleText(MonthCount m) =>
    '${MonthUtils.label(m.month)}\n${m.guests} ${m.guests == 1 ? 'guest' : 'guests'} · ${m.members} ${m.members == 1 ? 'member' : 'members'}';

class TrendChart extends StatefulWidget {
  final List<MonthCount> months;

  const TrendChart({super.key, required this.months});

  @override
  State<TrendChart> createState() => _TrendChartState();
}

class _TrendChartState extends State<TrendChart> {
  /// The month the bubble shows (tap, drag or hover), or null.
  int? _selected;

  static const _height = 140.0;

  void _pick(Offset local, double width) {
    final n = widget.months.length;
    final i = (local.dx / (width / n)).floor().clamp(0, n - 1);
    if (i != _selected) setState(() => _selected = i);
  }

  @override
  Widget build(BuildContext context) {
    final months = widget.months;
    final last = months.last;
    Widget key(Color c, String label) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 12, height: 3, color: c),
            SizedBox(width: AppSizes.s4),
            Text(label, style: AppTextStyles.caption),
          ],
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            key(AppColors.navy, 'Guests'),
            SizedBox(width: AppSizes.s16),
            key(AppColors.gold, 'Members'),
          ],
        ),
        SizedBox(height: AppSizes.s16),
        Semantics(
          label: 'Guests and members over the last 12 months. '
              '${MonthUtils.name(last.month)}: ${last.guests} guests, ${last.members} members. Tap a month for its numbers.',
          child: LayoutBuilder(builder: (context, box) {
            final width = box.maxWidth;
            final painter = TrendPainter(months, selected: _selected);
            final sel = _selected;
            return MouseRegion(
              onHover: (e) => _pick(e.localPosition, width),
              onExit: (_) => setState(() => _selected = null),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapDown: (d) => _pick(d.localPosition, width),
                onHorizontalDragStart: (d) => _pick(d.localPosition, width),
                onHorizontalDragUpdate: (d) => _pick(d.localPosition, width),
                child: SizedBox(
                  height: _height,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Positioned.fill(child: ExcludeSemantics(child: CustomPaint(painter: painter))),
                      if (sel != null) _bubble(context, months[sel], painter.pointFor(sel, months[sel].guests, Size(width, _height)), width),
                    ],
                  ),
                ),
              ),
            );
          }),
        ),
        SizedBox(height: AppSizes.s8),
        Row(
          children: [
            for (final m in months)
              Expanded(
                child: Text(
                  MonthUtils.short(m.month).substring(0, 1),
                  textAlign: TextAlign.center,
                  style: AppTextStyles.caption,
                ),
              ),
          ],
        ),
      ],
    );
  }

  /// A small navy bubble above the month, kept inside the chart's width.
  Widget _bubble(BuildContext context, MonthCount m, Offset at, double width) {
    const bubbleWidth = 150.0;
    final left = (at.dx - bubbleWidth / 2).clamp(0.0, width - bubbleWidth);
    final top = (at.dy - 64).clamp(-56.0, _height - 56);
    return Positioned(
      left: left,
      top: top,
      width: bubbleWidth,
      child: IgnorePointer(
        child: Semantics(
          liveRegion: true,
          label: trendBubbleText(m).replaceAll('\n', ', '),
          child: ExcludeSemantics(
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: AppSizes.s8 + 2, vertical: AppSizes.s8 - 2),
              decoration: BoxDecoration(
                color: AppColors.navy,
                borderRadius: BorderRadius.circular(AppSizes.radiusSm),
              ),
              child: Text(
                trendBubbleText(m),
                textAlign: TextAlign.center,
                style: AppTextStyles.caption.copyWith(color: AppColors.onNavy),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Two lines over the same scale; each month sits in the middle of its column.
class TrendPainter extends CustomPainter {
  final List<MonthCount> months;

  /// The month the bubble shows: a guide line and a dot on each line.
  final int? selected;
  TrendPainter(this.months, {this.selected});

  int get maxValue => math.max(1, months.fold<int>(0, (m, c) => math.max(m, math.max(c.guests, c.members))));

  /// Where month [i] with [value] is drawn.
  Offset pointFor(int i, int value, Size size) {
    final step = size.width / months.length;
    final x = step * i + step / 2;
    final y = size.height - (value / maxValue) * (size.height - 8) - 4;
    return Offset(x, y);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final grid = Paint()
      ..color = AppColors.line
      ..strokeWidth = 1;
    canvas.drawLine(Offset(0, size.height - 0.5), Offset(size.width, size.height - 0.5), grid);
    void line(int Function(MonthCount) value, Color color) {
      final paint = Paint()
        ..color = color
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
      final path = Path();
      for (var i = 0; i < months.length; i++) {
        final p = pointFor(i, value(months[i]), size);
        i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
      }
      canvas.drawPath(path, paint);
      canvas.drawCircle(pointFor(months.length - 1, value(months.last), size), 3.5, Paint()..color = color);
    }

    final sel = selected;
    if (sel != null) {
      final x = pointFor(sel, 0, size).dx;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), Paint()
        ..color = AppColors.lineStrong
        ..strokeWidth = 1);
    }
    line((m) => m.guests, AppColors.navy);
    line((m) => m.members, AppColors.gold);
    if (sel != null) {
      for (final (value, color) in [(months[sel].guests, AppColors.navy), (months[sel].members, AppColors.gold)]) {
        final p = pointFor(sel, value, size);
        canvas.drawCircle(p, 5, Paint()..color = AppColors.surface);
        canvas.drawCircle(p, 3.5, Paint()..color = color);
      }
    }
  }

  @override
  bool shouldRepaint(TrendPainter old) => old.months != months || old.selected != selected;
}
