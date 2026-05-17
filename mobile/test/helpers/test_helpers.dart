import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:luharide/providers/auth_provider.dart';
import 'package:luharide/providers/app_language_provider.dart';
import 'package:luharide/services/auth_service.dart';
import 'package:luharide/services/api_service.dart';
import 'package:luharide/core/app_navigator.dart';

void initTestPrefs() {
  SharedPreferences.setMockInitialValues({});
}

Widget makeTestable(Widget child) {
  final apiService = ApiService();
  final authService = AuthService(apiService);

  return MultiProvider(
    providers: [
      ChangeNotifierProvider<AuthProvider>(
        create: (_) => AuthProvider(authService),
      ),
      ChangeNotifierProvider<AppLanguageProvider>(
        create: (_) => AppLanguageProvider(),
      ),
    ],
    child: MaterialApp(
      navigatorKey: navigatorKey,
      home: ScaffoldMessenger(
        child: child,
      ),
    ),
  );
}
