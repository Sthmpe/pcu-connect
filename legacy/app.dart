import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'core/constants/app_strings.dart';
import 'core/routing/app_router.dart';
import 'core/routing/app_routes.dart';
import 'core/terminology/terminology_cubit.dart';
import 'core/theme/app_theme.dart';
import 'features/access_control/data/repositories/access_control_repository_impl.dart';
import 'features/access_control/presentation/cubit/access_cubit.dart';
import 'features/auth/data/repositories/auth_repository_impl.dart';
import 'features/auth/presentation/bloc/auth_bloc.dart';
import 'features/auth/presentation/bloc/auth_state.dart';

class PCUWorkflowApp extends StatelessWidget {
  const PCUWorkflowApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ScreenUtilInit(
      designSize: const Size(375, 812),
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (context, child) {
        return MultiBlocProvider(
          providers: [
            // Auth, terminology, and current-unit access are session state.
            // Workflow feature blocs stay route-scoped and are disposed with
            // their screens.
            BlocProvider(
              create: (_) => AuthBloc(authRepository: AuthRepositoryImpl()),
            ),
            BlocProvider(create: (_) => TerminologyCubit()),
            BlocProvider(
              create: (_) =>
                  AccessCubit(repository: AccessControlRepositoryImpl()),
            ),
          ],
          child: _SessionLoader(
            child: MaterialApp(
              title: AppStrings.appDisplayName,
              debugShowCheckedModeBanner: false,
              theme: AppTheme.lightTheme,
              initialRoute: AppRoutes.splash,
              onGenerateRoute: AppRouter.onGenerateRoute,
            ),
          ),
        );
      },
    );
  }
}

/// Loads terminology and the current unit's capability read model whenever
/// authentication resolves. Neither read model grants authority.
class _SessionLoader extends StatelessWidget {
  final Widget child;

  const _SessionLoader({required this.child});

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is AuthAuthenticated) {
          context.read<TerminologyCubit>().loadForOrganization(
            state.userProfile.organizationId,
          );
          final unitId = state.userProfile.unitId;
          if (unitId.isEmpty) {
            context.read<AccessCubit>().reset();
          } else {
            context.read<AccessCubit>().loadForUnit(unitId);
          }
        } else {
          context.read<AccessCubit>().reset();
        }
      },
      child: child,
    );
  }
}
