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
import 'services/push_notification_service.dart'
    if (dart.library.html) 'services/push_notification_service_web.dart';
import 'core/routes.dart';
import 'features/home/presentation/screens/home_screen.dart';
import 'features/landing/presentation/screens/landing_screen.dart';
import 'services/in_app_update_service.dart';
import 'services/network_status_service.dart';
import 'widgets/offline_banner.dart';

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

  if (!kIsWeb) {
    await Firebase.initializeApp();
    await PushNotificationService.instance.initialize();
  }
  await EnvConfig.init();

  InAppUpdateService.instance.checkForUpdate();
  NetworkStatusService.instance.startMonitoring();

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
            onGenerateRoute: onGenerateRoute,
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
            builder: (context, child) => Column(
              children: [
                const OfflineBanner(),
                Expanded(child: child!),
              ],
            ),
            home: Builder(
                builder: (context) {
                  if (authProvider.status == AuthStatus.initial ||
                      !langProvider.isInitialized) {
                    return const Scaffold(
                      body: Center(
                        child: CircularProgressIndicator(),
                      ),
                    );
                  }

                  if (authProvider.isAuthenticated) {
                    return const HomeScreen();
                  }

                  if (authProvider.suspensionMessage != null) {
                    final msg = authProvider.suspensionMessage!;
                    authProvider.clearSuspensionMessage();
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      final nav = navigatorKey.currentContext;
                      if (nav != null) {
                        showDialog(
                          context: nav,
                          barrierDismissible: false,
                          builder: (ctx) => AlertDialog(
                            icon: Icon(Icons.block, color: Colors.red.shade600, size: 48),
                            title: const Text('Account Suspended'),
                            content: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(msg, textAlign: TextAlign.center,
                                    style: const TextStyle(fontSize: 14)),
                                const SizedBox(height: 16),
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.shade50,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(Icons.email_outlined, size: 20,
                                          color: Colors.blue.shade700),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(BrandConfig.supportEmail,
                                          style: TextStyle(fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.blue.shade700)),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            actions: [
                              FilledButton(
                                onPressed: () => Navigator.pop(ctx),
                                child: const Text('OK'),
                              ),
                            ],
                          ),
                        );
                      }
                    });
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

