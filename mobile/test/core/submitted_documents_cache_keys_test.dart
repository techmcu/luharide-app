import 'package:flutter_test/flutter_test.dart';
import 'package:luharide/core/kyc/submitted_documents_cache_keys.dart';

void main() {
  group('SubmittedDocumentsCacheKeys', () {
    test('keys are scoped per user id', () {
      expect(
        SubmittedDocumentsCacheKeys.jsonKey('user-a'),
        isNot(SubmittedDocumentsCacheKeys.jsonKey('user-b')),
      );
      expect(SubmittedDocumentsCacheKeys.jsonKey('u1'), contains('u1'));
      expect(SubmittedDocumentsCacheKeys.atKey('u1'), contains('u1'));
    });

    test('legacy keys stay stable for migration cleanup', () {
      expect(SubmittedDocumentsCacheKeys.legacyJsonKey, 'kyc_submitted_docs_cache_v1');
      expect(SubmittedDocumentsCacheKeys.legacyAtKey, 'kyc_submitted_docs_cache_v1_at');
    });

    test('ttl matches service contract', () {
      expect(SubmittedDocumentsCacheKeys.ttl.inMinutes, 20);
    });
  });
}
