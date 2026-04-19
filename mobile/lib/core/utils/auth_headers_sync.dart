import 'package:shared_preferences/shared_preferences.dart';

/// Cached auth token for image requests (avoids async on every build).
/// Call [refreshAuthHeadersCache] once after login/logout.
class AuthHeadersSync {
  static String? _cachedToken;

  static Map<String, String>? get headers {
    if (_cachedToken == null || _cachedToken!.isEmpty) return null;
    return {'Authorization': 'Bearer $_cachedToken'};
  }

  static Future<void> refreshAuthHeadersCache() async {
    final p = await SharedPreferences.getInstance();
    _cachedToken = p.getString('access_token');
  }
}
