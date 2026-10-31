import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_icons.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/widgets/app_controls.dart';
import '../../../core/widgets/app_feedback.dart';
import '../../../core/widgets/app_page.dart';
import '../../../core/widgets/app_surfaces.dart';
import '../../../core/widgets/status_tone.dart';
import '../../../domain/entities/guest_entity.dart';
import '../../../domain/repositories/i_guest_repository.dart';
import '../../auth/bloc/auth_bloc.dart';
import '../../auth/bloc/auth_state.dart';
import '../../common/insights_cubits.dart';
import '../../guests/bloc/guests_bloc.dart';
import '../../guests/bloc/guests_event.dart';
import '../../guests/bloc/guests_state.dart';
import 'guest_detail_screen.dart';

class LogFollowUpScreen extends StatefulWidget {
  final String guestId;
  final String? initialOutcome;

  const LogFollowUpScreen({super.key, required this.guestId, this.initialOutcome});

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

  GuestEntity? get _guest {
    final state = context.read<GuestsBloc>().state;
    if (state is GuestsLoadedState) {
      for (final g in state.allGuests) {
        if (g.id == widget.guestId) return g;
      }
    }
    return null;
  }

  String? get _guestName => _guest?.name;

  /// First name of the worker who gets the credit when an admin logs it.
  String? get _creditedTo {
    final auth = context.read<AuthBloc>().state;
    final isAdmin = auth is AuthAuthenticatedState && auth.user.isAdmin;
    final assignee = (_guest?.assignedWorkerName ?? '').trim();
    return isAdmin && assignee.isNotEmpty ? firstNameOf(assignee) : null;
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
    final guestName = _guestName ?? 'this guest';
    final creditedTo = _creditedTo;
    final ranking = context.read<RankingCubit>();
    final dashboard = context.read<DashboardCubit>();
    final team = context.read<TeamCubit>();

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
      if (ranking.state.data != null) ranking.load();
      if (dashboard.state.data != null) dashboard.load();
      if (team.state.data != null) team.load();
      Navigator.pop(context);
      AppFeedback.pointsEarned(
          points: points, guestName: guestName, creditedTo: creditedTo);
    } else {
      AppFeedback.error('Not saved', result.failure?.message ?? 'Please try again.');
    }
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final name = _guestName;
    final creditedTo = _creditedTo;
    return Scaffold(
      body: Column(
        children: [
          const AppTopBar(title: 'Log follow-up'),
          Expanded(
            child: PageList(
              children: [
                if (name != null)
                  Padding(
                    padding: EdgeInsets.zero,
                    child: Text(
                      creditedTo == null
                          ? 'For $name'
                          : 'For $name. It counts for $creditedTo.',
                      style: AppTextStyles.bodyMuted,
                    ),
                  ),
                SectionLabel('What happened?'),
                GroupedCard(
                  dividerIndent: AppSizes.s16 * 2 + AppSizes.iconMd,
                  children: [
                    for (final (label, icon) in kFollowUpOutcomes)
                      _OutcomeOption(
                        label: label,
                        icon: icon,
                        selected: _selectedOutcome == label,
                        onTap: () => setState(() => _selectedOutcome = label),
                      ),
                  ],
                ),
                SectionLabel('Notes'),
                TextField(
                  controller: _noteController,
                  minLines: 3,
                  maxLines: 5,
                  style: AppTextStyles.body,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    hintText: 'What did they share? Any prayer requests?',
                  ),
                ),
                SectionLabel('Did they come to church?'),
                GroupedCard(
                  children: [
                    AppSwitchRow(
                      title: 'Sunday service',
                      value: _cameSunday,
                      onChanged: (v) => setState(() => _cameSunday = v),
                      extra: _cameSunday
                          ? _DateChip(date: _sundayDate, onTap: () => _pickDate(true))
                          : null,
                    ),
                    AppSwitchRow(
                      title: 'Wednesday service',
                      value: _cameWednesday,
                      onChanged: (v) => setState(() => _cameWednesday = v),
                      extra: _cameWednesday
                          ? _DateChip(date: _wednesdayDate, onTap: () => _pickDate(false))
                          : null,
                    ),
                  ],
                ),
                SectionLabel('Joined a team?'),
                SegmentedPicker(
                  options: _teams,
                  value: _selectedTeam,
                  onChanged: (t) => setState(() => _selectedTeam = t),
                ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(AppSizes.gutter, AppSizes.s8, AppSizes.gutter,
                AppSizes.s16 + MediaQuery.paddingOf(context).bottom),
            child: AppButton(
              label: 'Save follow-up',
              isLoading: _isSubmitting,
              onPressed: _submit,
            ),
          ),
        ],
      ),
    );
  }
}

class _OutcomeOption extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _OutcomeOption({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      button: true,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: AppSizes.touch + AppSizes.s8,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: AppSizes.s16),
            child: Row(
              children: [
                Icon(icon, size: AppSizes.iconMd, color: AppColors.inkSoft),
                SizedBox(width: AppSizes.s16),
                Expanded(child: Text(label, style: AppTextStyles.body)),
                AnimatedContainer(
                  duration: AppDurations.fast,
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: selected ? AppColors.gold : Colors.transparent,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: selected ? AppColors.gold : AppColors.lineStrong,
                      width: 1.5,
                    ),
                  ),
                  child: selected
                      ? const Icon(AppIcons.check, size: 14, color: AppColors.navy)
                      : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DateChip extends StatelessWidget {
  final DateTime date;
  final VoidCallback onTap;

  const _DateChip({required this.date, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        height: AppSizes.touch,
        child: Center(
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: AppSizes.s8 + 2, vertical: AppSizes.s4 + 2),
            decoration: BoxDecoration(
              color: AppColors.sunken,
              borderRadius: BorderRadius.circular(AppSizes.radiusFull),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(AppIcons.calendar, size: AppSizes.iconSm, color: AppColors.inkSoft),
                SizedBox(width: AppSizes.s4),
                Text(DateFormat('EEE d MMM').format(date),
                    style: AppTextStyles.centered(AppTextStyles.caption)
                        .copyWith(color: AppColors.ink)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
