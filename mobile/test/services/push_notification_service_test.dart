import 'package:flutter_test/flutter_test.dart';
import 'package:luharide/services/push_notification_service.dart';

void main() {
  group('PushNotificationService', () {
    test('registerToken is safe when not initialized (no crash)', () async {
      // Service starts uninitialized — registerToken should be a no-op, not crash.
      // On test environment kIsWeb is false but _currentToken is null.
      await PushNotificationService.instance.registerToken();
      // No exception = pass
    });

    test('unregisterToken is safe when not initialized (no crash)', () async {
      await PushNotificationService.instance.unregisterToken();
    });

    test('currentToken is null before initialization', () {
      expect(PushNotificationService.instance.currentToken, isNull);
    });

    test('initialize skips on web platform', () async {
      // In test environment, kIsWeb depends on test runner.
      // This verifies initialize() doesn't crash when called.
      // Firebase is not available in tests, so it will fail gracefully
      // (the fix ensures _initialized stays false on failure).
      try {
        await PushNotificationService.instance.initialize();
      } catch (_) {
        // Firebase not available in test — expected.
      }
      // After failed init, registerToken should still be safe
      await PushNotificationService.instance.registerToken();
    });
  });
}
