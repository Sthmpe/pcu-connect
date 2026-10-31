import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_sizes.dart';
import '../constants/app_text_styles.dart';

/// White card: radius 20 and a soft shadow, no border.
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;
  final Color? color;
  final Gradient? gradient;

  const AppCard({
    super.key,
    required this.child,
    this.padding,
    this.onTap,
    this.color,
    this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppSizes.radiusLg);
    return Container(
      decoration: BoxDecoration(
        color: gradient == null ? (color ?? AppColors.surface) : null,
        gradient: gradient,
        borderRadius: radius,
        boxShadow: AppShadows.card,
      ),
      child: Material(
        type: MaterialType.transparency,
        borderRadius: radius,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: padding ?? EdgeInsets.all(AppSizes.s24),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// One card holding a list of rows split by hairlines.
class GroupedCard extends StatelessWidget {
  final List<Widget> children;
  final double? dividerIndent;

  const GroupedCard({super.key, required this.children, this.dividerIndent});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0)
              Divider(
                indent: dividerIndent ?? AppSizes.s16,
                endIndent: AppSizes.s16,
              ),
            children[i],
          ],
        ],
      ),
    );
  }
}

/// Section heading in sentence case with an optional text action.
class SectionLabel extends StatelessWidget {
  final String text;
  final String? actionLabel;
  final VoidCallback? onAction;

  const SectionLabel(this.text, {super.key, this.actionLabel, this.onAction});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: AppSizes.s24, bottom: AppSizes.s8),
      child: Row(
        children: [
          Expanded(child: Text(text, style: AppTextStyles.bodyStrong)),
          if (actionLabel != null && onAction != null)
            InkWell(
              onTap: onAction,
              borderRadius: BorderRadius.circular(AppSizes.radiusSm),
              child: Padding(
                padding: EdgeInsets.symmetric(
                    horizontal: AppSizes.s8, vertical: AppSizes.s4),
                child: Text(actionLabel!,
                    style: AppTextStyles.captionStrong
                        .copyWith(color: AppColors.blueInk)),
              ),
            ),
        ],
      ),
    );
  }
}

class StatItem {
  final String value;
  final String label;
  final Color? color;
  final VoidCallback? onTap;

  const StatItem(this.value, this.label, {this.color, this.onTap});
}

/// Numbers in one card, laid out in a grid with hairline separators.
class StatGrid extends StatelessWidget {
  final List<StatItem> items;
  final int columns;

  const StatGrid({super.key, required this.items, this.columns = 2});

  @override
  Widget build(BuildContext context) {
    final rows = <List<StatItem>>[];
    for (var i = 0; i < items.length; i += columns) {
      rows.add(items.sublist(i, (i + columns).clamp(0, items.length)));
    }
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (var r = 0; r < rows.length; r++) ...[
            if (r > 0) const Divider(),
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var c = 0; c < columns; c++) ...[
                    if (c > 0) const VerticalDivider(width: 1, thickness: 1),
                    Expanded(
                      child: c < rows[r].length
                          ? _StatCell(item: rows[r][c])
                          : const SizedBox.shrink(),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StatCell extends StatelessWidget {
  final StatItem item;

  const _StatCell({required this.item});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: item.onTap,
      child: Padding(
        padding: EdgeInsets.all(AppSizes.s16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(item.value,
                style: AppTextStyles.title
                    .copyWith(color: item.color ?? AppColors.ink)),
            SizedBox(height: AppSizes.s4),
            Text(item.label,
                style: AppTextStyles.caption,
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }
}

/// A plain row inside a GroupedCard: label left, value or chevron right.
class InfoTile extends StatelessWidget {
  final IconData? icon;
  final String label;
  final String? value;
  final Color? valueColor;
  final Widget? trailing;
  final VoidCallback? onTap;
  final Color? labelColor;

  const InfoTile({
    super.key,
    this.icon,
    required this.label,
    this.value,
    this.valueColor,
    this.trailing,
    this.onTap,
    this.labelColor,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: AppSizes.touch + AppSizes.s8),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: AppSizes.s16),
          child: Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: AppSizes.iconMd, color: labelColor ?? AppColors.inkSoft),
                SizedBox(width: AppSizes.s16),
              ],
              Expanded(
                child: Text(label,
                    style: AppTextStyles.body
                        .copyWith(color: labelColor ?? AppColors.ink)),
              ),
              if (value != null)
                Text(value!,
                    style: AppTextStyles.body
                        .copyWith(color: valueColor ?? AppColors.muted)),
              ?trailing,
            ],
          ),
        ),
      ),
    );
  }
}
