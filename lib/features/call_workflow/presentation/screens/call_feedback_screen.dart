import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/widgets/custom_button.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../../../guests/domain/models/guest_model.dart';
import '../../domain/models/call_interaction_model.dart';
import '../bloc/call_bloc.dart';
import '../bloc/call_event.dart';
import '../bloc/call_state.dart';

const _outcomes = <String, String>{
  'connected': AppStrings.outcomeConnected,
  'no_answer': AppStrings.outcomeNoAnswer,
  'busy': AppStrings.outcomeBusy,
  'voicemail': AppStrings.outcomeVoicemail,
  'wrong_number': AppStrings.outcomeWrongNumber,
};

const _durationBands = <String, String>{
  'under_2m': 'Under 2 minutes',
  '2_5m': '2-5 minutes',
  '5_15m': '5-15 minutes',
  '15m_plus': '15+ minutes',
};

class CallFeedbackScreen extends StatefulWidget {
  final GuestModel guest;

  const CallFeedbackScreen({super.key, required this.guest});

  @override
  State<CallFeedbackScreen> createState() => _CallFeedbackScreenState();
}

class _CallFeedbackScreenState extends State<CallFeedbackScreen> {
  String? _outcome;
  String _durationBand = 'under_2m';
  final _notesController = TextEditingController();
  DateTime? _nextFollowUpAt;
  bool _dialerOpened = false;

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _openDialer() async {
    // Opens the device's native dialer - this app never places or records
    // the call itself (spec section 9: no call recording in v1).
    final uri = Uri(scheme: 'tel', path: widget.guest.phoneE164);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
      setState(() => _dialerOpened = true);
    }
  }

  Future<void> _pickFollowUpDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _nextFollowUpAt = picked);
  }

  void _submit() {
    if (_outcome == null) return;
    final authState = context.read<AuthBloc>().state;
    if (authState is! AuthAuthenticated) return;

    context.read<CallBloc>().add(
      SubmitCallFeedbackEvent(
        CallInteractionModel(
          contactId: widget.guest.id,
          organizationId: widget.guest.organizationId,
          locationId: widget.guest.locationId,
          unitId: widget.guest.unitId,
          operatorId: authState.userProfile.id,
          outcome: _outcome!,
          phoneE164: widget.guest.phoneE164,
          durationSeconds: 0,
          durationBand: _durationBand,
          notes: _notesController.text.trim().isEmpty
              ? null
              : _notesController.text.trim(),
          nextFollowUpAt: _nextFollowUpAt,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text(widget.guest.fullName)),
      body: BlocListener<CallBloc, CallState>(
        listener: (context, state) {
          if (state is CallSubmittedSuccessState) {
            Navigator.of(context).pop();
          } else if (state is CallSubmittedFailureState) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.errorMessage),
                backgroundColor: AppColors.danger,
              ),
            );
          }
        },
        child: ListView(
          padding: EdgeInsets.all(AppSizes.p16),
          children: [
            if (!_dialerOpened)
              CustomButton(
                text: AppStrings.callGuestAction,
                onPressed: _openDialer,
              )
            else
              Container(
                padding: EdgeInsets.all(AppSizes.p12),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle, color: AppColors.success),
                    SizedBox(width: AppSizes.p8),
                    Text(
                      'Call opened - log the outcome below',
                      style: AppTextStyles.bodySmall,
                    ),
                  ],
                ),
              ),
            SizedBox(height: AppSizes.p24),
            Text('Outcome', style: AppTextStyles.titleLarge),
            SizedBox(height: AppSizes.p12),
            Wrap(
              spacing: AppSizes.p8,
              runSpacing: AppSizes.p8,
              children: _outcomes.entries.map((entry) {
                final selected = _outcome == entry.key;
                return ChoiceChip(
                  label: Text(entry.value),
                  selected: selected,
                  selectedColor: AppColors.primary,
                  labelStyle: AppTextStyles.labelMedium.copyWith(
                    color: selected
                        ? AppColors.textOnPrimary
                        : AppColors.textSecondary,
                  ),
                  onSelected: (_) => setState(() => _outcome = entry.key),
                );
              }).toList(),
            ),
            SizedBox(height: AppSizes.p24),
            Text('Duration', style: AppTextStyles.titleLarge),
            SizedBox(height: AppSizes.p12),
            DropdownButtonFormField<String>(
              initialValue: _durationBand,
              items: _durationBands.entries
                  .map(
                    (e) => DropdownMenuItem(value: e.key, child: Text(e.value)),
                  )
                  .toList(),
              onChanged: (value) =>
                  setState(() => _durationBand = value ?? _durationBand),
            ),
            SizedBox(height: AppSizes.p24),
            Text('Notes (optional)', style: AppTextStyles.titleLarge),
            SizedBox(height: AppSizes.p12),
            TextField(
              controller: _notesController,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'Add feedback notes...',
              ),
            ),
            SizedBox(height: AppSizes.p24),
            Row(
              children: [
                Expanded(
                  child: Text(
                    _nextFollowUpAt == null
                        ? AppStrings.scheduleFollowUp
                        : 'Follow-up: ${_nextFollowUpAt!.month}/${_nextFollowUpAt!.day}/${_nextFollowUpAt!.year}',
                    style: AppTextStyles.bodyMedium,
                  ),
                ),
                TextButton(
                  onPressed: _pickFollowUpDate,
                  child: const Text('Pick date'),
                ),
              ],
            ),
            SizedBox(height: AppSizes.p32),
            BlocBuilder<CallBloc, CallState>(
              builder: (context, state) {
                return CustomButton(
                  text: 'Save',
                  isLoading: state is CallSubmittingState,
                  onPressed: _outcome == null ? null : _submit,
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
