import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/config/app_config.dart';
import 'core/constants/app_sizes.dart';
import 'core/network/api_client.dart';
import 'core/routing/app_routes.dart';
import 'core/storage/local_cache.dart';
import 'core/theme/app_theme.dart';
import 'core/widgets/responsive_web_shell.dart';
import 'data/repositories/auth_repository_impl.dart';
import 'data/repositories/guest_repository_impl.dart';
import 'data/repositories/team_repository_impl.dart';
import 'data/sample/sample_repositories.dart';
import 'domain/repositories/i_auth_repository.dart';
import 'firebase_options.dart';
import 'domain/repositories/i_guest_repository.dart';
import 'domain/repositories/i_team_repository.dart';
import 'presentation/auth/bloc/auth_bloc.dart';
import 'presentation/auth/bloc/auth_event.dart';
import 'presentation/common/insights_cubits.dart';
import 'presentation/guests/bloc/guests_bloc.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  final prefs = await SharedPreferences.getInstance();
  final localCache = LocalCache(prefs);

  // Apps Script /exec URL, set at build time:
  // flutter build web --dart-define=APPS_SCRIPT_URL=<url>
  const appsScriptUrl = String.fromEnvironment(
    'APPS_SCRIPT_URL',
    defaultValue: 'https://script.google.com/macros/s/AKfycbytest/exec',
  );

  final apiClient = ApiClient(baseUrl: appsScriptUrl);
  final authRepository = AuthRepositoryImpl(apiClient: apiClient);
  // Sample repositories exist for UI work only and are compiled out of any
  // build made without --dart-define=USE_SAMPLE_DATA=true.
  final IGuestRepository guestRepository = AppConfig.useSampleData
      ? SampleGuestRepository()
      : GuestRepositoryImpl(
          apiClient: apiClient,
          authRepository: authRepository,
          localCache: localCache,
        );
  final ITeamRepository teamRepository = AppConfig.useSampleData
      ? SampleTeamRepository()
      : TeamRepositoryImpl(apiClient: apiClient, authRepository: authRepository);

  runApp(PCUConnectApp(
    authRepository: authRepository,
    guestRepository: guestRepository,
    teamRepository: teamRepository,
    localCache: localCache,
  ));
}

class PCUConnectApp extends StatelessWidget {
  final IAuthRepository authRepository;
  final IGuestRepository guestRepository;
  final ITeamRepository teamRepository;
  final LocalCache localCache;

  const PCUConnectApp({
    super.key,
    required this.authRepository,
    required this.guestRepository,
    required this.teamRepository,
    required this.localCache,
  });

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider<IAuthRepository>.value(value: authRepository),
        RepositoryProvider<IGuestRepository>.value(value: guestRepository),
        RepositoryProvider<ITeamRepository>.value(value: teamRepository),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider<AuthBloc>(
            create: (ctx) => AuthBloc(
              authRepository: authRepository,
              localCache: localCache,
            )..add(AuthCheckSessionEvent()),
          ),
          BlocProvider<GuestsBloc>(
            create: (ctx) => GuestsBloc(guestRepository: guestRepository),
          ),
          BlocProvider<RankingCubit>(create: (ctx) => RankingCubit(teamRepository)),
          BlocProvider<DashboardCubit>(create: (ctx) => DashboardCubit(teamRepository)),
          BlocProvider<TeamCubit>(create: (ctx) => TeamCubit(teamRepository)),
        ],
        child: ScreenUtilInit(
          // Design resolution from PCU_Worker_App.html (390 x 844). The
          // ResponsiveWebShell re-configures scaling from the phone frame.
          designSize: AppSizes.designSize,
          minTextAdapt: true,
          fontSizeResolver: ResponsiveWebShell.resolveFontSize,
          builder: (context, child) {
            return GetMaterialApp(
              title: 'PCU Connect',
              debugShowCheckedModeBanner: false,
              theme: AppTheme.lightTheme,
              initialRoute: AppRoutes.login,
              onGenerateInitialRoutes: AppRoutes.initialRoutes,
              onGenerateRoute: AppRoutes.onGenerateRoute,
              builder: (context, child) =>
                  ResponsiveWebShell(child: child ?? const SizedBox.shrink()),
            );
          },
        ),
      ),
    );
  }
}
