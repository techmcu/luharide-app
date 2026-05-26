import '../storage/secure_token_storage.dart';

/// Cached auth token for image requests (avoids async on every build).
/// Call [refreshAuthHeadersCache] once after login/logout.
class AuthHeadersSync {
  static String? _cachedToken;

  static Map<String, String>? get headers {
    if (_cachedToken == null || _cachedToken!.isEmpty) return null;
    return {'Authorization': 'Bearer $_cachedToken'};
  }

  static Future<void> refreshAuthHeadersCache() async {
    _cachedToken = await SecureTokenStorage.instance.getAccessToken();
  }
}
