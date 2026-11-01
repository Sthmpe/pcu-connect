import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_icons.dart';
import '../../core/constants/app_sizes.dart';
import '../../core/widgets/attention.dart';

/// Next to the month filter: the outstanding icon with a red count that
/// ripples gently, so a month change never hides waiting work.
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
        child: GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: SizedBox(
            width: AppSizes.touch,
            height: AppSizes.touch,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                Container(
                  width: AppSizes.iconButton,
                  height: AppSizes.iconButton,
                  decoration: BoxDecoration(
                    color: count > 0 ? AppColors.redSoft : AppColors.sunken,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(AppIcons.outstanding,
                      size: AppSizes.iconMd, color: count > 0 ? AppColors.redInk : AppColors.inkSoft),
                ),
                Positioned(right: -2, top: 0, child: RippleBadge(count: count)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
