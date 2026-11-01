import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
import 'core/web/bundled_firebase.dart';
import 'core/widgets/responsive_web_shell.dart';
import 'data/firestore/firestore_guest_repository.dart';
import 'data/firestore/firestore_profile_source.dart';
import 'data/firestore/sheet_sync_repository.dart';
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
  await waitForBundledFirebase();
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
  // Firestore switch (--dart-define=DATA_SOURCE=firestore): roles and guests
  // come from Firestore and follow-ups are saved there. The device keeps a
  // copy, so saves made offline survive a reload and sync when back online.
  if (AppConfig.useFirestore) {
    FirebaseFirestore.instance.settings = const Settings(persistenceEnabled: true);
  }
  final profileSource = AppConfig.useFirestore
      ? FirestoreProfileSource(db: FirebaseFirestore.instance, auth: FirebaseAuth.instance)
      : null;
  final authRepository = AuthRepositoryImpl(
    apiClient: apiClient,
    profileLoader: profileSource?.load,
  );
  // Sample repositories exist for UI work only and are compiled out of any
  // build made without --dart-define=USE_SAMPLE_DATA=true.
  final apiGuests = GuestRepositoryImpl(
    apiClient: apiClient,
    authRepository: authRepository,
    localCache: localCache,
  );
  final IGuestRepository guestRepository = AppConfig.useSampleData
      ? SampleGuestRepository()
      : AppConfig.useFirestore
          ? FirestoreGuestRepository(
              db: FirebaseFirestore.instance,
              authRepository: authRepository,
            )
          : apiGuests;
  final ITeamRepository teamRepository = AppConfig.useSampleData
      ? SampleTeamRepository()
      : TeamRepositoryImpl(apiClient: apiClient, authRepository: authRepository);

  final ISheetSyncRepository? sheetSyncRepository = AppConfig.useFirestore
      ? SheetSyncRepository(
          db: FirebaseFirestore.instance,
          apiClient: apiClient,
          authRepository: authRepository,
        )
      : null;

  runApp(PCUConnectApp(
    authRepository: authRepository,
    guestRepository: guestRepository,
    teamRepository: teamRepository,
    sheetSyncRepository: sheetSyncRepository,
    localCache: localCache,
  ));
}

class PCUConnectApp extends StatelessWidget {
  final IAuthRepository authRepository;
  final IGuestRepository guestRepository;
  final ITeamRepository teamRepository;

  /// Firestore mode only: the HOD's sheet sync.
  final ISheetSyncRepository? sheetSyncRepository;
  final LocalCache localCache;

  const PCUConnectApp({
    super.key,
    required this.authRepository,
    required this.guestRepository,
    required this.teamRepository,
    this.sheetSyncRepository,
    required this.localCache,
  });

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider<IAuthRepository>.value(value: authRepository),
        RepositoryProvider<IGuestRepository>.value(value: guestRepository),
        RepositoryProvider<ITeamRepository>.value(value: teamRepository),
        if (sheetSyncRepository != null)
          RepositoryProvider<ISheetSyncRepository>.value(value: sheetSyncRepository!),
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
