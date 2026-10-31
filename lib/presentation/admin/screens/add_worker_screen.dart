import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_feedback.dart';
import '../../../core/widgets/app_header.dart';
import '../../../core/widgets/custom_button.dart';
import '../../../core/widgets/custom_text_field.dart';
import '../../../core/widgets/filter_chip_widget.dart';
import '../cubit/team_cubit.dart';

class AddWorkerScreen extends StatefulWidget {
  const AddWorkerScreen({super.key});

  @override
  State<AddWorkerScreen> createState() => _AddWorkerScreenState();
}

class _AddWorkerScreenState extends State<AddWorkerScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  String _role = 'Worker';
  bool _active = true;

  static final _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  void _save() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final name = _nameCtrl.text.trim();
    context.read<TeamCubit>().add(
          name: name,
          email: _emailCtrl.text,
          role: _role,
          active: _active,
        );
    Navigator.pop(context);
    AppFeedback.success(
      'Worker added',
      _role == 'Worker' && _active
          ? '$name joins the guest rotation.'
          : '$name can now sign in.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<TeamCubit>();
    final isWorker = _role == 'Worker';

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Column(
        children: [
          AppHeader(
            title: 'Add a worker',
            subtitle: 'They sign in with this Google account',
            onBack: () => Navigator.pop(context),
            backLabel: 'Team',
          ),
          Expanded(
            child: Form(
              key: _formKey,
              child: ListView(
                padding: EdgeInsets.fromLTRB(AppSizes.gutter, AppSizes.p16,
                    AppSizes.gutter, AppSizes.p24),
                children: [
                  CustomTextField(
                    label: 'Full name',
                    hint: 'e.g. Grace Ade',
                    controller: _nameCtrl,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.name],
                    validator: (v) => (v ?? '').trim().length < 2
                        ? 'Enter their name.'
                        : null,
                  ),
                  SizedBox(height: AppSizes.p16),
                  CustomTextField(
                    label: 'Google email',
                    hint: 'name@gmail.com',
                    controller: _emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.done,
                    autofillHints: const [AutofillHints.email],
                    validator: (v) {
                      final value = (v ?? '').trim();
                      if (!_emailPattern.hasMatch(value)) {
                        return 'Enter a valid email address.';
                      }
                      if (cubit.emailExists(value)) {
                        return 'This email is already on the team.';
                      }
                      return null;
                    },
                  ),
                  SizedBox(height: AppSizes.p20),
                  Text('Role', style: AppTextStyles.label),
                  SizedBox(height: AppSizes.p6),
                  SegmentedPicker(
                    options: const ['Worker', 'Admin'],
                    value: _role,
                    onChanged: (r) => setState(() => _role = r),
                  ),
                  SizedBox(height: AppSizes.p6),
                  Text(
                    isWorker
                        ? 'Workers call and follow up the guests assigned to them.'
                        : 'Admins see the dashboard and manage the team. They never get guests.',
                    style: AppTextStyles.caption,
                  ),
                  SizedBox(height: AppSizes.p20),
                  AnimatedOpacity(
                    duration: AppDurations.fast,
                    opacity: isWorker ? 1 : 0.5,
                    child: AppCard(
                      padding: EdgeInsets.symmetric(
                          horizontal: AppSizes.p16, vertical: AppSizes.p8),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Add to the rotation',
                                    style: AppTextStyles.itemTitle),
                                SizedBox(height: AppSizes.p2),
                                Text('New guests are shared out to them',
                                    style: AppTextStyles.caption),
                              ],
                            ),
                          ),
                          Switch(
                            value: isWorker && _active,
                            onChanged: isWorker
                                ? (v) => setState(() => _active = v)
                                : null,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          BottomActionBar(
            child: AppButton(
              label: 'Add worker',
              icon: Icons.person_add_alt_1_rounded,
              variant: AppButtonVariant.accent,
              onPressed: _save,
            ),
          ),
        ],
      ),
    );
  }
}
