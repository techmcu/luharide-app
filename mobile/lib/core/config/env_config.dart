import 'package:flutter/foundation.dart';

class EnvConfig {
  /// Compile-time: `--dart-define=USE_LOCAL_API=true` (recommended with [kDebugMode] check below).
  static const bool _useLocalApiEnv =
      bool.fromEnvironment('USE_LOCAL_API', defaultValue: false);

  /// Host port for local REST + Socket.IO (gateway or monolith — **must match** what you run).
  /// - Monolith `node server.js` → **3000** (default).
  /// - Microservices `npm run dev:stack` → gateway is **3010** → `--dart-define=LOCAL_API_PORT=3010`
  static const int _localApiPort =
      int.fromEnvironment('LOCAL_API_PORT', defaultValue: 3000);

  /// Wins over everything: `--dart-define=API_BASE_URL=http://localhost:3000/api`
  static const String _apiBaseUrlDefine = String.fromEnvironment('API_BASE_URL');

  /// Same for Socket.IO host (no `/api`).
  static const String _socketUrlDefine = String.fromEnvironment('SOCKET_URL');

  static String _trimEndSlashes(String s) =>
      s.replaceAll(RegExp(r'/+$'), '');

  /// REST API base including `/api`. **Not const** — Web vs Android emulator differs for local dev.
  static String get apiBaseUrl {
    if (_apiBaseUrlDefine.isNotEmpty) {
      return _trimEndSlashes(_apiBaseUrlDefine.trim());
    }
    if (kDebugMode && _useLocalApiEnv) {
      // Web: use `localhost` (same as Flutter dev server host) — avoids Chrome Private
      // Network Access blocking `localhost` page → `127.0.0.1` API.
      return 'http://${kIsWeb ? 'localhost' : '10.0.2.2'}:$_localApiPort/api';
    }
    return 'http://76.13.243.157:3000/api';
  }

  /// Socket.IO URL (host:port, no `/api`).
  static String get socketUrl {
    if (_socketUrlDefine.isNotEmpty) {
      return _trimEndSlashes(_socketUrlDefine.trim());
    }
    if (kDebugMode && _useLocalApiEnv) {
      return 'http://${kIsWeb ? 'localhost' : '10.0.2.2'}:$_localApiPort';
    }
    return 'http://76.13.243.157:3000';
  }

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
