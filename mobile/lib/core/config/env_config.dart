import 'package:flutter/foundation.dart';

/// API hosts for REST + Socket.IO. Production should use HTTPS + domain, e.g.:
/// `--dart-define=API_BASE_URL=https://api.example.com/api --dart-define=SOCKET_URL=https://api.example.com`
///
/// Version label in Help → About:
/// - Default shows `Beta` after `0.9.0 (1)`.
/// - Store / stable: `--dart-define=STABLE_RELEASE=true`
/// - Custom tag: `--dart-define=VERSION_CHANNEL=Preview` (ignored if STABLE_RELEASE=true)
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

  /// Play / public release: `--dart-define=STABLE_RELEASE=true` hides channel label next to version.
  static const bool _stableRelease =
      bool.fromEnvironment('STABLE_RELEASE', defaultValue: false);

  /// Shown next to app version in Help (e.g. Beta). Ignored when [_stableRelease] is true.
  static const String _versionChannel =
      String.fromEnvironment('VERSION_CHANNEL', defaultValue: 'Beta');

  static String _trimEndSlashes(String s) =>
      s.replaceAll(RegExp(r'/+$'), '');

  /// Public API when no `--dart-define=API_BASE_URL=...` (release APK + `flutter build web`).
  /// Override for self-hosted: `--dart-define=API_BASE_URL=https://your-host/api`
  static const String _productionApiBase = 'https://api.luharide.cloud/api';

  /// Socket host (no `/api`) — must match gateway/nginx TLS host.
  static const String _productionSocket = 'https://api.luharide.cloud';

  /// REST API base including `/api`. **Not const** — Web vs Android emulator differs for local dev.
  static String get apiBaseUrl {
    if (_apiBaseUrlDefine.isNotEmpty) {
      return _trimEndSlashes(_apiBaseUrlDefine.trim());
    }
    if (kDebugMode && _useLocalApiEnv) {
      // Web: **127.0.0.1** — Windows par `localhost` → ::1 vs Node IPv4 mismatch fix.
      return 'http://${kIsWeb ? '127.0.0.1' : '10.0.2.2'}:$_localApiPort/api';
    }
    return _productionApiBase;
  }

  /// Socket.IO URL (host:port, no `/api`).
  static String get socketUrl {
    if (_socketUrlDefine.isNotEmpty) {
      return _trimEndSlashes(_socketUrlDefine.trim());
    }
    if (kDebugMode && _useLocalApiEnv) {
      return 'http://${kIsWeb ? '127.0.0.1' : '10.0.2.2'}:$_localApiPort';
    }
    return _productionSocket;
  }

  /// Non-empty when this build should show a channel tag after `version (build)` in About.
  static String get versionDisplaySuffix {
    if (_stableRelease) return '';
    final c = _versionChannel.trim();
    return c;
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
