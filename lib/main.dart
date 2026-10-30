import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'core/constants/app_colors.dart';
import 'core/network/api_client.dart';
import 'data/repositories/auth_repository_impl.dart';
import 'data/repositories/guest_repository_impl.dart';
import 'domain/repositories/i_auth_repository.dart';
import 'domain/repositories/i_guest_repository.dart';
import 'presentation/auth/bloc/auth_bloc.dart';
import 'presentation/auth/bloc/auth_event.dart';
import 'presentation/auth/screens/login_screen.dart';
import 'presentation/guests/bloc/guests_bloc.dart';
import 'presentation/guests/bloc/guests_event.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Test Apps Script Web App URL (Configurable via backend deployment)
  const appsScriptUrl =
      'https://script.google.com/macros/s/AKfycbytest/exec';

  final apiClient = ApiClient(baseUrl: appsScriptUrl);
  final authRepository = AuthRepositoryImpl(apiClient: apiClient);
  final guestRepository = GuestRepositoryImpl(
    apiClient: apiClient,
    authRepository: authRepository,
  );

  runApp(PCUConnectApp(
    authRepository: authRepository,
    guestRepository: guestRepository,
  ));
}

class PCUConnectApp extends StatelessWidget {
  final IAuthRepository authRepository;
  final IGuestRepository guestRepository;

  const PCUConnectApp({
    super.key,
    required this.authRepository,
    required this.guestRepository,
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
            create: (ctx) => AuthBloc(authRepository: authRepository)
              ..add(AuthCheckSessionEvent()),
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
