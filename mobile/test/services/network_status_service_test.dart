// Platform-interface packages are imported directly only to mock connectivity
// in tests (they are transitive deps of connectivity_plus).
// ignore_for_file: depend_on_referenced_packages
import 'package:flutter_test/flutter_test.dart';
import 'package:connectivity_plus_platform_interface/connectivity_plus_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:luharide/services/network_status_service.dart';

/// Fake connectivity platform so start/stopMonitoring don't touch real plugin
/// channels in unit tests. onConnectivityChanged is an empty stream (no events)
/// so it never flips the service state during these API-level tests.
class _FakeConnectivity extends ConnectivityPlatform with MockPlatformInterfaceMixin {
  @override
  Future<List<ConnectivityResult>> checkConnectivity() async => [ConnectivityResult.wifi];

  @override
  Stream<List<ConnectivityResult>> get onConnectivityChanged =>
      const Stream<List<ConnectivityResult>>.empty();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    ConnectivityPlatform.instance = _FakeConnectivity();
    NetworkStatusService.instance.markOnline(); // reset to known state
  });

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
      void listener() => notified = true;
      service.addListener(listener);

      service.markOffline();
      expect(service.isOnline, false);
      expect(notified, true);

      service.removeListener(listener);
      service.markOnline();
    });

    test('markOnline sets isOnline to true and notifies', () {
      final service = NetworkStatusService.instance;
      service.markOffline();

      bool notified = false;
      void listener() => notified = true;
      service.addListener(listener);

      service.markOnline();
      expect(service.isOnline, true);
      expect(notified, true);

      service.removeListener(listener);
    });

    test('does not notify when value unchanged', () {
      final service = NetworkStatusService.instance;
      service.markOnline();

      bool notified = false;
      void listener() => notified = true;
      service.addListener(listener);

      service.markOnline();
      expect(notified, false);

      service.removeListener(listener);
    });

    test('start then stop monitoring does not crash', () {
      final service = NetworkStatusService.instance;
      service.startMonitoring();
      service.stopMonitoring();
      // No assertion — just verifying no crash (event-driven, no polling timer).
    });
  });
}
