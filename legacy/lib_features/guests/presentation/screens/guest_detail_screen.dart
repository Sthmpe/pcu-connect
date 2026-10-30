import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/routing/app_routes.dart';
import '../../../../core/widgets/custom_button.dart';
import '../../domain/models/guest_model.dart';
import '../bloc/guest_bloc.dart';
import '../bloc/guest_event.dart';
import '../bloc/guest_state.dart';
import '../widgets/guest_stage_badge.dart';

class GuestDetailScreen extends StatefulWidget {
  final String guestId;

  const GuestDetailScreen({super.key, required this.guestId});

  @override
  State<GuestDetailScreen> createState() => _GuestDetailScreenState();
}

class _GuestDetailScreenState extends State<GuestDetailScreen> {
  @override
  void initState() {
    super.initState();
    context.read<GuestBloc>().add(LoadContactDetail(widget.guestId));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text(AppStrings.guestDetail)),
      body: BlocBuilder<GuestBloc, GuestState>(
        builder: (context, state) {
          if (state is GuestDetailLoading || state is GuestInitial) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            );
          }
          if (state is GuestDetailFailure) {
            return Center(
              child: Text(
                AppStrings.genericError,
                style: AppTextStyles.bodyMedium,
              ),
            );
          }
          final guest = (state as GuestDetailLoaded).guest;
          return _GuestDetailBody(guest: guest);
        },
      ),
    );
  }
}

class _GuestDetailBody extends StatelessWidget {
  final GuestModel guest;

  const _GuestDetailBody({required this.guest});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.all(AppSizes.p16),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(guest.fullName, style: AppTextStyles.displayMedium),
            ),
            GuestStageBadge(stage: guest.currentStage),
          ],
        ),
        SizedBox(height: AppSizes.p8),
        Text(guest.phoneOriginal, style: AppTextStyles.bodyLarge),
        if (guest.serviceName != null) ...[
          SizedBox(height: AppSizes.p4),
          Text(guest.serviceName!, style: AppTextStyles.bodySmall),
        ],
        SizedBox(height: AppSizes.p24),
        CustomButton(
          text: AppStrings.callGuestAction,
          icon: FontAwesomeIcons.phone,
          onPressed: () => Navigator.of(
            context,
          ).pushNamed(AppRoutes.callFeedback, arguments: guest),
        ),
        SizedBox(height: AppSizes.p12),
        CustomButton(
          text: AppStrings.scheduleFollowUp,
          icon: Icons.event_outlined,
          backgroundColor: AppColors.surface,
          textColor: AppColors.primary,
          onPressed: () => Navigator.of(
            context,
          ).pushNamed(AppRoutes.callFeedback, arguments: guest),
        ),
        SizedBox(height: AppSizes.p32),
        Text('Journey', style: AppTextStyles.titleLarge),
        SizedBox(height: AppSizes.p12),
        _TimelineRow(label: AppStrings.metricReceived, date: guest.receivedAt),
        _TimelineRow(
          label: AppStrings.outcomeConnected,
          date: guest.contactedAt,
        ),
        _TimelineRow(label: 'Returned', date: guest.returnedAt),
        _TimelineRow(label: AppStrings.metricRetained, date: guest.retainedAt),
      ],
    );
  }
}

class _TimelineRow extends StatelessWidget {
  final String label;
  final DateTime? date;

  const _TimelineRow({required this.label, required this.date});

  @override
  Widget build(BuildContext context) {
    final reached = date != null;
    return Padding(
      padding: EdgeInsets.symmetric(vertical: AppSizes.p8),
      child: Row(
        children: [
          Icon(
            reached ? Icons.check_circle : Icons.radio_button_unchecked,
            size: AppSizes.iconSm,
            color: reached ? AppColors.success : AppColors.textMuted,
          ),
          SizedBox(width: AppSizes.p12),
          Expanded(
            child: Text(
              label,
              style: AppTextStyles.bodyMedium.copyWith(
                color: reached ? AppColors.textPrimary : AppColors.textMuted,
              ),
            ),
          ),
          if (reached)
            Text(
              '${date!.month}/${date!.day}/${date!.year}',
              style: AppTextStyles.caption,
            ),
        ],
      ),
    );
  }
}
