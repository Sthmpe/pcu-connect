import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_icons.dart';
import '../../core/constants/app_sizes.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/widgets/app_controls.dart';
import '../../core/widgets/app_surfaces.dart';
import '../../data/firestore/push_service.dart';
import 'push_cubit.dart';

/// A small, polite card that offers notifications after sign-in. It only
/// appears while the browser has not asked yet, and "Not now" hides it.
class PushPromptCard extends StatelessWidget {
  /// What the person gets, for example "when a guest is assigned to you".
  final String reason;

  const PushPromptCard({super.key, required this.reason});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PushCubit, PushState>(
      builder: (context, state) {
        if (state.message != null) {
          return Padding(
            padding: EdgeInsets.only(bottom: AppSizes.s16),
            child: Text(state.message!,
                style: AppTextStyles.caption.copyWith(
                    color: state.permission == PushPermission.granted ? AppColors.greenInk : AppColors.inkSoft)),
          );
        }
        if (!state.showPrompt) return const SizedBox.shrink();
        final cubit = context.read<PushCubit>();
        return Padding(
          padding: EdgeInsets.only(bottom: AppSizes.s16),
          child: AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(AppIcons.bellRing, size: AppSizes.iconMd, color: AppColors.inkSoft),
                    SizedBox(width: AppSizes.s16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Turn on notifications?', style: AppTextStyles.bodyStrong),
                          SizedBox(height: AppSizes.s4),
                          Text('Get a ping $reason.', style: AppTextStyles.bodyMuted),
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: AppSizes.s16),
                Row(
                  children: [
                    Expanded(
                      child: AppButton(
                        label: 'Not now',
                        variant: AppButtonVariant.outline,
                        onPressed: state.busy ? null : cubit.snooze,
                      ),
                    ),
                    SizedBox(width: AppSizes.s8),
                    Expanded(
                      child: AppButton(
                        label: 'Turn on',
                        variant: AppButtonVariant.navy,
                        isLoading: state.busy,
                        onPressed: cubit.enable,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
