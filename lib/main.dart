import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
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
import 'core/web/browser_info.dart';
import 'core/web/bundled_firebase.dart';
import 'core/web/notification_sound.dart';
import 'core/widgets/app_feedback.dart';
import 'core/widgets/responsive_web_shell.dart';
import 'data/firestore/firestore_guest_repository.dart';
import 'data/firestore/firestore_profile_source.dart';
import 'data/firestore/firestore_team_repository.dart';
import 'data/firestore/notifications_repository.dart';
import 'data/firestore/push_service.dart';
import 'data/firestore/sheet_sync_repository.dart';
import 'core/install/install_support.dart';
import 'core/storage/member_celebrations.dart';
import 'core/sync/connectivity.dart';
import 'core/sync/sync_signals.dart';
import 'core/sync/sync_status_cubit.dart';
import 'data/firestore/message_templates_repository.dart';
import 'data/firestore/nudge_repository.dart';
import 'data/firestore/worker_calls_repository.dart';
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
import 'presentation/common/install_prompt_cubit.dart';
import 'presentation/common/notifications_cubit.dart';
import 'presentation/common/push_cubit.dart';
import 'presentation/guests/bloc/guests_bloc.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  AppConfig.userAgentSource = browserUserAgent;
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
  // The top bar's sync chip (Firestore mode). Saves left from an earlier
  // visit count as on their way until the server has them.
  final SyncSignals? syncSignals = AppConfig.useFirestore ? SyncSignals() : null;
  syncSignals?.trackWrite(FirebaseFirestore.instance.waitForPendingWrites());
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
              signals: syncSignals,
            )
          : apiGuests;
  final apiTeam = TeamRepositoryImpl(apiClient: apiClient, authRepository: authRepository);
  // Firestore mode: ranking, team and dashboard read Firestore, so saves show
  // at once; adding or pausing a worker still goes through Apps Script.
  final ITeamRepository teamRepository = AppConfig.useSampleData
      ? SampleTeamRepository()
      : AppConfig.useFirestore
          ? FirestoreTeamRepository(db: FirebaseFirestore.instance, authRepository: authRepository, accounts: apiTeam)
          : apiTeam;

  final ISheetSyncRepository? sheetSyncRepository = AppConfig.useFirestore
      ? SheetSyncRepository(
          db: FirebaseFirestore.instance,
          apiClient: apiClient,
          authRepository: authRepository,
        )
      : null;

  // Web push (Firestore mode, web only): token saved after the person agrees.
  final IPushService? pushService = AppConfig.useFirestore && kIsWeb
      ? PushService(
          messaging: FirebaseMessaging.instance,
          db: FirebaseFirestore.instance,
          authRepository: authRepository,
        )
      : null;

  runApp(PCUConnectApp(
    authRepository: authRepository,
    guestRepository: guestRepository,
    teamRepository: teamRepository,
    sheetSyncRepository: sheetSyncRepository,
    pushService: pushService,
    notificationsRepository: AppConfig.useFirestore
        ? NotificationsRepository(db: FirebaseFirestore.instance, authRepository: authRepository)
        : null,
    localCache: localCache,
    syncSignals: syncSignals,
    // "Add to Home Screen" (web only; the flags live on this device).
    installPrompt: InstallPromptCubit(prefs: prefs, support: InstallSupport()),
    celebrations: MemberCelebrations(prefs),
    nudgeRepository: NudgeRepository(
      apiClient: apiClient,
      authRepository: authRepository,
      db: AppConfig.useFirestore ? FirebaseFirestore.instance : null,
    ),
  ));
}

class PCUConnectApp extends StatelessWidget {
  final IAuthRepository authRepository;
  final IGuestRepository guestRepository;
  final ITeamRepository teamRepository;

  /// Firestore mode only: the HOD's sheet sync.
  final ISheetSyncRepository? sheetSyncRepository;

  /// Firestore mode on the web only: notifications.
  final IPushService? pushService;

  /// Firestore mode only: the bell list.
  final INotificationsRepository? notificationsRepository;
  final LocalCache localCache;

  /// Firestore mode only: the sync chip.
  final SyncSignals? syncSignals;

  final InstallPromptCubit? installPrompt;

  /// Guests whose membership was already celebrated on this device.
  final MemberCelebrations? celebrations;

  /// The HOD's nudges (sent by Apps Script).
  final INudgeRepository? nudgeRepository;

  const PCUConnectApp({
    super.key,
    required this.authRepository,
    required this.guestRepository,
    required this.teamRepository,
    this.sheetSyncRepository,
    this.pushService,
    this.notificationsRepository,
    required this.localCache,
    this.syncSignals,
    this.installPrompt,
    this.celebrations,
    this.nudgeRepository,
  });

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider<IAuthRepository>.value(value: authRepository),
        RepositoryProvider<IGuestRepository>.value(value: guestRepository),
        RepositoryProvider<ITeamRepository>.value(value: teamRepository),
        // The worker's own calls for Today (live in Firestore mode).
        RepositoryProvider<IWorkerCallsRepository>(
          create: (_) => AppConfig.useFirestore
              ? FirestoreWorkerCallsRepository(db: FirebaseFirestore.instance, authRepository: authRepository)
              : const NoWorkerCallsRepository(),
        ),
        // WhatsApp messages (editable by the HOD in Firestore mode).
        RepositoryProvider<IMessageTemplatesRepository>(
          create: (_) => AppConfig.useFirestore
              ? FirestoreMessageTemplatesRepository(db: FirebaseFirestore.instance, authRepository: authRepository)
              : const DefaultMessageTemplatesRepository(),
        ),
        if (celebrations != null) RepositoryProvider<MemberCelebrations>.value(value: celebrations!),
        if (nudgeRepository != null) RepositoryProvider<INudgeRepository>.value(value: nudgeRepository!),
        if (sheetSyncRepository != null)
          RepositoryProvider<ISheetSyncRepository>.value(value: sheetSyncRepository!),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider<AuthBloc>(
            create: (ctx) => AuthBloc(
              authRepository: authRepository,
              localCache: localCache,
              beforeSignOut: pushService?.forget,
            )..add(AuthCheckSessionEvent()),
          ),
          BlocProvider<GuestsBloc>(
            create: (ctx) => GuestsBloc(guestRepository: guestRepository),
          ),
          BlocProvider<RankingCubit>(create: (ctx) => RankingCubit(teamRepository)),
          BlocProvider<DashboardCubit>(create: (ctx) => DashboardCubit(teamRepository)),
          BlocProvider<TeamCubit>(create: (ctx) => TeamCubit(teamRepository)),
          if (installPrompt != null) BlocProvider<InstallPromptCubit>.value(value: installPrompt!),
          if (syncSignals != null)
            BlocProvider<SyncStatusCubit>(
              create: (ctx) {
                final connectivity = Connectivity();
                return SyncStatusCubit(
                  signals: syncSignals!,
                  online: connectivity.online,
                  onlineChanges: connectivity.changes,
                );
              },
              lazy: false,
            ),
          BlocProvider<NotificationsCubit>(create: (ctx) => NotificationsCubit(notificationsRepository)),
          BlocProvider<PushCubit>(
            create: (ctx) => PushCubit(
              pushService,
              cache: localCache,
              onForeground: (push) {
                playNotificationSound();
                AppFeedback.success(push.title, push.body);
              },
            ),
          ),
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
