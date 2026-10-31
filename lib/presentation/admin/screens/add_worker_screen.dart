import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/widgets/app_controls.dart';
import '../../../core/widgets/app_feedback.dart';
import '../../../core/widgets/app_page.dart';
import '../../../core/widgets/app_surfaces.dart';
import '../../common/insights_cubits.dart';

class AddWorkerScreen extends StatefulWidget {
  const AddWorkerScreen({super.key});

  @override
  State<AddWorkerScreen> createState() => _AddWorkerScreenState();
}

class _AddWorkerScreenState extends State<AddWorkerScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  String _role = 'Worker';
  bool _active = true;
  bool _saving = false;

  static final _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    final name = _nameCtrl.text.trim();
    final result = await context.read<TeamCubit>().add(
          name: name,
          email: _emailCtrl.text,
          phone: _phoneCtrl.text,
          role: _role,
          active: _active,
        );
    if (!mounted) return;
    setState(() => _saving = false);
    if (result.isFailure) {
      AppFeedback.error('Not added', result.failure!.message);
      return;
    }
    Navigator.pop(context);
    AppFeedback.success(
      '${name.split(' ').first} is on the team',
      _role == 'Worker' && _active
          ? 'They will start getting new guests.'
          : 'They can sign in now.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<TeamCubit>();
    final isWorker = _role == 'Worker';

    return Scaffold(
      body: Column(
        children: [
          const AppTopBar(title: 'Add a worker'),
          Expanded(
            child: Form(
              key: _formKey,
              child: PageList(
                children: [
                  Padding(
                    padding: EdgeInsets.only(left: AppSizes.s8, bottom: AppSizes.s24),
                    child: Text('They sign in with this Google account.',
                        style: AppTextStyles.bodyMuted),
                  ),
                  AppTextField(
                    label: 'Full name',
                    hint: 'Grace Ade',
                    controller: _nameCtrl,
                    textInputAction: TextInputAction.next,
                    textCapitalization: TextCapitalization.words,
                    autofillHints: const [AutofillHints.name],
                    validator: (v) =>
                        (v ?? '').trim().length < 2 ? 'Enter their name.' : null,
                  ),
                  SizedBox(height: AppSizes.s16),
                  AppTextField(
                    label: 'Google email',
                    hint: 'name@gmail.com',
                    controller: _emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.email],
                    validator: (v) {
                      final value = (v ?? '').trim().toLowerCase();
                      if (!_emailPattern.hasMatch(value)) return 'Enter a valid email.';
                      if (cubit.members.any((m) => m.email.toLowerCase() == value)) {
                        return 'This email is already on the team.';
                      }
                      return null;
                    },
                  ),
                  SizedBox(height: AppSizes.s16),
                  AppTextField(
                    label: 'Phone (optional)',
                    hint: '0803 000 0000',
                    controller: _phoneCtrl,
                    keyboardType: TextInputType.phone,
                    textInputAction: TextInputAction.done,
                    autofillHints: const [AutofillHints.telephoneNumber],
                  ),
                  SizedBox(height: AppSizes.s24),
                  Text('Role', style: AppTextStyles.captionStrong),
                  SizedBox(height: AppSizes.s8),
                  SegmentedPicker(
                    options: const ['Worker', 'Admin'],
                    value: _role,
                    onChanged: (r) => setState(() => _role = r),
                  ),
                  SizedBox(height: AppSizes.s8),
                  Text(
                    isWorker
                        ? 'Workers call and follow up their guests.'
                        : 'Admins see the dashboard and never get guests.',
                    style: AppTextStyles.caption,
                  ),
                  if (isWorker) ...[
                    SizedBox(height: AppSizes.s24),
                    GroupedCard(
                      children: [
                        AppSwitchRow(
                          title: 'Start getting guests now',
                          subtitle: 'Adds them to the rotation',
                          value: _active,
                          onChanged: (v) => setState(() => _active = v),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(AppSizes.gutter, AppSizes.s8, AppSizes.gutter,
                AppSizes.s16 + MediaQuery.paddingOf(context).bottom),
            child: AppButton(label: 'Add worker', isLoading: _saving, onPressed: _save),
          ),
        ],
      ),
    );
  }
}
