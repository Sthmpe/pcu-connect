import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_icons.dart';
import '../../core/widgets/app_controls.dart';
import '../../core/widgets/attention.dart';

/// Next to the month filter: the outstanding icon with a red count that
/// ripples gently, so a month change never hides waiting work. The same
/// circle as every other top-bar icon button (AppIconButton), with the
/// count laid over its corner.
class OutstandingButton extends StatelessWidget {
  final int count;
  final VoidCallback onTap;

  const OutstandingButton({super.key, required this.count, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: count == 0 ? 'Outstanding, none' : 'Outstanding, $count',
      child: ExcludeSemantics(
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            AppIconButton(
              icon: AppIcons.outstanding,
              tooltip: 'Outstanding',
              background: count > 0 ? AppColors.redSoft : AppColors.sunken,
              foreground: count > 0 ? AppColors.redInk : AppColors.inkSoft,
              onTap: onTap,
            ),
            Positioned(right: -2, top: 0, child: IgnorePointer(child: RippleBadge(count: count))),
          ],
        ),
      ),
    );
  }
}
