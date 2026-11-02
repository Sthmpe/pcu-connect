import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_icons.dart';
import '../constants/app_sizes.dart';
import '../constants/app_text_styles.dart';
import '../utils/month_utils.dart';

enum AppButtonVariant {
  /// Gold. The one main action on a screen.
  primary,

  /// Navy. Strong but secondary (for example Call).
  navy,

  /// Soft grey fill.
  secondary,

  /// Hairline outline.
  outline,

  /// Soft red for destructive actions.
  danger,
}

/// The one button used across the app. 48px tall, radius 12.
class AppButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final Widget? leading;
  final AppButtonVariant variant;
  final bool isLoading;
  final bool expand;

  /// A small button: 36px tall inside a 44px touch target, smaller text.
  final bool compact;

  const AppButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.leading,
    this.variant = AppButtonVariant.primary,
    this.isLoading = false,
    this.expand = true,
    this.compact = false,
  });

  ({Color bg, Color fg, Color? border}) get _colors {
    switch (variant) {
      case AppButtonVariant.primary:
        return (bg: AppColors.gold, fg: AppColors.navy, border: null);
      case AppButtonVariant.navy:
        return (bg: AppColors.navy, fg: AppColors.onNavy, border: null);
      case AppButtonVariant.secondary:
        return (bg: AppColors.sunken, fg: AppColors.ink, border: null);
      case AppButtonVariant.outline:
        return (bg: AppColors.surface, fg: AppColors.ink, border: AppColors.lineStrong);
      case AppButtonVariant.danger:
        return (bg: AppColors.redSoft, fg: AppColors.redInk, border: null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = _colors;
    final radius = BorderRadius.circular(AppSizes.radiusSm);
    final enabled = onPressed != null && !isLoading;

    final content = isLoading
        ? SizedBox(
            width: AppSizes.iconMd,
            height: AppSizes.iconMd,
            child: CircularProgressIndicator(strokeWidth: 2, color: c.fg),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (leading != null) ...[
                leading!,
                SizedBox(width: AppSizes.s8),
              ] else if (icon != null) ...[
                Icon(icon, size: compact ? AppSizes.iconSm : AppSizes.iconMd, color: c.fg),
                SizedBox(width: compact ? AppSizes.s4 + 2 : AppSizes.s8),
              ],
              Flexible(
                child: Text(label,
                    textAlign: TextAlign.center,
                    style: AppTextStyles.centered(compact ? AppTextStyles.captionStrong : AppTextStyles.button)
                        .copyWith(color: c.fg),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ),
            ],
          );

    final button = AnimatedOpacity(
      duration: AppDurations.fast,
      opacity: enabled || isLoading ? 1 : 0.45,
      child: Material(
        color: c.bg,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: c.border == null ? BorderSide.none : BorderSide(color: c.border!),
        ),
        child: InkWell(
          onTap: enabled ? onPressed : null,
          borderRadius: radius,
          child: Container(
            height: compact ? 36 : AppSizes.buttonHeight,
            width: expand ? double.infinity : null,
            padding: EdgeInsets.symmetric(horizontal: compact ? AppSizes.s16 : AppSizes.s24),
            // A button that does not expand is only as wide as its label.
            alignment: expand ? Alignment.center : null,
            child: expand ? content : Center(widthFactor: 1, child: content),
          ),
        ),
      ),
    );
    if (!compact) return button;
    // The small button still answers taps across a 44px tall area.
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: enabled ? onPressed : null,
      child: SizedBox(height: 44, child: Center(widthFactor: 1, child: button)),
    );
  }
}

