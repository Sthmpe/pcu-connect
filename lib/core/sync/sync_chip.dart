import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../constants/app_colors.dart';
import '../constants/app_icons.dart';
import '../constants/app_sizes.dart';
import '../constants/app_text_styles.dart';
import 'sync_status_cubit.dart';

/// Small chip for the top bar: offline, syncing, or all synced.
/// Nothing when there is no SyncStatusCubit (Apps Script mode) or all is quiet.
class SyncChip extends StatelessWidget {
  const SyncChip({super.key});

  static (String, IconData, Color, Color)? look(SyncChipState s) => switch (s) {
        SyncChipState.offline => ('Offline, saves will sync', AppIcons.offline, AppColors.amberSoft, AppColors.amberInk),
        SyncChipState.syncing => ('Syncing', AppIcons.sync, AppColors.navySoft, AppColors.navy),
        SyncChipState.synced => ('All synced', AppIcons.check, AppColors.greenSoft, AppColors.greenInk),
        SyncChipState.hidden => null,
      };

  @override
  Widget build(BuildContext context) {
    final SyncStatusCubit cubit;
    try {
      cubit = context.read<SyncStatusCubit>();
    } on ProviderNotFoundException {
      return const SizedBox.shrink();
    }
    return BlocBuilder<SyncStatusCubit, SyncChipState>(
      bloc: cubit,
      builder: (context, state) {
        final l = look(state);
        return AnimatedSwitcher(
          duration: AppDurations.fast,
          child: l == null
              ? const SizedBox.shrink()
              : Semantics(
                  key: ValueKey(state),
                  liveRegion: true,
                  label: l.$1,
                  child: ExcludeSemantics(
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: AppSizes.s8 + 2, vertical: AppSizes.s4),
                      decoration: BoxDecoration(color: l.$3, borderRadius: BorderRadius.circular(AppSizes.radiusFull)),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(l.$2, size: AppSizes.iconSm, color: l.$4),
                          SizedBox(width: AppSizes.s4),
                          Text(l.$1, style: AppTextStyles.centered(AppTextStyles.caption).copyWith(color: l.$4)),
                        ],
                      ),
                    ),
                  ),
                ),
        );
      },
    );
  }
}
