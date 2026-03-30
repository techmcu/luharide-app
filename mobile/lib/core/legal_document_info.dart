/// Shown on Terms screen and signup — bump when legal text changes materially.
class LegalDocumentInfo {
  LegalDocumentInfo._();

  static const String termsVersion = '1.0';
  static const String termsLastUpdated = '30 March 2026';

  static String get termsSummaryLine => 'Terms v$termsVersion · Last updated: $termsLastUpdated';
}
