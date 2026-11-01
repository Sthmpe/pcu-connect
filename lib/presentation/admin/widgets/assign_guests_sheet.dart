import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/config/app_config.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_icons.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/utils/lagos_time.dart';
import '../../../core/widgets/app_controls.dart';
import '../../../core/widgets/app_feedback.dart';
import '../../../core/widgets/app_surfaces.dart';
import '../../../data/repositories/assign_repository.dart';

/// "Assigned 3 guests".
String assignedLine(int n) => n == 0 ? 'No guests were assigned' : 'Assigned $n ${n == 1 ? 'guest' : 'guests'}';

/// HOD: pick service dates, see how many guests have no worker, confirm,
/// assign them in turn among active workers (never admins).
Future<void> showAssignGuestsSheet(BuildContext context, IAssignRepository repo, {VoidCallback? onAssigned}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => AssignGuestsSheet(repo: repo, onAssigned: onAssigned),
  );
}

class AssignGuestsSheet extends StatefulWidget {
  final IAssignRepository repo;
  final VoidCallback? onAssigned;
  final String? today;

  const AssignGuestsSheet({super.key, required this.repo, this.onAssigned, this.today});

  @override
  State<AssignGuestsSheet> createState() => _AssignGuestsSheetState();
}

class _AssignGuestsSheetState extends State<AssignGuestsSheet> {
  late String _from = AppConfig.chaseFrom;
  late String _to = widget.today ?? LagosTime.today();
  AssignPreview? _preview;
  String? _error;
  bool _loading = true;
  bool _assigning = false;
  int _asked = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final ask = ++_asked;
    setState(() {
      _loading = true;
      _error = null;
    });
    final r = await widget.repo.preview(from: _from, to: _to);
    if (!mounted || ask != _asked) return;
    setState(() {
      _loading = false;
      _preview = r.data;
      _error = r.failure?.message;
    });
  }

  /// "Wed 28 Oct" (fits a phone row).
  static String _short(String day) => DateFormat('EEE d MMM').format(DateTime.parse(day));

  Future<void> _pick(bool from) async {
    final current = DateTime.parse(from ? _from : _to);
    final picked = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(2020),
      lastDate: DateTime.parse(widget.today ?? LagosTime.today()),
    );
    if (picked == null) return;
    final day = LagosTime.pickedDay(picked);
    setState(() {
      if (from) {
        _from = day;
        if (_from.compareTo(_to) > 0) _to = _from;
      } else {
        _to = day;
        if (_to.compareTo(_from) < 0) _from = _to;
      }
    });
    _load();
  }

  Future<void> _assign() async {
    final n = _preview?.unassigned ?? 0;
    if (n == 0 || _assigning) return;
    final ok = await AppFeedback.confirm(
      title: 'Assign $n ${n == 1 ? 'guest' : 'guests'}?',
      message: 'They are shared in turn among the ${_preview!.workers} active workers. Admins never receive guests.',
      confirmLabel: 'Assign',
    );
    if (!ok || !mounted) return;
    setState(() => _assigning = true);
    final r = await widget.repo.assign(from: _from, to: _to);
    if (!mounted) return;
    setState(() => _assigning = false);
    if (r.isSuccess) {
      AppFeedback.success(assignedLine(r.data!.assigned), r.data!.summary.isEmpty ? 'Every guest already has a worker.' : r.data!.summary);
      widget.onAssigned?.call();
      _load();
    } else {
      AppFeedback.error('Not assigned', r.failure!.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final n = _preview?.unassigned ?? 0;
    final line = _loading
        ? 'Counting...'
        : _error != null
            ? _error!
            : n == 0
                ? 'Every guest in these dates has a worker.'
                : '$n ${n == 1 ? 'guest has' : 'guests have'} no worker in these dates.';
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(AppSizes.gutter, 0, AppSizes.gutter, AppSizes.s24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Assign guests', style: AppTextStyles.title),
            SizedBox(height: AppSizes.s4),
            Text('By service date. Each guest goes to the next active worker.', style: AppTextStyles.bodyMuted),
            SizedBox(height: AppSizes.s16),
            GroupedCard(
              children: [
                InfoTile(
                  icon: AppIcons.calendar,
                  label: 'From',
                  value: _short(_from),
                  onTap: () => _pick(true),
                ),
                InfoTile(
                  icon: AppIcons.calendar,
                  label: 'To',
                  value: _short(_to),
                  onTap: () => _pick(false),
                ),
              ],
            ),
            SizedBox(height: AppSizes.s16),
            Text(line,
                style: AppTextStyles.body.copyWith(color: _error != null ? AppColors.redInk : AppColors.ink)),
            if (_error != null)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(onPressed: _load, child: Text('Try again', style: AppTextStyles.captionStrong)),
              ),
            SizedBox(height: AppSizes.s16),
            AppButton(
              label: n == 0 ? 'Assign guests' : 'Assign $n ${n == 1 ? 'guest' : 'guests'}',
              variant: AppButtonVariant.navy,
              isLoading: _assigning,
              onPressed: _loading || n == 0 ? null : _assign,
            ),
          ],
        ),
      ),
    );
  }
}

/// Dashboard: "4 guests are waiting for a worker", opening Assign guests.
class UnassignedCard extends StatefulWidget {
  final IAssignRepository repo;
  final String? today;

  const UnassignedCard({super.key, required this.repo, this.today});

  @override
  State<UnassignedCard> createState() => _UnassignedCardState();
}

class _UnassignedCardState extends State<UnassignedCard> {
  int _waiting = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final r = await widget.repo.preview(from: AppConfig.chaseFrom, to: widget.today ?? LagosTime.today());
    if (mounted) setState(() => _waiting = r.data?.unassigned ?? 0);
  }

  @override
  Widget build(BuildContext context) {
    if (_waiting == 0) return const SizedBox.shrink();
    return Padding(
      padding: EdgeInsets.only(bottom: AppSizes.s16),
      child: AppCard(
        onTap: () => showAssignGuestsSheet(context, widget.repo, onAssigned: _load),
        child: Row(
          children: [
            Icon(AppIcons.addPerson, size: AppSizes.iconMd, color: AppColors.inkSoft),
            SizedBox(width: AppSizes.s16),
            Expanded(
              child: Text(
                '$_waiting ${_waiting == 1 ? 'guest is' : 'guests are'} waiting for a worker',
                style: AppTextStyles.bodyStrong,
              ),
            ),
            Text('Assign', style: AppTextStyles.captionStrong.copyWith(color: AppColors.navy)),
            Icon(AppIcons.chevronRight, size: AppSizes.iconMd, color: AppColors.subtle),
          ],
        ),
      ),
    );
  }
}
