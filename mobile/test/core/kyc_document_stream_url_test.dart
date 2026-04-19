import 'package:flutter_test/flutter_test.dart';
import 'package:luharide/core/kyc/kyc_document_stream_url.dart';

void main() {
  test('build owner route encodes path', () {
    final u = KycDocumentStreamUrl.build('/uploads/driver-docs/a.jpg', isAdmin: false);
    expect(u.contains('/kyc/document-file'), isTrue);
    expect(u.contains('path='), isTrue);
  });

  test('build admin route', () {
    final u = KycDocumentStreamUrl.build('/uploads/union-merged/x.pdf', isAdmin: true);
    expect(u.contains('/admin/document-file'), isTrue);
  });

  test('strips https host to pathname', () {
    final u = KycDocumentStreamUrl.build(
      'https://luharide.cloud/uploads/driver-docs/z.png',
      isAdmin: false,
    );
    expect(u.contains('path='), isTrue);
    expect(u.contains('driver-docs'), isTrue);
  });
}
