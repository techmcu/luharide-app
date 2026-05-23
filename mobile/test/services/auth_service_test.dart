import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:luharide/services/api_service.dart';
import 'package:luharide/services/auth_service.dart';

void main() {
  group('AuthService', () {
    late AuthService authService;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      authService = AuthService(ApiService());
    });

    test('getCurrentUser throws on 401 without recursive refresh', () async {
      // No token set — API call will fail with 401.
      // Old code: getCurrentUser catches 401 → calls refreshToken() → calls getCurrentUser() again (recursive).
      // New code: getCurrentUser lets the interceptor handle 401, throws a clean exception.
      //
      // We verify it throws a single exception, not a stack overflow from recursion.
      expect(
        () => authService.getCurrentUser(),
        throwsA(isA<Exception>()),
      );
    });

    test('isLoggedIn returns false when no token stored', () async {
      final result = await authService.isLoggedIn();
      expect(result, isFalse);
    });

    test('isLoggedIn returns true when token present', () async {
      SharedPreferences.setMockInitialValues({'access_token': 'test-token'});
      final result = await authService.isLoggedIn();
      expect(result, isTrue);
    });

    test('getSavedUser returns null when no data stored', () async {
      final user = await authService.getSavedUser();
      expect(user, isNull);
    });

    test('getSavedUser handles corrupted JSON gracefully', () async {
      SharedPreferences.setMockInitialValues({'user_data': 'not-valid-json'});
      final user = await authService.getSavedUser();
      expect(user, isNull);
    });

    test('refreshToken calls logout and rethrows when no refresh token', () async {
      // No refresh token stored — should throw, not recurse
      try {
        await authService.refreshToken();
        fail('Should have thrown');
      } catch (e) {
        expect(e.toString(), contains('No refresh token'));
      }
    });
  });
}
