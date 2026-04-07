import 'package:flutter_test/flutter_test.dart';
import 'package:luharide/core/kyc/kyc_public_document_url.dart';

void main() {
  group('KycPublicDocumentUrl.resolve', () {
    const base = 'https://api.example.com';

    test('passes through http(s)', () {
      expect(
        KycPublicDocumentUrl.resolve('https://cdn/x/y.jpg', base),
        'https://cdn/x/y.jpg',
      );
      expect(
        KycPublicDocumentUrl.resolve('http://localhost/uploads/a', 'http://x'),
        'http://localhost/uploads/a',
      );
    });

    test('joins absolute path to base', () {
      expect(
        KycPublicDocumentUrl.resolve('/uploads/driver/x.pdf', base),
        'https://api.example.com/uploads/driver/x.pdf',
      );
    });

    test('joins relative path and strips base slashes', () {
      expect(
        KycPublicDocumentUrl.resolve('uploads/u/x.png', 'https://h.com/'),
        'https://h.com/uploads/u/x.png',
      );
    });

    test('trims storage path', () {
      expect(
        KycPublicDocumentUrl.resolve('  /uploads/a  ', base),
        'https://api.example.com/uploads/a',
      );
    });
  });
}
