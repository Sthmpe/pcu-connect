import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/routing/app_routes.dart';
import '../../../../core/terminology/terminology_cubit.dart';
import '../../../access_control/domain/models/capability.dart';
import '../../../access_control/presentation/cubit/access_cubit.dart';
import '../../../access_control/presentation/cubit/access_state.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_event.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../../../auth/domain/models/user_profile.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Scoped to just the app-title label so unrelated terminology changes
    // (e.g. `contact` vs `contactPlural`) don't rebuild this AppBar.
    final unitLabel = context.select((TerminologyCubit c) => c.state.unit);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('$unitLabel Workflow'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () =>
                context.read<AuthBloc>().add(const AuthLogoutRequested()),
          ),
        ],
      ),
      body: BlocListener<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state is AuthUnauthenticated) {
            Navigator.of(
              context,
            ).pushNamedAndRemoveUntil(AppRoutes.login, (_) => false);
          }
        },
        child: Padding(
          padding: EdgeInsets.all(AppSizes.p16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Welcome', style: AppTextStyles.displayMedium),
              SizedBox(height: AppSizes.p8),
              Text(
                'Home dashboard metrics land here (Received, Contacted, Retained...).',
                style: AppTextStyles.bodyMedium,
              ),
              SizedBox(height: AppSizes.p24),
              ElevatedButton(
                onPressed: () =>
                    Navigator.of(context).pushNamed(AppRoutes.guests),
                child: Builder(
                  builder: (context) {
                    final terminology = context.select(
                      (TerminologyCubit c) => c.state,
                    );
                    return Text('My ${terminology.contactPlural}');
                  },
                ),
              ),
              BlocBuilder<AuthBloc, AuthState>(
                buildWhen: (previous, current) => previous != current,
                builder: (context, state) {
                  if (state is! AuthAuthenticated ||
                      state.userProfile.role != UserRole.organizationOwner ||
                      state.userProfile.organizationId.isEmpty) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: EdgeInsets.only(top: AppSizes.p12),
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.account_tree_outlined),
                      label: const Text(AppStrings.manageStructure),
                      onPressed: () => Navigator.of(context).pushNamed(
                        AppRoutes.organizationStructure,
                        arguments: state.userProfile.organizationId,
                      ),
                    ),
                  );
                },
              ),
              BlocBuilder<AuthBloc, AuthState>(
                buildWhen: (previous, current) => previous != current,
                builder: (context, state) {
                  if (state is! AuthAuthenticated ||
                      state.userProfile.unitId.isEmpty) {
                    return const SizedBox.shrink();
                  }
                  return BlocSelector<AccessCubit, AccessState, bool>(
                    selector: (access) =>
                        access is AccessReady &&
                        access.membership.baseRole == BaseRole.unitManager &&
                        access.can(Capability.permissionsDelegate),
                    builder: (context, canDelegate) {
                      if (!canDelegate) return const SizedBox.shrink();
                      return Padding(
                        padding: EdgeInsets.only(top: AppSizes.p12),
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.admin_panel_settings_outlined),
                          label: const Text(AppStrings.manageAccess),
                          onPressed: () => Navigator.of(context).pushNamed(
                            AppRoutes.delegation,
                            arguments: DelegationRouteArguments(
                              unitId: state.userProfile.unitId,
                              unitName: unitLabel,
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
