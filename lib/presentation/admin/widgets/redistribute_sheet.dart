import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_icons.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/utils/lagos_time.dart';
import '../../../core/widgets/app_controls.dart';
import '../../../core/widgets/app_feedback.dart';
import '../../../core/widgets/app_surfaces.dart';
import '../../../data/repositories/redistribute_repository.dart';

const _modeLabels = {
  RedistributeMode.outstanding: 'Outstanding',
  RedistributeMode.uncalled: 'All uncalled',
  RedistributeMode.selected: 'Selected',
};

/// "Moved 12 guests".
String movedLine(int n) => n == 0 ? 'No guests were moved' : 'Moved $n ${n == 1 ? 'guest' : 'guests'}';

/// HOD: move a worker's waiting guests to other active workers.
Future<void> showRedistributeSheet(
  BuildContext context, {
  required IRedistributeRepository repo,
  required String workerEmail,
  required String workerName,
  RedistributeMode mode = RedistributeMode.outstanding,
  VoidCallback? onMoved,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) => RedistributeSheet(
      repo: repo,
      workerEmail: workerEmail,
      workerName: workerName,
      initialMode: mode,
      onMoved: () {
        Navigator.pop(sheetContext);
        onMoved?.call();
      },
    ),
  );
}

class RedistributeSheet extends StatefulWidget {
  final IRedistributeRepository repo;
  final String workerEmail;
  final String workerName;
  final RedistributeMode initialMode;
  final VoidCallback onMoved;

  const RedistributeSheet({
    super.key,
    required this.repo,
    required this.workerEmail,
    required this.workerName,
    this.initialMode = RedistributeMode.outstanding,
    required this.onMoved,
  });

  @override
  State<RedistributeSheet> createState() => _RedistributeSheetState();
}

class _RedistributeSheetState extends State<RedistributeSheet> {
  late RedistributeMode _mode = widget.initialMode;
  final Set<String> _guestIds = {};

  /// Every possible recipient (from the first preview) and the ones chosen.
  List<RedistributeShare> _everyone = const [];
  Set<String>? _to;

  /// Guests never called, for "Selected".
  List<RedistributeCandidate> _uncalled = const [];

  RedistributePlan? _plan;
  String? _error;
  bool _loading = true;
  bool _moving = false;
  int _asked = 0;

  String get _first => widget.workerName.replaceFirst(RegExp(r'^TEST\s+'), '').split(RegExp(r'\s+')).first;

