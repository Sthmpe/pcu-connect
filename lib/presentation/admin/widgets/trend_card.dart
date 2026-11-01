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

class TrendChart extends StatelessWidget {
  final List<MonthCount> months;

  const TrendChart({super.key, required this.months});

  @override
  Widget build(BuildContext context) {
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
              '${MonthUtils.name(last.month)}: ${last.guests} guests, ${last.members} members.',
          child: ExcludeSemantics(
            child: SizedBox(
              height: 140,
              child: CustomPaint(size: Size.infinite, painter: TrendPainter(months)),
            ),
          ),
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
}

/// Two lines over the same scale; each month sits in the middle of its column.
class TrendPainter extends CustomPainter {
  final List<MonthCount> months;
  TrendPainter(this.months);

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

    line((m) => m.guests, AppColors.navy);
    line((m) => m.members, AppColors.gold);
  }

  @override
  bool shouldRepaint(TrendPainter old) => old.months != months;
}
