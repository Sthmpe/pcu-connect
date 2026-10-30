import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/widgets/responsive_web_shell.dart';
import '../../admin/screens/admin_shell_screen.dart';
import '../../worker/screens/worker_shell_screen.dart';
import '../bloc/auth_bloc.dart';
import '../bloc/auth_event.dart';
import '../bloc/auth_state.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ResponsiveWebShell(
      child: Scaffold(
        backgroundColor: AppColors.bg,
        body: BlocConsumer<AuthBloc, AuthState>(
          listener: (context, state) {
            if (state is AuthAuthenticatedState) {
              if (state.user.isAdmin) {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (_) => const AdminShellScreen()),
                );
              } else {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (_) => const WorkerShellScreen()),
                );
              }
            } else if (state is AuthUnauthorizedState) {
              Get.defaultDialog(
                title: 'Access Restricted',
                middleText: state.message,
                textConfirm: 'OK',
                confirmTextColor: Colors.white,
                buttonColor: AppColors.navy,
                onConfirm: () => Get.back(),
              );
            } else if (state is AuthFailureState) {
              Get.snackbar(
                'Sign In Failed',
                state.message,
                backgroundColor: AppColors.red,
                colorText: Colors.white,
                snackPosition: SnackPosition.BOTTOM,
              );
            }
          },
          builder: (context, state) {
            final isLoading = state is AuthLoadingState;

            return Center(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 24.w),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Brand Icon & Header
                    Container(
                      width: 80.r,
                      height: 80.r,
                      decoration: const BoxDecoration(
                        color: AppColors.navy,
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.handshake_rounded,
                        color: AppColors.gold,
                        size: 44,
                      ),
                    ),
                    SizedBox(height: 18.h),
                    Text(
                      'PCU Connect',
                      style: TextStyle(
                        fontSize: 28.sp,
                        fontWeight: FontWeight.w700,
                        color: AppColors.navy,
                      ),
                    ),
                    SizedBox(height: 6.h),
                    Text(
                      'Pastoral Care Unit Guest Management',
                      style: AppTextStyles.bodyMuted,
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 48.h),

                    // Google Sign-In Button
                    InkWell(
                      onTap: isLoading
                          ? null
                          : () {
                              context
                                  .read<AuthBloc>()
                                  .add(AuthSignInRequestedEvent());
                            },
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        height: 52.h,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                              color: const Color(0xFFC3CAD6), width: 1.5),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.navy.withValues(alpha: 0.06),
                              blurRadius: 3,
                              offset: const Offset(0, 1),
                            ),
                          ],
                        ),
                        child: isLoading
                            ? const Center(
                                child: CircularProgressIndicator(
                                  color: AppColors.navy,
                                  strokeWidth: 2.5,
                                ),
                              )
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.g_mobiledata_rounded,
                                      size: 32, color: AppColors.navy),
                                  SizedBox(width: 8.w),
                                  Text(
                                    'Sign in with Google',
                                    style: TextStyle(
                                      fontSize: 16.sp,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.navy,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                    SizedBox(height: 24.h),

                    // Quick Switch Options for Testing
                    Container(
                      padding: EdgeInsets.all(14.r),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.line),
                      ),
                      child: Column(
                        children: [
                          Text(
                            'Quick Test Switch',
                            style: TextStyle(
                              fontSize: 12.sp,
                              fontWeight: FontWeight.w600,
                              color: AppColors.muted,
                            ),
                          ),
                          SizedBox(height: 10.h),
                          Row(
                            children: [
                              Expanded(
                                child: InkWell(
                                  onTap: () {
                                    context.read<AuthBloc>().add(
                                          const AuthMockSignInRequestedEvent(
                                            email: 'davidolanite0@gmail.com',
                                            role: 'Worker',
                                          ),
                                        );
                                  },
                                  borderRadius: BorderRadius.circular(10),
                                  child: Container(
                                    padding: EdgeInsets.symmetric(vertical: 8.h),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFE6EBF4),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    alignment: Alignment.center,
                                    child: Text(
                                      'David (Worker)',
                                      style: TextStyle(
                                        fontSize: 12.sp,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.navy,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              SizedBox(width: 8.w),
                              Expanded(
                                child: InkWell(
                                  onTap: () {
                                    context.read<AuthBloc>().add(
                                          const AuthMockSignInRequestedEvent(
                                            email: 'olaniteolanight@gmail.com',
                                            role: 'Admin',
                                          ),
                                        );
                                  },
                                  borderRadius: BorderRadius.circular(10),
                                  child: Container(
                                    padding: EdgeInsets.symmetric(vertical: 8.h),
                                    decoration: BoxDecoration(
                                      color: AppColors.pillGoldBg,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    alignment: Alignment.center,
                                    child: Text(
                                      'Opeyemi (Admin)',
                                      style: TextStyle(
                                        fontSize: 12.sp,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.pillGoldText,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
