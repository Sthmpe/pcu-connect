import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/config/app_config.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/widgets/app_feedback.dart';
import '../../../core/widgets/brand_marks.dart';
import '../../../core/widgets/custom_button.dart';
import '../../guests/bloc/guests_bloc.dart';
import '../../guests/bloc/guests_event.dart';
import '../bloc/auth_bloc.dart';
import '../bloc/auth_event.dart';
import '../bloc/auth_state.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  @override
  void initState() {
    super.initState();
    // The session check may finish before this screen subscribes.
    final state = context.read<AuthBloc>().state;
    if (state is AuthAuthenticatedState) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _enterApp(state));
    }
  }

  void _enterApp(AuthAuthenticatedState state) {
    if (!mounted) return;
    context.read<GuestsBloc>().add(const LoadGuestsEvent());
    Navigator.of(context).pushReplacementNamed(
      state.user.isAdmin ? AppRoutes.admin : AppRoutes.worker,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.navy,
      body: BlocConsumer<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state is AuthAuthenticatedState) {
            _enterApp(state);
          } else if (state is AuthUnauthorizedState) {
            AppFeedback.notice(title: 'No access yet', message: state.message);
          } else if (state is AuthFailureState) {
            AppFeedback.error('Sign in failed', state.message);
          }
        },
        builder: (context, state) {
          final checkingSession = state is AuthInitialState;
          final isLoading = state is AuthLoadingState;

          return Column(
            children: [
              Expanded(child: _Hero(checkingSession: checkingSession)),
              AnimatedSwitcher(
                duration: AppDurations.normal,
                child: checkingSession
                    ? const SizedBox(height: 0, width: double.infinity)
                    : _SignInPanel(isLoading: isLoading),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  final bool checkingSession;

  const _Hero({required this.checkingSession});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.navy, AppColors.navyLight],
        ),
      ),
      child: Stack(
        children: [
          // Soft gold glow, decorative only.
          Positioned(
            top: -80,
            right: -60,
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [
                  AppColors.gold.withValues(alpha: 0.22),
                  AppColors.gold.withValues(alpha: 0),
                ]),
              ),
            ),
          ),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: AppColors.gold,
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.gold.withValues(alpha: 0.35),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.volunteer_activism_rounded,
                      color: AppColors.navy, size: 36),
                ),
                SizedBox(height: AppSizes.p20),
                Text('PCU Connect',
                    style: AppTextStyles.brand.copyWith(color: AppColors.onNavy)),
                SizedBox(height: AppSizes.p6),
                Text(
                  'Care for every guest, one call at a time',
                  style: AppTextStyles.screenSubtitle,
                  textAlign: TextAlign.center,
                ),
                if (checkingSession) ...[
                  SizedBox(height: AppSizes.p32),
                  const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      color: AppColors.gold,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SignInPanel extends StatelessWidget {
  final bool isLoading;

  const _SignInPanel({required this.isLoading});

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<AuthBloc>();

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        AppSizes.p24,
        AppSizes.p24,
        AppSizes.p24,
        AppSizes.p24 + MediaQuery.paddingOf(context).bottom,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppSizes.radiusXl + 4)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Welcome',
              style: AppTextStyles.detailTitle.copyWith(color: AppColors.ink)),
          SizedBox(height: AppSizes.p4),
          Text(
            'Sign in with the Google account your HOD added to the team.',
            style: AppTextStyles.secondary,
          ),
          SizedBox(height: AppSizes.p20),
          AppButton(
            label: 'Continue with Google',
            variant: AppButtonVariant.primary,
            isLoading: isLoading,
            leading: Container(
              width: 22,
              height: 22,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: AppColors.surface,
                shape: BoxShape.circle,
              ),
              child: const GoogleMark(size: 13),
            ),
            onPressed: () => bloc.add(AuthSignInRequestedEvent()),
          ),
          SizedBox(height: AppSizes.p12),
          Row(
            children: [
              Icon(Icons.lock_outline_rounded,
                  size: AppSizes.iconXs, color: AppColors.subtle),
              SizedBox(width: AppSizes.p6),
              Expanded(
                child: Text(
                  'Only approved PCU workers and leaders can sign in.',
                  style: AppTextStyles.caption,
                ),
              ),
            ],
          ),
          if (AppConfig.enableMockLogin) ...[
            SizedBox(height: AppSizes.p20),
            const _DevSwitcher(),
          ],
        ],
      ),
    );
  }
}

/// Debug builds only: sign in as a test worker or admin.
class _DevSwitcher extends StatelessWidget {
  const _DevSwitcher();

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<AuthBloc>();
    return Container(
      padding: EdgeInsets.all(AppSizes.p12),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('DEVELOPER SWITCH', style: AppTextStyles.overline),
          SizedBox(height: AppSizes.p8),
          Row(
            children: [
              Expanded(
                child: AppButton(
                  label: 'David · Worker',
                  size: AppButtonSize.small,
                  variant: AppButtonVariant.tonal,
                  onPressed: () => bloc.add(const AuthMockSignInRequestedEvent(
                    email: 'davidolanite0@gmail.com',
                    role: 'Worker',
                  )),
                ),
              ),
              SizedBox(width: AppSizes.p8),
              Expanded(
                child: AppButton(
                  label: 'Opeyemi · Admin',
                  size: AppButtonSize.small,
                  variant: AppButtonVariant.outline,
                  onPressed: () => bloc.add(const AuthMockSignInRequestedEvent(
                    email: 'olaniteolanight@gmail.com',
                    role: 'Admin',
                  )),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
