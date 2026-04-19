import '../config/env_config.dart';

/// Authenticated KYC file streaming via API (same origin as `/api` — reliable on web).
///
/// Prefer this over raw `https://host/uploads/...` for previews: JWT + normal API CORS,
/// and optional `Cache-Control: private` on the gateway.
class KycDocumentStreamUrl {
  KycDocumentStreamUrl._();

  /// [storageUrl] may be `/uploads/...` or full `https://.../uploads/...`.
  static String build(String storageUrl, {required bool isAdmin}) {
    var path = storageUrl.trim();
    if (path.startsWith('http://') || path.startsWith('https://')) {
      path = Uri.parse(path).path;
    }
    if (!path.startsWith('/')) {
      if (path.startsWith('uploads/')) path = '/$path';
    }
    final base = EnvConfig.apiBaseUrl;
    final route = isAdmin ? '/admin/document-file' : '/kyc/document-file';
    return '$base$route?path=${Uri.encodeQueryComponent(path)}';
  }
}
