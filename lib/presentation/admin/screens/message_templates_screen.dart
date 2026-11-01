import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/widgets/app_controls.dart';
import '../../../core/widgets/app_feedback.dart';
import '../../../core/widgets/app_page.dart';
import '../../../core/widgets/app_surfaces.dart';
import '../../../data/firestore/message_templates_repository.dart';
import '../../../domain/message_templates.dart';

/// HOD only: the wording of the WhatsApp messages workers can send.
class MessageTemplatesScreen extends StatefulWidget {
  const MessageTemplatesScreen({super.key});

  @override
  State<MessageTemplatesScreen> createState() => _MessageTemplatesScreenState();
}

class _MessageTemplatesScreenState extends State<MessageTemplatesScreen> {
  final Map<String, TextEditingController> _controllers = {
    for (final id in MessageTemplates.allIds) id: TextEditingController(text: MessageTemplates.defaults[id]),
  };
  StreamSubscription<List<MessageTemplate>>? _sub;
  bool _edited = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    // Show the saved wording; never overwrite what the HOD is typing.
    _sub = context.read<IMessageTemplatesRepository>().watch().listen((list) {
      if (_edited || !mounted) return;
      setState(() {
        for (final t in list) {
          _controllers[t.id]?.text = t.text;
        }
      });
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final result = await context
        .read<IMessageTemplatesRepository>()
        .save({for (final e in _controllers.entries) e.key: e.value.text});
    if (!mounted) return;
    setState(() => _saving = false);
    if (result.isSuccess) {
      _edited = false;
      AppFeedback.success('Messages saved', 'Workers see the new wording straight away.');
    } else {
      AppFeedback.error('Not saved', result.failure?.message ?? 'Please try again.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          const AppTopBar(title: 'WhatsApp messages'),
          Expanded(
            child: PageList(
              children: [
                Text(
                  'Workers pick one of these when they tap WhatsApp. {title} becomes sis or bro '
                  '(left out when the gender is not known), {name} the guest\'s first name, {worker} '
                  'the worker\'s name, and {service} the day of their first visit, for example Sunday 25 October.',
                  style: AppTextStyles.bodyMuted,
                ),
                for (final id in MessageTemplates.allIds) ...[
                  SectionLabel(MessageTemplates.labels[id]!),
                  if (id == MessageTemplates.nudgeId)
                    Padding(
                      padding: EdgeInsets.only(bottom: AppSizes.s8),
                      child: Text(
                        'Sent by the HOD on WhatsApp. {worker} becomes the worker\'s first name, {n} the guests waiting '
                        'and {oldest} the longest wait, for example 9 days.',
                        style: AppTextStyles.caption,
                      ),
                    ),
                  TextField(
                    controller: _controllers[id],
                    minLines: 4,
                    maxLines: 10,
                    maxLength: MessageTemplates.maxLength,
                    style: AppTextStyles.body,
                    textCapitalization: TextCapitalization.sentences,
                    onChanged: (_) => _edited = true,
                  ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      onPressed: () => setState(() {
                        _edited = true;
                        _controllers[id]!.text = MessageTemplates.defaults[id]!;
                      }),
                      child: Text('Use the default wording',
                          style: AppTextStyles.captionStrong.copyWith(color: AppColors.navy)),
                    ),
                  ),
                ],
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
                AppSizes.gutter, AppSizes.s8, AppSizes.gutter, AppSizes.s16 + MediaQuery.paddingOf(context).bottom),
            child: AppButton(label: 'Save messages', isLoading: _saving, onPressed: _save),
          ),
        ],
      ),
    );
  }
}