/// Round icon button: a 40px circle inside a 48px touch target.
class AppIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;
  final Color background;
  final Color foreground;
  final double? size;

  const AppIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.background = AppColors.sunken,
    this.foreground = AppColors.ink,
    this.size,
  });

  @override
  Widget build(BuildContext context) {
    final visual = size ?? AppSizes.iconButton;
    return Tooltip(
      message: tooltip,
      child: SizedBox(
        width: AppSizes.touch.clamp(visual, double.infinity),
        height: AppSizes.touch.clamp(visual, double.infinity),
        child: Center(
          child: Material(
            color: background,
            shape: const CircleBorder(),
            child: InkWell(
              onTap: onTap,
              customBorder: const CircleBorder(),
              child: SizedBox(
                width: visual,
                height: visual,
                child: Icon(icon, size: AppSizes.iconMd, color: foreground),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Selectable chip with an optional count. Selected chips are gold.
class AppChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final int? count;

  const AppChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.count,
  });

  @override
  Widget build(BuildContext context) {
    final style = AppTextStyles.centered(
            selected ? AppTextStyles.captionStrong : AppTextStyles.caption)
        .copyWith(color: selected ? AppColors.navy : AppColors.inkSoft);
    return Semantics(
      button: true,
      selected: selected,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          height: AppSizes.touch,
          child: Center(
            child: AnimatedContainer(
              duration: AppDurations.fast,
              curve: AppDurations.curve,
              height: AppSizes.chipHeight + AppSizes.s4,
              padding: EdgeInsets.symmetric(horizontal: AppSizes.s16),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected ? AppColors.gold : AppColors.surface,
                borderRadius: BorderRadius.circular(AppSizes.radiusFull),
                boxShadow: selected ? null : AppShadows.control,
              ),
              child: Text.rich(
                TextSpan(children: [
                  TextSpan(text: label),
                  if (count != null)
                    TextSpan(
                      text: '  $count',
                      style: TextStyle(
                        color: selected
                            ? AppColors.navy.withValues(alpha: 0.65)
                            : AppColors.muted,
                      ),
                    ),
                ]),
                style: style,
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Horizontally scrolling chip row with page gutters.
class ChipBar extends StatelessWidget {
  final List<Widget> chips;

  const ChipBar({super.key, required this.chips});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: AppSizes.gutter),
        child: Row(
          children: [
            for (var i = 0; i < chips.length; i++) ...[
              if (i > 0) SizedBox(width: AppSizes.s8),
              chips[i],
            ],
          ],
        ),
      ),
    );
  }
}

/// Segmented control for two or three short options.
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
      height: AppSizes.touch,
      padding: EdgeInsets.all(AppSizes.s4),
      decoration: BoxDecoration(
        color: AppColors.sunken,
        borderRadius: BorderRadius.circular(AppSizes.radiusSm),
      ),
      child: Row(
        children: [
          for (final o in options)
            Expanded(
              child: GestureDetector(
                onTap: () => onChanged(o),
                behavior: HitTestBehavior.opaque,
                child: AnimatedContainer(
                  duration: AppDurations.fast,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: o == value ? AppColors.surface : Colors.transparent,
                    borderRadius: BorderRadius.circular(AppSizes.radiusSm - 4),
                    boxShadow: o == value ? AppShadows.card : null,
                  ),
                  child: Text(
                    o,
                    textAlign: TextAlign.center,
                    style: AppTextStyles.centered(o == value
                            ? AppTextStyles.captionStrong
                            : AppTextStyles.caption)
                        .copyWith(
                            color: o == value ? AppColors.navy : AppColors.muted),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Title, optional hint, and a switch. Sits inside a card.
class AppSwitchRow extends StatelessWidget {
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final Widget? extra;

  const AppSwitchRow({
    super.key,
    required this.title,
    this.subtitle,
    required this.value,
    required this.onChanged,
    this.extra,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onChanged == null ? null : () => onChanged!(!value),
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: AppSizes.touch + AppSizes.s16),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: AppSizes.s16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(title, style: AppTextStyles.body),
                    if (subtitle != null) ...[
                      SizedBox(height: AppSizes.s4 / 2),
                      Text(subtitle!, style: AppTextStyles.caption),
                    ],
                  ],
                ),
              ),
              ?extra,
              Transform.scale(
                scale: 0.85,
                child: Switch(value: value, onChanged: onChanged),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Label above a themed text field.
class AppTextField extends StatelessWidget {
  final String label;
  final String? hint;
  final TextEditingController? controller;
  final TextInputType keyboardType;
  final String? Function(String?)? validator;
  final int maxLines;
  final int? minLines;
  final TextInputAction? textInputAction;
  final Iterable<String>? autofillHints;
  final TextCapitalization textCapitalization;

  const AppTextField({
    super.key,
    required this.label,
    this.hint,
    this.controller,
    this.keyboardType = TextInputType.text,
    this.validator,
    this.maxLines = 1,
    this.minLines,
    this.textInputAction,
    this.autofillHints,
    this.textCapitalization = TextCapitalization.none,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTextStyles.captionStrong),
        SizedBox(height: AppSizes.s8),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          validator: validator,
          maxLines: maxLines,
          minLines: minLines,
          textInputAction: textInputAction,
          autofillHints: autofillHints,
          textCapitalization: textCapitalization,
          style: AppTextStyles.body,
          decoration: InputDecoration(hintText: hint),
        ),
      ],
    );
  }
}

/// "October 2026 v" pill that opens the month sheet.
class MonthPill extends StatelessWidget {
  final String month;
  final ValueChanged<String> onChanged;

  /// Offers "All months" at the top of the list (the worker's Guests screen).
  final bool allowAll;

  const MonthPill({super.key, required this.month, required this.onChanged, this.allowAll = false});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Choose month, ${MonthUtils.label(month)}',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () async {
          final m = await showMonthSheet(context, month, allowAll: allowAll);
          if (m != null && m != month) onChanged(m);
        },
        child: SizedBox(
          height: AppSizes.touch,
          child: Center(
            child: Container(
              height: AppSizes.chipHeight + AppSizes.s4,
              padding: EdgeInsets.only(left: AppSizes.s16, right: AppSizes.s8),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppSizes.radiusFull),
                boxShadow: AppShadows.control,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(MonthUtils.short(month),
                      style: AppTextStyles.centered(AppTextStyles.captionStrong)),
                  SizedBox(width: AppSizes.s4),
                  Icon(AppIcons.chevronDown,
                      size: AppSizes.iconSm, color: AppColors.inkSoft),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Bottom sheet listing recent months. Resolves to the chosen key or null.
Future<String?> showMonthSheet(BuildContext context, String current, {bool allowAll = false}) {
  return showModalBottomSheet<String>(
    context: context,
    builder: (sheetContext) => SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
            AppSizes.s16, 0, AppSizes.s16, AppSizes.s16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(
                  AppSizes.s8, 0, AppSizes.s8, AppSizes.s8),
              child: Text('Choose a month', style: AppTextStyles.title),
            ),
            for (final m in [if (allowAll) MonthUtils.all, ...MonthUtils.recent(6)])
              InkWell(
                borderRadius: BorderRadius.circular(AppSizes.radiusSm),
                onTap: () => Navigator.pop(sheetContext, m),
                child: Container(
                  height: AppSizes.touch,
                  padding: EdgeInsets.symmetric(horizontal: AppSizes.s8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          MonthUtils.label(m),
                          style: m == current
                              ? AppTextStyles.bodyStrong
                              : AppTextStyles.body,
                        ),
                      ),
                      if (m == current)
                        Icon(AppIcons.check,
                            size: AppSizes.iconMd, color: AppColors.navy),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    ),
  );
}
