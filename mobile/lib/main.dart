import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/theme/app_theme.dart';
import 'core/config/env_config.dart';
import 'core/app_navigator.dart';
import 'core/localization/app_localizations.dart';
import 'providers/auth_provider.dart';
import 'providers/app_language_provider.dart';
import 'services/api_service.dart';
import 'services/auth_service.dart';
import 'screens/auth/simple_login_screen.dart';
import 'screens/auth/simple_signup_screen.dart';
import 'screens/home/home_screen.dart';
import 'screens/landing/landing_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await EnvConfig.init();

  // Single instance for app lifecycle (stable, no recreate on rebuild)
  final apiService = ApiService();
  final authService = AuthService(apiService);

  runApp(LuhaRideApp(
    authService: authService,
  ));
}

class LuhaRideApp extends StatelessWidget {
  final AuthService authService;

  const LuhaRideApp({super.key, required this.authService});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => AuthProvider(authService),
        ),
        ChangeNotifierProvider(
          create: (_) => AppLanguageProvider(),
        ),
      ],
      child: Consumer<AppLanguageProvider>(
        builder: (context, langProvider, _) {
          final locale = langProvider.locale;
          return MaterialApp(
            navigatorKey: navigatorKey,
            title: 'LuhaRide',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: ThemeMode.light,
            locale: locale,
            supportedLocales: const [
              Locale('en'),
              Locale('hi'),
            ],
            home: Consumer<AuthProvider>(
              builder: (context, authProvider, _) {
                // Show loading while checking auth status
                if (authProvider.status == AuthStatus.initial ||
                    !langProvider.isInitialized) {
                  return const Scaffold(
                    body: Center(
                      child: CircularProgressIndicator(),
                    ),
                  );
                }

                // Navigate based on auth status
                if (authProvider.isAuthenticated) {
                  return const HomeScreen();
                }

                return const LandingScreen();
              },
            ),
          );
        },
      ),
    );
  }
}

