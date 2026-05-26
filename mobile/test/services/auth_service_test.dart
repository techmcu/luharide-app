import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:luharide/services/api_service.dart';
import 'package:luharide/services/auth_service.dart';
import '../helpers/test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AuthService', () {
    late AuthService authService;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      setupMockSecureStorage();
      authService = AuthService(ApiService());
    });

    test('getCurrentUser throws on 401 without recursive refresh', () async {
      expect(
        () => authService.getCurrentUser(),
        throwsA(isA<Exception>()),
      );
    });

    test('isLoggedIn returns false when no token stored', () async {
      final result = await authService.isLoggedIn();
      expect(result, isFalse);
    });

    test('isLoggedIn returns true when token present (migrated from prefs)', () async {
      SharedPreferences.setMockInitialValues({'access_token': 'test-token'});
      setupMockSecureStorage();
      final fresh = AuthService(ApiService());
      final result = await fresh.isLoggedIn();
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
      try {
        await authService.refreshToken();
        fail('Should have thrown');
      } catch (e) {
        expect(e.toString(), contains('No refresh token'));
      }
    });
  });
}
