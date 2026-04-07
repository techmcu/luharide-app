/// SharedPreferences keys for [SubmittedDocumentsService].
class SubmittedDocumentsCacheKeys {
  SubmittedDocumentsCacheKeys._();

  /// Legacy keys — cleared on load to avoid cross-account bleed.
  static const String legacyJsonKey = 'kyc_submitted_docs_cache_v1';
  static const String legacyAtKey = 'kyc_submitted_docs_cache_v1_at';

  static String jsonKey(String userId) => 'kyc_submitted_docs_v2_$userId';
  static String atKey(String userId) => 'kyc_submitted_docs_v2_at_$userId';

  static const Duration ttl = Duration(minutes: 20);
}
