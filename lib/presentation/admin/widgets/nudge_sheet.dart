import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_icons.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/utils/contact_launcher.dart';
import '../../../core/utils/lagos_time.dart';
import '../../../core/utils/phone_intl.dart';
import '../../../core/widgets/app_controls.dart';
import '../../../core/widgets/app_feedback.dart';
import '../../../core/widgets/app_surfaces.dart';
import '../../../data/firestore/message_templates_repository.dart';
import '../../../data/firestore/nudge_repository.dart';
import '../../../domain/attention_rules.dart';
import '../../../domain/message_templates.dart';
import '../../../domain/nudge.dart';
import '../../common/insights_cubits.dart';
import '../../common/notifications_screen.dart';

/// "Nudged at 10:42. You can nudge again at 10:42 on Tuesday." (Lagos time).
String nudgedLine(DateTime at) {
  final lagos = at.toUtc().add(LagosTime.offset);
  final next = lagos.add(Nudge.every);
  return 'Nudged at ${DateFormat('HH:mm').format(lagos)}. '
      'You can nudge again at ${DateFormat('HH:mm').format(next)} on ${DateFormat('EEEE').format(next)}.';
}

/// "Last nudged 2 h ago on WhatsApp".
String lastNudgedLine(NudgeLog log, [DateTime? clock]) =>
    'Last nudged ${timeAgo(log.at, clock).toLowerCase()} ${log.isWhatsApp ? 'on WhatsApp' : 'in the app'}';

/// The worker's phone from the team (the Workers tab); '' when not known.
String phoneFor(BuildContext context, String email) {
  for (final m in context.read<TeamCubit>().state.data ?? const []) {
    if (m.email.trim().toLowerCase() == email) return m.phone;
  }
  return '';
}

/// Opens WhatsApp to [worker] with the nudge message filled in, and logs it.
/// False (with a plain message) when there is no phone saved.
Future<bool> nudgeOnWhatsApp({
  required WorkerAttention worker,
  required String phone,
  required String template,
  required INudgeRepository repo,
}) async {
  final international = nigerianInternational(phone);
  final first = worker.workerName.trim().replaceFirst(RegExp(r'^TEST\s+'), '').split(RegExp(r'\s+')).first;
  if (international == null) {
    AppFeedback.error('No phone saved', 'Add a phone number for $first in the Workers tab.');
    return false;
  }
  await ContactLauncher.whatsAppTo(
    international,
    MessageTemplates.fillNudge(template, workerName: worker.workerName, waiting: worker.outstanding, oldestDays: worker.oldestDays),
  );
  await repo.logWhatsApp(workerEmail: worker.workerEmail, workerName: worker.workerName, outstanding: worker.outstanding);
  return true;
}

/// The friendly nudge and Nudge on WhatsApp for one worker.
Future<void> showNudgeSheet(
  BuildContext context,
  WorkerAttention worker,
  INudgeRepository repo, {
  required String phone,
  IMessageTemplatesRepository? templates,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(sheetContext).bottom),
      child: NudgeSheet(
        worker: worker,
        repo: repo,
        phone: phone,
        templates: templates?.watch() ?? Stream.value(MessageTemplates.defaultList),
        onSent: () => Navigator.pop(sheetContext),
      ),
    ),
  );
}

class NudgeSheet extends StatefulWidget {
  final WorkerAttention worker;
  final INudgeRepository repo;
  final VoidCallback onSent;

  /// The worker's phone from the Workers tab ('' when none).
  final String phone;
  final Stream<List<MessageTemplate>> templates;
  final DateTime Function()? clock;

  const NudgeSheet({
    super.key,
    required this.worker,
    required this.repo,
    required this.onSent,
    this.phone = '',
    this.templates = const Stream.empty(),
    this.clock,
  });

  @override
  State<NudgeSheet> createState() => _NudgeSheetState();
}

class _NudgeSheetState extends State<NudgeSheet> {
  final _line = TextEditingController();
  late final Stream<NudgeHistory> _history = widget.repo.history();
  String _nudgeText = MessageTemplates.defaults[MessageTemplates.nudgeId]!;
  bool _sending = false;

  String get _first => widget.worker.workerName.trim().replaceFirst(RegExp(r'^TEST\s+'), '').split(RegExp(r'\s+')).first;

  @override
  void initState() {
    super.initState();
    widget.templates.listen((list) {
      if (mounted) setState(() => _nudgeText = MessageTemplates.nudgeText(list));
    });
  }

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

  Future<void> _whatsApp() async {
    if (await nudgeOnWhatsApp(worker: widget.worker, phone: widget.phone, template: _nudgeText, repo: widget.repo)) {
      widget.onSent();
    }
  }

  @override
  Widget build(BuildContext context) {
    final international = nigerianInternational(widget.phone);
    return SafeArea(
      child: StreamBuilder<NudgeHistory>(
        stream: _history,
        initialData: NudgeHistory.empty,
        builder: (context, snap) {
          final history = snap.data ?? NudgeHistory.empty;
          final now = widget.clock?.call() ?? DateTime.now();
          final last = history.last(widget.worker.workerEmail);
          final friendlyAt = history.friendlyWithin24h(widget.worker.workerEmail, now);
          return ListView(
            shrinkWrap: true,
            padding: EdgeInsets.fromLTRB(AppSizes.gutter, 0, AppSizes.gutter, AppSizes.s24),
            children: [
              Text('Nudge $_first', style: AppTextStyles.title),
              SizedBox(height: AppSizes.s4),
              Text(widget.worker.line, style: AppTextStyles.bodyMuted),
              if (last != null) ...[
                SizedBox(height: AppSizes.s4),
                Text(lastNudgedLine(last, now), style: AppTextStyles.caption),
              ],
              SectionLabel('In the app, on their phone and by email'),
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
              if (friendlyAt != null) ...[
                SizedBox(height: AppSizes.s8),
                Text(nudgedLine(friendlyAt), style: AppTextStyles.caption),
              ] else ...[
                SizedBox(height: AppSizes.s16),
                TextField(
                  controller: _line,
                  maxLength: Nudge.maxLine,
                  maxLines: 1,
                  style: AppTextStyles.body,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(hintText: 'Add a personal line (optional)'),
                ),
              ],
              SizedBox(height: AppSizes.s8),
              AppButton(
                label: 'Send nudge',
                variant: AppButtonVariant.navy,
                isLoading: _sending,
                onPressed: widget.worker.workerEmail.isEmpty || friendlyAt != null ? null : _send,
              ),
              SectionLabel('On WhatsApp'),
              if (international == null)
                Text('No phone saved for $_first. Add one in the Workers tab.', style: AppTextStyles.bodyMuted)
              else
                Text(
                  MessageTemplates.fillNudge(_nudgeText,
                      workerName: widget.worker.workerName,
                      waiting: widget.worker.outstanding,
                      oldestDays: widget.worker.oldestDays),
                  style: AppTextStyles.caption.copyWith(color: AppColors.inkSoft),
                ),
              SizedBox(height: AppSizes.s8),
              AppButton(
                label: 'Nudge on WhatsApp',
                icon: AppIcons.whatsapp,
                variant: AppButtonVariant.outline,
                onPressed: international == null || widget.worker.workerEmail.isEmpty ? null : _whatsApp,
              ),
            ],
          );
        },
      ),
    );
  }
}