  List<String>? get _toEmails => _to == null || _to!.length == _everyone.length ? null : _to!.toList();

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    final all = await widget.repo.preview(fromEmail: widget.workerEmail, mode: RedistributeMode.uncalled);
    if (!mounted) return;
    if (all.isSuccess) {
      _everyone = all.data!.shares;
      _uncalled = all.data!.candidates;
      _to = {for (final s in _everyone) s.email};
    }
    _load();
  }

  Future<void> _load() async {
    final ask = ++_asked;
    setState(() {
      _loading = true;
      _error = null;
    });
    final r = await widget.repo.preview(
      fromEmail: widget.workerEmail,
      mode: _mode,
      guestIds: _guestIds.toList(),
      toEmails: _toEmails,
    );
    if (!mounted || ask != _asked) return;
    setState(() {
      _loading = false;
      _plan = r.data;
      _error = r.failure?.message;
    });
  }

  Future<void> _move() async {
    final plan = _plan;
    if (plan == null || plan.guests == 0 || _moving) return;
    final ok = await AppFeedback.confirm(
      title: 'Move ${plan.guests} ${plan.guests == 1 ? 'guest' : 'guests'}?',
      message: '${plan.text}. $_first and the new workers are told. Calls already made and points stay where they are.',
      confirmLabel: 'Move',
    );
    if (!ok || !mounted) return;
    setState(() => _moving = true);
    final r = await widget.repo.run(
      fromEmail: widget.workerEmail,
      mode: _mode,
      guestIds: _guestIds.toList(),
      toEmails: _toEmails,
    );
    if (!mounted) return;
    setState(() => _moving = false);
    if (r.isSuccess) {
      AppFeedback.success(movedLine(r.data!.moved), r.data!.moved == 0 ? 'Nothing was left to move.' : r.data!.text);
      widget.onMoved();
    } else {
      AppFeedback.error('Not moved', r.failure!.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final n = _plan?.guests ?? 0;
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.88),
        child: ListView(
          shrinkWrap: true,
          padding: EdgeInsets.fromLTRB(AppSizes.gutter, 0, AppSizes.gutter, AppSizes.s24),
          children: [
            Text("Redistribute $_first's guests", style: AppTextStyles.title),
            SizedBox(height: AppSizes.s4),
            Text('Only guests never called move. Active workers only, never admins.', style: AppTextStyles.bodyMuted),
            SizedBox(height: AppSizes.s16),
            SegmentedPicker(
              options: _modeLabels.values.toList(),
              value: _modeLabels[_mode]!,
              onChanged: (label) {
                setState(() => _mode = _modeLabels.entries.firstWhere((e) => e.value == label).key);
                _load();
              },
            ),
            if (_mode == RedistributeMode.selected) ...[
              SectionLabel('Guests never called'),
              if (_uncalled.isEmpty)
                Text('$_first has no guests waiting for a first call.', style: AppTextStyles.bodyMuted)
              else
                GroupedCard(
                  children: [
                    for (final c in _uncalled)
                      _CheckRow(
                        title: c.name,
                        subtitle: c.serviceDate.isEmpty ? null : 'Visited ${LagosTime.fullDate(c.serviceDate)}',
                        checked: _guestIds.contains(c.id),
                        onTap: () {
                          setState(() => _guestIds.contains(c.id) ? _guestIds.remove(c.id) : _guestIds.add(c.id));
                          _load();
                        },
                      ),
                  ],
                ),
            ],
            if (_everyone.isNotEmpty) ...[
              SectionLabel('Give to'),
              GroupedCard(
                children: [
                  for (final w in _everyone)
                    _CheckRow(
                      title: w.name,
                      checked: _to?.contains(w.email) ?? true,
                      onTap: () {
                        final to = {...?_to};
                        to.contains(w.email) ? to.remove(w.email) : to.add(w.email);
                        if (to.isEmpty) return;
                        setState(() => _to = to);
                        _load();
                      },
                    ),
                ],
              ),
              SizedBox(height: AppSizes.s4),
              Text('Spread evenly, oldest visit first.', style: AppTextStyles.caption),
            ],
            SizedBox(height: AppSizes.s16),
            AppCard(
              color: AppColors.sunken,
              child: Text(
                _loading ? 'Working it out...' : _error ?? _plan?.text ?? '',
                style: AppTextStyles.bodyStrong.copyWith(color: _error != null ? AppColors.redInk : AppColors.ink),
              ),
            ),
            SizedBox(height: AppSizes.s16),
            AppButton(
              label: n == 0 ? 'Redistribute' : 'Redistribute $n ${n == 1 ? 'guest' : 'guests'}',
              variant: AppButtonVariant.navy,
              isLoading: _moving,
              onPressed: _loading || n == 0 ? null : _move,
            ),
          ],
        ),
      ),
    );
  }
}

class _CheckRow extends StatelessWidget {
  final String title;
  final String? subtitle;
  final bool checked;
  final VoidCallback onTap;

  const _CheckRow({required this.title, this.subtitle, required this.checked, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      checked: checked,
      button: true,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: AppSizes.s16, vertical: AppSizes.s8 + 4),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: AppTextStyles.body),
                    if (subtitle != null) Text(subtitle!, style: AppTextStyles.caption),
                  ],
                ),
              ),
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: checked ? AppColors.gold : Colors.transparent,
                  shape: BoxShape.circle,
                  border: Border.all(color: checked ? AppColors.gold : AppColors.lineStrong, width: 1.5),
                ),
                child: checked ? const Icon(AppIcons.check, size: 14, color: AppColors.navy) : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
