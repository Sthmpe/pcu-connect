import 'package:flutter/material.dart';
import '../constants/app_sizes.dart';
import '../constants/app_text_styles.dart';
import 'status_tone.dart';

/// Small rounded label with an optional leading dot.
class AppPill extends StatelessWidget {
  final String label;
  final StatusTone tone;
  final bool showDot;

  const AppPill({
    super.key,
    required this.label,
    required this.tone,
    this.showDot = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: AppSizes.p8, vertical: 3.5),
      decoration: BoxDecoration(
        color: tone.background,
        borderRadius: BorderRadius.circular(AppSizes.radiusFull),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showDot) ...[
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: tone.accent,
                shape: BoxShape.circle,
              ),
            ),
            SizedBox(width: AppSizes.p4),
          ],
          Text(label, style: AppTextStyles.pill.copyWith(color: tone.foreground)),
        ],
      ),
    );
  }
}

/// Guest status as shown across the app.
class GuestStatusPill extends StatelessWidget {
  final String status;

  const GuestStatusPill({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    return AppPill(label: status, tone: StatusTone.forStatus(status));
  }
}
