import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_sizes.dart';
import '../constants/app_text_styles.dart';

/// Compact selectable chip. Selected chips are navy with white text.
class FilterChipWidget extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final int? count;

  const FilterChipWidget({
    super.key,
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.count,
  });

  @override
  Widget build(BuildContext context) {
    final fg = isSelected ? AppColors.onNavy : AppColors.inkSoft;
    return Semantics(
      selected: isSelected,
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSizes.radiusFull),
        child: AnimatedContainer(
          duration: AppDurations.fast,
          height: AppSizes.chipHeight,
          padding: EdgeInsets.symmetric(horizontal: AppSizes.p12),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected ? AppColors.navy : AppColors.surface,
            borderRadius: BorderRadius.circular(AppSizes.radiusFull),
            border: Border.all(
              color: isSelected ? AppColors.navy : AppColors.lineStrong,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: AppTextStyles.chip.copyWith(
                  color: fg,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
              if (count != null) ...[
                SizedBox(width: AppSizes.p6),
                Text(
                  '$count',
                  style: AppTextStyles.caption.copyWith(
                    color: isSelected ? AppColors.gold : AppColors.muted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Horizontally scrolling row of chips with page gutters.
class ChipBar extends StatelessWidget {
  final List<Widget> chips;
  final EdgeInsetsGeometry? padding;

  const ChipBar({super.key, required this.chips, this.padding});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: padding ??
            EdgeInsets.fromLTRB(
                AppSizes.gutter, AppSizes.p12, AppSizes.gutter, AppSizes.p4),
        child: Row(
          children: [
            for (var i = 0; i < chips.length; i++) ...[
              if (i > 0) SizedBox(width: AppSizes.p8),
              chips[i],
            ],
          ],
        ),
      ),
    );
  }
}

/// Segmented control for two to three short options.
class SegmentedPicker extends StatelessWidget {
  final List<String> options;
  final String value;
  final ValueChanged<String> onChanged;

  const SegmentedPicker({
    super.key,
    required this.options,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(AppSizes.p4),
      decoration: BoxDecoration(
        color: AppColors.neutralSoft,
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
      ),
      child: Row(
        children: options.map((o) {
          final selected = o == value;
          return Expanded(
            child: GestureDetector(
              onTap: () => onChanged(o),
              behavior: HitTestBehavior.opaque,
              child: AnimatedContainer(
                duration: AppDurations.fast,
                height: AppSizes.buttonHeightSm,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: selected ? AppColors.surface : Colors.transparent,
                  borderRadius: BorderRadius.circular(AppSizes.radiusSm),
                  boxShadow: selected ? AppShadows.card : null,
                ),
                child: Text(
                  o,
                  style: AppTextStyles.chip.copyWith(
                    color: selected ? AppColors.navy : AppColors.muted,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
