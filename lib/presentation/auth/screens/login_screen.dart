import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/config/app_config.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_icons.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/widgets/app_controls.dart';
import '../../../core/widgets/app_feedback.dart';
import '../../../core/widgets/brand_marks.dart';
import '../../common/insights_cubits.dart';
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
    // Clear anything left from a previous account on this device.
    context.read<RankingCubit>().reset();
    context.read<DashboardCubit>().reset();
    context.read<TeamCubit>().reset();
    context.read<GuestsBloc>().add(const LoadGuestsEvent());
    Navigator.of(context).pushReplacementNamed(
      state.user.isAdmin ? AppRoutes.admin : AppRoutes.worker,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BlocConsumer<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state is AuthAuthenticatedState) {
            _enterApp(state);
          } else if (state is AuthUnauthorizedState) {
            AppFeedback.notice(title: 'You are not on the team yet', message: state.message);
          } else if (state is AuthFailureState) {
            AppFeedback.error('Sign in did not work', state.message);
          }
        },
        builder: (context, state) {
          final checking = state is AuthInitialState;
          final loading = state is AuthLoadingState;
          final bloc = context.read<AuthBloc>();

          return SafeArea(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: AppSizes.gutter),
              child: Column(
                children: [
                  const Spacer(flex: 3),
                  _BrandMark(pulsing: checking),
                  SizedBox(height: AppSizes.s24),
                  Text('PCU Connect', style: AppTextStyles.display),
                  SizedBox(height: AppSizes.s8),
                  Text(
                    'Follow up every guest with care.',
                    style: AppTextStyles.bodyMuted,
                    textAlign: TextAlign.center,
                  ),
                  const Spacer(flex: 4),
                  AnimatedOpacity(
                    duration: AppDurations.normal,
                    opacity: checking ? 0 : 1,
                    child: IgnorePointer(
                      ignoring: checking,
                      child: Column(
                        children: [
                          AppButton(
                            label: 'Continue with Google',
                            isLoading: loading,
                            leading: Container(
                              width: 24,
                              height: 24,
                              alignment: Alignment.center,
                              decoration: const BoxDecoration(
                                color: AppColors.surface,
                                shape: BoxShape.circle,
                              ),
                              child: const GoogleMark(size: 14),
                            ),
                            onPressed: () => bloc.add(AuthSignInRequestedEvent()),
                          ),
                          SizedBox(height: AppSizes.s16),
                          Text(
                            'Use the Google account your HOD added.',
                            style: AppTextStyles.caption,
                            textAlign: TextAlign.center,
                          ),
                          if (AppConfig.enableMockLogin) ...[
                            SizedBox(height: AppSizes.s32),
                            Text('Developer sign in', style: AppTextStyles.caption),
                            SizedBox(height: AppSizes.s8),
                            Row(
                              children: [
                                Expanded(
                                  child: AppButton(
                                    label: 'David, worker',
                                    variant: AppButtonVariant.secondary,
                                    onPressed: () => bloc.add(
                                      const AuthMockSignInRequestedEvent(
                                        email: 'davidolanite0@gmail.com',
                                        role: 'Worker',
                                      ),
                                    ),
                                  ),
                                ),
                                SizedBox(width: AppSizes.s8),
                                Expanded(
                                  child: AppButton(
                                    label: 'Opeyemi, admin',
                                    variant: AppButtonVariant.secondary,
                                    onPressed: () => bloc.add(
                                      const AuthMockSignInRequestedEvent(
                                        email: 'olaniteolanight@gmail.com',
                                        role: 'Admin',
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: AppSizes.s32),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Navy app mark. Breathes gently while the session is being checked.
class _BrandMark extends StatefulWidget {
  final bool pulsing;

  const _BrandMark({required this.pulsing});

  @override
  State<_BrandMark> createState() => _BrandMarkState();
}

class _BrandMarkState extends State<_BrandMark> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );

  @override
  void initState() {
    super.initState();
    if (widget.pulsing) _c.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(_BrandMark old) {
    super.didUpdateWidget(old);
    if (widget.pulsing && !_c.isAnimating) {
      _c.repeat(reverse: true);
    } else if (!widget.pulsing && _c.isAnimating) {
      _c.animateTo(0, duration: AppDurations.normal);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: Tween(begin: 1.0, end: 0.94).animate(
        CurvedAnimation(parent: _c, curve: Curves.easeInOut),
      ),
      child: Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.navyRaised, AppColors.navy],
          ),
          borderRadius: BorderRadius.circular(AppSizes.radiusLg + 2),
          boxShadow: AppShadows.raised,
        ),
        child: const Icon(AppIcons.heart, color: AppColors.gold, size: 32),
      ),
    );
  }
}
