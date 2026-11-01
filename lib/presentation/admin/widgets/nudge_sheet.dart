import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/utils/lagos_time.dart';
import '../../../core/widgets/app_controls.dart';
import '../../../core/widgets/app_feedback.dart';
import '../../../core/widgets/app_surfaces.dart';
import '../../../data/firestore/nudge_repository.dart';
import '../../../domain/attention_rules.dart';
import '../../../domain/nudge.dart';

/// "Nudged at 10:42. You can nudge again at 10:42 on Tuesday." (Lagos time).
String nudgedLine(DateTime at) {
  final lagos = at.toUtc().add(LagosTime.offset);
  final next = lagos.add(Nudge.every);
  return 'Nudged at ${DateFormat('HH:mm').format(lagos)}. '
      'You can nudge again at ${DateFormat('HH:mm').format(next)} on ${DateFormat('EEEE').format(next)}.';
}

/// Preview, one optional personal line, and Send.
Future<void> showNudgeSheet(BuildContext context, WorkerAttention worker, INudgeRepository repo) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(sheetContext).bottom),
      child: NudgeSheet(worker: worker, repo: repo, onSent: () => Navigator.pop(sheetContext)),
    ),
  );
}

class NudgeSheet extends StatefulWidget {
  final WorkerAttention worker;
  final INudgeRepository repo;
  final VoidCallback onSent;

  const NudgeSheet({super.key, required this.worker, required this.repo, required this.onSent});

  @override
  State<NudgeSheet> createState() => _NudgeSheetState();
}

class _NudgeSheetState extends State<NudgeSheet> {
  final _line = TextEditingController();
  bool _sending = false;

  String get _first => widget.worker.workerName.trim().split(RegExp(r'\s+')).first;

  @override
  void dispose() {
    _line.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    setState(() => _sending = true);
    final result = await widget.repo.send(
      workerEmail: widget.worker.workerEmail,
      outstanding: widget.worker.outstanding,
      personalLine: _line.text,
    );
    if (!mounted) return;
    setState(() => _sending = false);
    if (result.isSuccess) {
      widget.onSent();
      AppFeedback.success('Nudge sent', result.data!.summary(_first));
    } else {
      AppFeedback.error('Not sent', result.failure?.message ?? 'Please try again.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(AppSizes.gutter, 0, AppSizes.gutter, AppSizes.s24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Nudge $_first', style: AppTextStyles.title),
            SizedBox(height: AppSizes.s4),
            Text('In the app, on their phone if it is set up, and by email.', style: AppTextStyles.bodyMuted),
            SizedBox(height: AppSizes.s16),
            AppCard(
              color: AppColors.sunken,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(Nudge.title, style: AppTextStyles.bodyStrong),
                  SizedBox(height: AppSizes.s4),
                  Text(Nudge.body(widget.worker.outstanding), style: AppTextStyles.body),
                ],
              ),
            ),
            SizedBox(height: AppSizes.s16),
            TextField(
              controller: _line,
              maxLength: Nudge.maxLine,
              maxLines: 1,
              style: AppTextStyles.body,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(hintText: 'Add a personal line (optional)'),
            ),
            SizedBox(height: AppSizes.s8),
            AppButton(
              label: 'Send nudge',
              variant: AppButtonVariant.navy,
              isLoading: _sending,
              onPressed: widget.worker.workerEmail.isEmpty ? null : _send,
            ),
          ],
        ),
      ),
    );
  }
}
