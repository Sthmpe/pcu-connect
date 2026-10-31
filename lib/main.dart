import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/constants/app_colors.dart';
import 'core/network/api_client.dart';
import 'core/storage/local_cache.dart';
import 'data/repositories/auth_repository_impl.dart';
import 'data/repositories/guest_repository_impl.dart';
import 'domain/repositories/i_auth_repository.dart';
import 'domain/repositories/i_guest_repository.dart';
import 'presentation/auth/bloc/auth_bloc.dart';
import 'presentation/auth/bloc/auth_event.dart';
import 'presentation/auth/screens/login_screen.dart';
import 'presentation/guests/bloc/guests_bloc.dart';
import 'presentation/guests/bloc/guests_event.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

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
  final guestRepository = GuestRepositoryImpl(
    apiClient: apiClient,
    authRepository: authRepository,
    localCache: localCache,
  );

  runApp(PCUConnectApp(
    authRepository: authRepository,
    guestRepository: guestRepository,
    localCache: localCache,
  ));
}

class PCUConnectApp extends StatelessWidget {
  final IAuthRepository authRepository;
  final IGuestRepository guestRepository;
  final LocalCache localCache;

  const PCUConnectApp({
    super.key,
    required this.authRepository,
    required this.guestRepository,
    required this.localCache,
  });

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider<IAuthRepository>.value(value: authRepository),
        RepositoryProvider<IGuestRepository>.value(value: guestRepository),
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
            create: (ctx) => GuestsBloc(guestRepository: guestRepository)
              ..add(const LoadGuestsEvent()),
          ),
        ],
        child: ScreenUtilInit(
          // Exact design resolution from PCU_Worker_App.html (390 x 844)
          designSize: const Size(390, 844),
          minTextAdapt: true,
          splitScreenMode: true,
          builder: (context, child) {
            return GetMaterialApp(
              title: 'PCU Connect',
              debugShowCheckedModeBanner: false,
              theme: ThemeData(
                scaffoldBackgroundColor: AppColors.bg,
                primaryColor: AppColors.navy,
                fontFamily: 'Rubik',
                colorScheme: const ColorScheme.light(
                  primary: AppColors.navy,
                  secondary: AppColors.gold,
                  surface: Colors.white,
                ),
              ),
              home: const LoginScreen(),
            );
          },
        ),
      ),
    );
  }
}
