import 'dart:ui';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'core/theme/app_theme.dart';
import 'core/brand_config.dart';
import 'core/config/env_config.dart';
import 'core/app_navigator.dart';
import 'providers/auth_provider.dart';
import 'providers/app_language_provider.dart';
import 'services/api_service.dart';
import 'services/auth_service.dart';
import 'features/home/presentation/screens/home_screen.dart';
import 'features/landing/presentation/screens/landing_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Web: avoid FlutterError.presentError — it walks the widget inspector and can
  // crash (LegacyJavaScriptObject vs DiagnosticsNode) with HtmlElementView / DOM.
  FlutterError.onError = (FlutterErrorDetails details) {
    if (kIsWeb) {
      debugPrint(details.exceptionAsString());
      if (details.stack != null) debugPrint(details.stack.toString());
    } else {
      FlutterError.presentError(details);
    }
    if (kDebugMode) {
      // ignore: avoid_print
      print('FlutterError: ${details.exceptionAsString()}');
    }
  };
  PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
    if (kDebugMode) {
      // ignore: avoid_print
      print('PlatformDispatcher error: $error\n$stack');
    }
    return true;
  };

  await Firebase.initializeApp();
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
      child: Consumer2<AppLanguageProvider, AuthProvider>(
        builder: (context, langProvider, authProvider, _) {
          final locale = langProvider.locale;
          return MaterialApp(
            navigatorKey: navigatorKey,
            title: BrandConfig.appName,
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            themeMode: ThemeMode.light,
            locale: locale,
            supportedLocales: const [
              Locale('en'),
              Locale('hi'),
            ],
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            home: Builder(
              builder: (context) {
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

