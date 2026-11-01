import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_sizes.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/utils/contact_launcher.dart';
import '../../core/widgets/app_controls.dart';
import '../../core/widgets/app_surfaces.dart';
import '../../data/firestore/message_templates_repository.dart';
import '../../domain/entities/guest_entity.dart';
import '../../domain/message_templates.dart';
import '../auth/bloc/auth_bloc.dart';
import '../auth/bloc/auth_state.dart';

/// WhatsApp with a choice of message: each template filled in for [guest],
/// or WhatsApp with nothing typed.
Future<void> showWhatsAppSheet(BuildContext context, GuestEntity guest) {
  final auth = context.read<AuthBloc>().state;
  final workerName = auth is AuthAuthenticatedState ? auth.user.name : '';
  final templates = context.read<IMessageTemplatesRepository>().watch();
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) => WhatsAppSheet(
      guest: guest,
      workerName: workerName,
      templates: templates,
      onSend: (text) {
        Navigator.pop(sheetContext);
        text == null ? ContactLauncher.whatsApp(guest) : ContactLauncher.whatsAppMessage(guest, text);
      },
    ),
  );
}

class WhatsAppSheet extends StatelessWidget {
  final GuestEntity guest;
  final String workerName;
  final Stream<List<MessageTemplate>> templates;

  /// The filled message, or null for WhatsApp with nothing typed.
  final ValueChanged<String?> onSend;

  const WhatsAppSheet({
    super.key,
    required this.guest,
    required this.workerName,
    required this.templates,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.85),
        child: StreamBuilder<List<MessageTemplate>>(
          stream: templates,
          initialData: MessageTemplates.defaultList,
          builder: (context, snap) {
            final list = snap.data ?? MessageTemplates.defaultList;
            return ListView(
              shrinkWrap: true,
              padding: EdgeInsets.fromLTRB(AppSizes.gutter, 0, AppSizes.gutter, AppSizes.s24),
              children: [
                Text('Send a WhatsApp message', style: AppTextStyles.title),
                SizedBox(height: AppSizes.s4),
                Text('To ${guest.name}', style: AppTextStyles.bodyMuted),
                SizedBox(height: AppSizes.s16),
                GroupedCard(
                  children: [
                    for (final t in list)
                      _TemplateOption(
                        label: t.label,
                        text: MessageTemplates.forGuest(t.text, guest, workerName: workerName),
                        onTap: () => onSend(MessageTemplates.forGuest(t.text, guest, workerName: workerName)),
                      ),
                  ],
                ),
                SizedBox(height: AppSizes.s16),
                AppButton(
                  label: 'Open WhatsApp without a message',
                  variant: AppButtonVariant.outline,
                  onPressed: () => onSend(null),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _TemplateOption extends StatelessWidget {
  final String label;
  final String text;
  final VoidCallback onTap;

  const _TemplateOption({required this.label, required this.text, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.all(AppSizes.s16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: AppTextStyles.bodyStrong),
              SizedBox(height: AppSizes.s4),
              Text(text, style: AppTextStyles.caption.copyWith(color: AppColors.inkSoft)),
            ],
          ),
        ),
      ),
    );
  }
}
