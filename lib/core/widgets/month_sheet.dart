import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_sizes.dart';
import '../constants/app_text_styles.dart';

/// Months the app offers in pickers, newest first.
const List<String> kAppMonths = [
  'Oct 2026',
  'Sep 2026',
  'Aug 2026',
  'Jul 2026',
  'Jun 2026',
  'May 2026',
];

/// 'Oct 2026' -> 'Oct 26'
String shortMonth(String month) => month.replaceFirst(' 20', ' ');

/// Bottom sheet to choose a month. Resolves to the chosen month or null.
Future<String?> showMonthSheet(BuildContext context, String current) {
  return showModalBottomSheet<String>(
    context: context,
    builder: (sheetContext) => SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
            AppSizes.gutter, 0, AppSizes.gutter, AppSizes.p16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Choose a month', style: AppTextStyles.sectionTitle),
            SizedBox(height: AppSizes.p8),
            ...kAppMonths.map((m) {
              final selected = m == current;
              return ListTile(
                contentPadding: EdgeInsets.symmetric(horizontal: AppSizes.p8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                ),
                dense: true,
                tileColor: selected ? AppColors.navySoft : null,
                title: Text(
                  m,
                  style: selected
                      ? AppTextStyles.bodyStrong.copyWith(color: AppColors.navy)
                      : AppTextStyles.body,
                ),
                trailing: selected
                    ? Icon(Icons.check_rounded,
                        size: AppSizes.iconMd, color: AppColors.navy)
                    : null,
                onTap: () => Navigator.pop(sheetContext, m),
              );
            }),
          ],
        ),
      ),
    ),
  );
}
