import 'package:flutter/material.dart';
import '../constants/app_icons.dart';
import '../constants/app_sizes.dart';
import '../constants/app_text_styles.dart';
import 'app_controls.dart';

/// Top-level tab page: a large title on the page background, then content.
class AppPage extends StatelessWidget {
  final String title;
  final String? eyebrow;
  final String? subtitle;
  final Widget? trailing;
  final Widget? below;
  final Widget child;

  const AppPage({
    super.key,
    required this.title,
    required this.child,
    this.eyebrow,
    this.subtitle,
    this.trailing,
    this.below,
  });

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(
              AppSizes.gutter, top + AppSizes.s32, AppSizes.gutter, AppSizes.s16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (eyebrow != null) ...[
                      Text(eyebrow!, style: AppTextStyles.caption),
                      SizedBox(height: AppSizes.s4),
                    ],
                    Text(title,
                        style: AppTextStyles.display,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    if (subtitle != null) ...[
                      SizedBox(height: AppSizes.s4),
                      Text(subtitle!, style: AppTextStyles.bodyMuted),
                    ],
                  ],
                ),
              ),
              if (trailing != null) ...[
                SizedBox(width: AppSizes.s16),
                trailing!,
              ],
            ],
          ),
        ),
        ?below,
        Expanded(child: child),
      ],
    );
  }
}

/// Compact bar for pushed screens: back, title, optional action.
class AppTopBar extends StatelessWidget {
  final String? title;
  final Widget? trailing;

  const AppTopBar({super.key, this.title, this.trailing});

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return Padding(
      padding: EdgeInsets.fromLTRB(AppSizes.s8, top + AppSizes.s8, AppSizes.s8, 0),
      child: SizedBox(
        height: AppSizes.topBarHeight,
        child: Row(
          children: [
            AppIconButton(
              icon: AppIcons.back,
              tooltip: 'Back',
              onTap: () => Navigator.of(context).maybePop(),
              background: Colors.transparent,
            ),
            SizedBox(width: AppSizes.s4),
            Expanded(
              child: title == null
                  ? const SizedBox.shrink()
                  : Text(title!,
                      style: AppTextStyles.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
            ),
            ?trailing,
          ],
        ),
      ),
    );
  }
}

/// Scrollable page body with standard gutters and room at the bottom.
class PageList extends StatelessWidget {
  final List<Widget> children;
  final EdgeInsetsGeometry? padding;

  const PageList({super.key, required this.children, this.padding});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: padding ??
          EdgeInsets.fromLTRB(
              AppSizes.gutter, AppSizes.s8, AppSizes.gutter, AppSizes.s32),
      children: children,
    );
  }
}
