import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/utils/call_return_watcher.dart';
import '../../../core/widgets/app_controls.dart';
import '../../../domain/entities/guest_entity.dart';
import '../../guests/bloc/guests_bloc.dart';
import '../follow_up_saver.dart';
import '../screens/guest_detail_screen.dart';

/// "How did the call go?" for one guest: the four quick outcomes and Save,
/// or the full form.
class CallOutcomeSheet extends StatefulWidget {
  final GuestEntity guest;

  /// Saves [outcome]; true when saved.
  final Future<bool> Function(String outcome) onSave;

  /// Opens the full form, with the outcome picked so far.
  final ValueChanged<String?> onFullForm;

  const CallOutcomeSheet({super.key, required this.guest, required this.onSave, required this.onFullForm});

  @override
  State<CallOutcomeSheet> createState() => _CallOutcomeSheetState();
}

class _CallOutcomeSheetState extends State<CallOutcomeSheet> {
  String? _outcome;
  bool _saving = false;

  Future<void> _save() async {
    final outcome = _outcome;
    if (outcome == null || _saving) return;
    setState(() => _saving = true);
    final saved = await widget.onSave(outcome);
    if (!saved && mounted) setState(() => _saving = false);
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
            Text('How did the call go?', style: AppTextStyles.title),
            SizedBox(height: AppSizes.s4),
            Text('With ${widget.guest.name}', style: AppTextStyles.bodyMuted),
            SizedBox(height: AppSizes.s8),
            Wrap(
              spacing: AppSizes.s8,
              children: [
                for (final label in kQuickOutcomes)
                  QuickOutcomeChip(
                    label: label,
                    selected: _outcome == label,
                    onTap: _saving ? () {} : () => setState(() => _outcome = label),
                  ),
              ],
            ),
            SizedBox(height: AppSizes.s16),
            AppButton(
              label: 'Save',
              isLoading: _saving,
              onPressed: _outcome == null ? null : _save,
            ),
            SizedBox(height: AppSizes.s8),
            AppButton(
              label: 'Open the full form',
              variant: AppButtonVariant.outline,
              onPressed: _saving ? null : () => widget.onFullForm(_outcome),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shows [CallOutcomeSheet] and saves through [saveFollowUp], the same path
/// as the full form.
Future<void> showCallOutcomeSheet(BuildContext context, GuestEntity guest) {
  final navigator = Navigator.of(context);
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) => CallOutcomeSheet(
      guest: guest,
      onSave: (outcome) => saveFollowUp(
        context,
        guestId: guest.id,
        outcome: outcome,
        close: () {
          if (sheetContext.mounted) Navigator.pop(sheetContext);
        },
      ),
      onFullForm: (outcome) {
        Navigator.pop(sheetContext);
        navigator.pushNamed(AppRoutes.logFollowUp, arguments: LogFollowUpArgs(guest.id, initialOutcome: outcome));
      },
    ),
  );
}

/// Worker screens: asks "How did the call go?" when the worker comes back
/// from a call or WhatsApp started in the app (CallReturnWatcher).
class CallReturnPrompt extends StatefulWidget {
  final Widget child;
  final CallReturnWatcher? watcher;

  const CallReturnPrompt({super.key, required this.child, this.watcher});

  @override
  State<CallReturnPrompt> createState() => _CallReturnPromptState();
}

class _CallReturnPromptState extends State<CallReturnPrompt> {
  late final CallReturnWatcher _watcher = widget.watcher ?? CallReturnWatcher.instance;
  late final AppLifecycleListener _lifecycle;
  StreamSubscription<String>? _returns;
  bool _showing = false;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(onStateChange: _watcher.onLifecycle);
    _returns = _watcher.returns.listen(_ask);
  }

  Future<void> _ask(String guestId) async {
    if (!mounted || _showing) return;
    final guest = context.read<GuestsBloc>().state.find(guestId);
    if (guest == null) return;
    _showing = true;
    try {
      await showCallOutcomeSheet(context, guest);
    } finally {
      _showing = false;
    }
  }

  @override
  void dispose() {
    _returns?.cancel();
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
