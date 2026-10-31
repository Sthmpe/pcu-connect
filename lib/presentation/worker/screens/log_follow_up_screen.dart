import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_feedback.dart';
import '../../../core/widgets/app_header.dart';
import '../../../core/widgets/custom_button.dart';
import '../../../core/widgets/filter_chip_widget.dart';
import '../../../domain/repositories/i_guest_repository.dart';
import '../../guests/bloc/guests_bloc.dart';
import '../../guests/bloc/guests_event.dart';
import '../../guests/bloc/guests_state.dart';
import 'guest_detail_screen.dart';

class LogFollowUpScreen extends StatefulWidget {
  final String guestId;
  final String? initialOutcome;

  const LogFollowUpScreen({
    super.key,
    required this.guestId,
    this.initialOutcome,
  });

  @override
  State<LogFollowUpScreen> createState() => _LogFollowUpScreenState();
}

class _LogFollowUpScreenState extends State<LogFollowUpScreen> {
  late String _selectedOutcome = widget.initialOutcome ?? 'Reached';
  final TextEditingController _noteController = TextEditingController();

  bool _cameSunday = false;
  DateTime _sundayDate = DateTime.now();

  bool _cameWednesday = false;
  DateTime _wednesdayDate = DateTime.now();

  String _selectedTeam = 'Not yet'; // 'Not yet' | 'Workforce' | 'Evangelism'
  bool _isSubmitting = false;

  static const List<String> _teams = ['Not yet', 'Workforce', 'Evangelism'];

  String get _guestName {
    final state = context.read<GuestsBloc>().state;
    if (state is GuestsLoadedState) {
      for (final g in state.allGuests) {
        if (g.id == widget.guestId) return g.name;
      }
    }
    return 'this guest';
  }

  Future<void> _pickDate(bool isSunday) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isSunday ? _sundayDate : _wednesdayDate,
      firstDate: DateTime(2026, 1, 1),
      lastDate: DateTime.now(), // Enforce: No future dates allowed!
    );

    if (picked != null) {
      setState(() {
        if (isSunday) {
          _sundayDate = picked;
        } else {
          _wednesdayDate = picked;
        }
      });
    }
  }

  Future<void> _submit() async {
    setState(() => _isSubmitting = true);
    final guestName = _guestName;

    final guestRepo = context.read<IGuestRepository>();
    final result = await guestRepo.logFollowUp(
      guestId: widget.guestId,
      outcome: _selectedOutcome,
      note: _noteController.text.trim(),
      attendedSunday: _cameSunday,
      sundayDate: _cameSunday ? _sundayDate : null,
      attendedWednesday: _cameWednesday,
      wednesdayDate: _cameWednesday ? _wednesdayDate : null,
      team: _selectedTeam == 'Not yet' ? '' : _selectedTeam,
    );

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (result.isSuccess) {
      final points = (result.data?['pointsEarned'] as num?)?.toInt() ?? 0;
      context.read<GuestsBloc>().add(const LoadGuestsEvent());
      Navigator.pop(context);
      AppFeedback.pointsEarned(points: points, guestName: guestName);
    } else {
      AppFeedback.error(
        'Could not save',
        result.failure?.message ?? 'Please try again.',
      );
    }
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Column(
        children: [
          AppHeader(
            title: 'Log follow-up',
            subtitle: _guestName == 'this guest' ? null : _guestName,
            onBack: () => Navigator.pop(context),
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.fromLTRB(
                  AppSizes.gutter, AppSizes.p16, AppSizes.gutter, AppSizes.p24),
              children: [
                const _FieldLabel('Outcome'),
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: AppSizes.p8,
                  crossAxisSpacing: AppSizes.p8,
                  childAspectRatio: 3.2,
                  children: [
                    for (final (label, icon, tone) in kFollowUpOutcomes)
                      _OutcomeOption(
                        label: label,
                        icon: icon,
                        accent: tone.accent,
                        selected: _selectedOutcome == label,
                        onTap: () => setState(() => _selectedOutcome = label),
                      ),
                  ],
                ),
                SizedBox(height: AppSizes.p20),
                const _FieldLabel('Notes'),
                TextField(
                  controller: _noteController,
                  maxLines: 3,
                  minLines: 3,
                  style: AppTextStyles.input,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    hintText: 'What did they say? Prayer requests, best time to call...',
                  ),
                ),
                SizedBox(height: AppSizes.p20),
                const _FieldLabel('Attendance'),
                AppCard(
                  padding: EdgeInsets.symmetric(
                      horizontal: AppSizes.p12, vertical: AppSizes.p4),
                  child: Column(
                    children: [
                      _AttendanceToggle(
                        title: 'Came on Sunday',
                        value: _cameSunday,
                        date: _sundayDate,
                        onChanged: (v) => setState(() => _cameSunday = v),
                        onPickDate: () => _pickDate(true),
                      ),
                      const Divider(),
                      _AttendanceToggle(
                        title: 'Came on Wednesday',
                        value: _cameWednesday,
                        date: _wednesdayDate,
                        onChanged: (v) => setState(() => _cameWednesday = v),
                        onPickDate: () => _pickDate(false),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: AppSizes.p20),
                const _FieldLabel('Joined a team?'),
                SegmentedPicker(
                  options: _teams,
                  value: _selectedTeam,
                  onChanged: (t) => setState(() => _selectedTeam = t),
                ),
              ],
            ),
          ),
          BottomActionBar(
            child: AppButton(
              label: 'Save follow-up',
              icon: Icons.check_rounded,
              variant: AppButtonVariant.accent,
              isLoading: _isSubmitting,
              onPressed: _submit,
            ),
          ),
        ],
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String text;

  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: AppSizes.p8),
      child: Text(text, style: AppTextStyles.label),
    );
  }
}

