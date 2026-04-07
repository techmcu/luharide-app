import 'package:flutter_test/flutter_test.dart';
import 'package:luharide/core/constants/api_constants.dart';

void main() {
  group('ApiConstants', () {
    test('submittedDocuments path is stable for KYC client', () {
      expect(ApiConstants.submittedDocuments, '/kyc/submitted-documents');
    });

    test('driverVerification path', () {
      expect(ApiConstants.driverVerification, '/driver-verification');
    });
  });
}
