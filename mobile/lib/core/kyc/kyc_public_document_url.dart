/// Builds a browser-loadable URL for KYC assets (`/uploads/...` or absolute).
class KycPublicDocumentUrl {
  KycPublicDocumentUrl._();

  /// [publicFileBaseUrl] is [EnvConfig.publicFileBaseUrl] (no trailing slash required).
  static String resolve(String relativeOrAbsolute, String publicFileBaseUrl) {
    final u = relativeOrAbsolute.trim();
    if (u.startsWith('http://') || u.startsWith('https://')) return u;
    final base = publicFileBaseUrl.replaceAll(RegExp(r'/+$'), '');
    if (u.startsWith('/')) return '$base$u';
    return '$base/$u';
  }
}