class _OutcomeOption extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color accent;
  final bool selected;
  final VoidCallback onTap;

  const _OutcomeOption({
    required this.label,
    required this.icon,
    required this.accent,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppSizes.radiusMd);
    return Semantics(
      selected: selected,
      button: true,
      child: AnimatedContainer(
        duration: AppDurations.fast,
        decoration: BoxDecoration(
          color: selected ? AppColors.navy : AppColors.surface,
          borderRadius: radius,
          border: Border.all(
            color: selected ? AppColors.navy : AppColors.lineStrong,
          ),
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: onTap,
            borderRadius: radius,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: AppSizes.p12),
              child: Row(
                children: [
                  Icon(icon,
                      size: AppSizes.iconSm,
                      color: selected ? AppColors.gold : accent),
                  SizedBox(width: AppSizes.p8),
                  Flexible(
                    child: Text(
                      label,
                      style: AppTextStyles.secondaryStrong.copyWith(
                        color: selected ? AppColors.onNavy : AppColors.ink,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AttendanceToggle extends StatelessWidget {
  final String title;
  final bool value;
  final DateTime date;
  final ValueChanged<bool> onChanged;
  final VoidCallback onPickDate;

  const _AttendanceToggle({
    required this.title,
    required this.value,
    required this.date,
    required this.onChanged,
    required this.onPickDate,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: AppSizes.p4),
      child: Row(
        children: [
          Expanded(child: Text(title, style: AppTextStyles.bodyStrong)),
          AnimatedSwitcher(
            duration: AppDurations.fast,
            child: value
                ? InkWell(
                    key: const ValueKey('date'),
                    onTap: onPickDate,
                    borderRadius: BorderRadius.circular(AppSizes.radiusFull),
                    child: Container(
                      padding: EdgeInsets.symmetric(
                          horizontal: AppSizes.p10, vertical: AppSizes.p6),
                      decoration: BoxDecoration(
                        color: AppColors.navySoft,
                        borderRadius: BorderRadius.circular(AppSizes.radiusFull),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.event_rounded,
                              size: AppSizes.iconXs, color: AppColors.navy),
                          SizedBox(width: AppSizes.p4),
                          Text(
                            DateFormat('EEE d MMM').format(date),
                            style: AppTextStyles.captionStrong
                                .copyWith(color: AppColors.navy),
                          ),
                        ],
                      ),
                    ),
                  )
                : const SizedBox.shrink(key: ValueKey('none')),
          ),
          SizedBox(width: AppSizes.p4),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}
