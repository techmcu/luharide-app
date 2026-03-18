import 'package:flutter/foundation.dart';

class EnvConfig {
  // USE_LOCAL_API sirf debug ke liye; release APK hamesha production URL use karega.
  static const bool _envUseLocalApi =
      bool.fromEnvironment('USE_LOCAL_API', defaultValue: false);

  static bool get _useLocalApi => kDebugMode && _envUseLocalApi;

  // Defaults: production domain (HTTPS). Local debug ke liye dart-define se override karo.
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    // VPS default (can be overridden via dart-define)
    defaultValue: _envUseLocalApi
        ? 'http://10.0.2.2:3000/api'
        : 'http://76.13.243.157:3000/api',
  );
  static const String socketUrl = String.fromEnvironment(
    'SOCKET_URL',
    // VPS default (can be overridden via dart-define)
    defaultValue: _envUseLocalApi
        ? 'http://10.0.2.2:3000'
        : 'http://76.13.243.157:3000',
  );
  
  // Google Maps API Key
  static const String googleMapsApiKey = 'YOUR_GOOGLE_MAPS_API_KEY';
  
  // Firebase Configuration
  // Add Firebase config after Firebase setup
  
  // Auth Token (managed by AuthService)
  static String? authToken;
  
  static Future<void> init() async {
    // Initialize any async configurations here
    // e.g., Firebase, Hive, SharedPreferences, etc.
  }
}
