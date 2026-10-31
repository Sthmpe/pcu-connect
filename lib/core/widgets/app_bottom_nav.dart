import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_sizes.dart';
import '../constants/app_text_styles.dart';

class AppNavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;

  const AppNavItem(this.icon, this.activeIcon, this.label);
}

/// Bottom navigation with a soft pill behind the active icon.
class AppBottomNav extends StatelessWidget {
  final List<AppNavItem> items;
  final int currentIndex;
  final ValueChanged<int> onTap;

  const AppBottomNav({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: const Border(top: BorderSide(color: AppColors.line)),
        boxShadow: AppShadows.bar,
      ),
      padding: EdgeInsets.only(bottom: MediaQuery.paddingOf(context).bottom),
      child: SizedBox(
        height: AppSizes.navBarHeight,
        child: Row(
          children: [
            for (var i = 0; i < items.length; i++)
              Expanded(child: _NavButton(
                item: items[i],
                selected: i == currentIndex,
                onTap: () => onTap(i),
              )),
          ],
        ),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  final AppNavItem item;
  final bool selected;
  final VoidCallback onTap;

  const _NavButton({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.navy : AppColors.muted;
    return Semantics(
      selected: selected,
      button: true,
      label: item.label,
      child: InkWell(
        onTap: onTap,
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: AppDurations.normal,
              curve: AppDurations.curve,
              width: selected ? 52 : 40,
              height: 28,
              decoration: BoxDecoration(
                color: selected ? AppColors.navySoft : Colors.transparent,
                borderRadius: BorderRadius.circular(AppSizes.radiusFull),
              ),
              child: Icon(
                selected ? item.activeIcon : item.icon,
                size: AppSizes.iconMd,
                color: color,
              ),
            ),
            SizedBox(height: AppSizes.p4),
            Text(
              item.label,
              style: AppTextStyles.navLabel.copyWith(
                color: color,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// IndexedStack that keeps every tab alive and fades the active one in.
class FadeIndexedStack extends StatefulWidget {
  final int index;
  final List<Widget> children;

  const FadeIndexedStack({
    super.key,
    required this.index,
    required this.children,
  });

  @override
  State<FadeIndexedStack> createState() => _FadeIndexedStackState();
}

class _FadeIndexedStackState extends State<FadeIndexedStack>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: AppDurations.normal,
    value: 1,
  );

  @override
  void didUpdateWidget(FadeIndexedStack oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.index != widget.index) _controller.forward(from: 0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: CurvedAnimation(parent: _controller, curve: AppDurations.curve),
      child: IndexedStack(index: widget.index, children: widget.children),
    );
  }
}
