import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:luharide/core/storage/secure_token_storage.dart';
import 'package:luharide/providers/auth_provider.dart';
import 'package:luharide/providers/app_language_provider.dart';
import 'package:luharide/services/auth_service.dart';
import 'package:luharide/services/api_service.dart';
import 'package:luharide/core/app_navigator.dart';

void initTestPrefs() {
  SharedPreferences.setMockInitialValues({});
}

/// In-memory mock for flutter_secure_storage MethodChannel.
/// Also resets singleton migration state for test isolation.
void setupMockSecureStorage() {
  SecureTokenStorage.instance.resetForTesting();
  final store = <String, String>{};
  const channel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');

  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(channel, (MethodCall call) async {
    switch (call.method) {
      case 'read':
        final key = call.arguments['key'] as String;
        return store[key];
      case 'write':
        final key = call.arguments['key'] as String;
        final value = call.arguments['value'] as String;
        store[key] = value;
        return null;
      case 'delete':
        final key = call.arguments['key'] as String;
        store.remove(key);
        return null;
      case 'deleteAll':
        store.clear();
        return null;
      case 'readAll':
        return store;
      case 'containsKey':
        final key = call.arguments['key'] as String;
        return store.containsKey(key) ? 'true' : null;
      default:
        return null;
    }
  });
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
