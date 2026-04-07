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

    test('auth paths use /auth prefix', () {
      expect(ApiConstants.sendOTP, '/auth/send-otp');
      expect(ApiConstants.verifyOTP, '/auth/verify-otp');
      expect(ApiConstants.currentUser, '/auth/me');
    });

    test('upload helpers match backend routes', () {
      expect(ApiConstants.uploadDriverDoc, '/uploads/driver-doc');
      expect(ApiConstants.uploadUnionDoc, '/uploads/union-doc');
    });

    test('review URL builders encode ids in path', () {
      expect(ApiConstants.userRatingSummary('u-1'), '/reviews/summary/u-1');
      expect(ApiConstants.rateBooking('b99'), '/bookings/b99/rate');
    });
  });
}
