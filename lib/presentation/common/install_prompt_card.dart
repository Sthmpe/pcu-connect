import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_icons.dart';
import '../../core/constants/app_sizes.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/install/install_support.dart';
import '../../core/widgets/app_controls.dart';
import '../../core/widgets/app_surfaces.dart';
import 'install_prompt_cubit.dart';

/// "Add to Home Screen" (InstallPromptCubit decides when it shows).
class InstallPromptCard extends StatelessWidget {
  const InstallPromptCard({super.key});

  static const iphoneSteps = [
    'Tap the Share button at the bottom of Safari.',
    'Scroll down and tap Add to Home Screen.',
    'Tap Add.',
  ];

  static const androidSteps = [
    'Tap the three dots at the top right of Chrome.',
    'Tap Add to Home screen or Install app.',
    'Tap Add or Install.',
  ];

  @override
  Widget build(BuildContext context) {
    final InstallPromptCubit cubit;
    try {
      cubit = context.read<InstallPromptCubit>();
    } on ProviderNotFoundException {
      return const SizedBox.shrink();
    }
    return BlocBuilder<InstallPromptCubit, InstallPromptState>(
      bloc: cubit,
      builder: (context, state) {
        if (!state.show) return const SizedBox.shrink();
        Widget steps(String title, List<String> lines) => Padding(
              padding: EdgeInsets.only(top: AppSizes.s16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppTextStyles.captionStrong),
                  SizedBox(height: AppSizes.s4),
                  for (var i = 0; i < lines.length; i++)
                    Padding(
                      padding: EdgeInsets.only(top: AppSizes.s4),
                      child: Text('${i + 1}. ${lines[i]}', style: AppTextStyles.bodyMuted),
                    ),
                ],
              ),
            );
        return Padding(
          padding: EdgeInsets.only(bottom: AppSizes.s16),
          child: AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(AppIcons.install, size: AppSizes.iconMd, color: AppColors.inkSoft),
                    SizedBox(width: AppSizes.s16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Add PCU Connect to your Home Screen', style: AppTextStyles.bodyStrong),
                          SizedBox(height: AppSizes.s4),
                          Text('Open it like an app, in one tap.', style: AppTextStyles.bodyMuted),
                        ],
                      ),
                    ),
                  ],
                ),
                if (!state.canPrompt) ...[
                  if (state.platform != InstallPlatform.android) steps('On iPhone', iphoneSteps),
                  if (state.platform != InstallPlatform.iphone) steps('On Android', androidSteps),
                ],
                SizedBox(height: AppSizes.s16),
                Row(
                  children: [
                    Expanded(
                      child: AppButton(
                        label: state.canPrompt ? 'Not now' : 'Got it',
                        variant: AppButtonVariant.outline,
                        onPressed: state.busy ? null : cubit.dismiss,
                      ),
                    ),
                    if (state.canPrompt) ...[
                      SizedBox(width: AppSizes.s8),
                      Expanded(
                        child: AppButton(
                          label: 'Add to Home Screen',
                          variant: AppButtonVariant.navy,
                          isLoading: state.busy,
                          onPressed: cubit.install,
                        ),
                      ),
                    ],
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
