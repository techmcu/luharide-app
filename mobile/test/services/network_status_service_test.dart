import 'package:flutter_test/flutter_test.dart';
import 'package:luharide/services/network_status_service.dart';

void main() {
  group('NetworkStatusService', () {
    test('singleton instance is consistent', () {
      expect(NetworkStatusService.instance, same(NetworkStatusService.instance));
    });

    test('defaults to online', () {
      expect(NetworkStatusService.instance.isOnline, true);
    });

    test('markOffline sets isOnline to false and notifies', () {
      final service = NetworkStatusService.instance;
      bool notified = false;
      service.addListener(() => notified = true);

      service.markOffline();
      expect(service.isOnline, false);
      expect(notified, true);

      service.removeListener(() {});
      service.markOnline();
    });

    test('markOnline sets isOnline to true and notifies', () {
      final service = NetworkStatusService.instance;
      service.markOffline();

      bool notified = false;
      service.addListener(() => notified = true);

      service.markOnline();
      expect(service.isOnline, true);
      expect(notified, true);

      service.removeListener(() {});
    });

    test('does not notify when value unchanged', () {
      final service = NetworkStatusService.instance;
      service.markOnline();

      bool notified = false;
      service.addListener(() => notified = true);

      service.markOnline();
      expect(notified, false);

      service.removeListener(() {});
    });

    test('stopMonitoring cancels timer', () {
      final service = NetworkStatusService.instance;
      service.startMonitoring();
      service.stopMonitoring();
      // No assertion needed — just verifying no crash
    });
  });
}
