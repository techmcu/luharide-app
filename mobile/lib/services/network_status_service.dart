import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

/// Tracks connectivity the way Ola/Uber/WhatsApp do — **event-driven, zero polling**.
///
/// We NEVER ping the server on a timer. Online/offline is derived from:
///  1. OS connectivity events ([Connectivity.onConnectivityChanged]) — the device
///     itself pushes wifi/mobile/none changes. No request, no battery drain.
///  2. Real request outcomes (reactive) — [ApiService] calls [markOnline] on any
///     successful response and [markOffline] on a true network error
///     (connection/timeout). So "device has wifi but server unreachable" is still
///     caught — the moment a real call fails, not 15s later by a wasted health ping.
///
/// Net effect: 1 user or 1 crore, the server gets **no** background connectivity
/// traffic. This scales infinitely.
class NetworkStatusService extends ChangeNotifier with WidgetsBindingObserver {
  NetworkStatusService._();
  static final NetworkStatusService instance = NetworkStatusService._();

  bool _isOnline = true;
  bool get isOnline => _isOnline;

  StreamSubscription<List<ConnectivityResult>>? _sub;
  bool _observerRegistered = false;

  void startMonitoring() {
    // Re-check when the app returns to foreground (network may have changed
    // while backgrounded). Guarded so plain unit tests (no binding) don't crash.
    if (!_observerRegistered) {
      try {
        WidgetsBinding.instance.addObserver(this);
        _observerRegistered = true;
      } catch (_) {/* no binding in unit test */}
    }

    // Subscribe to OS connectivity events. Guarded: in unit tests the plugin
    // channel isn't available — we simply skip the subscription, no crash.
    try {
      _sub?.cancel().catchError((_) {});
      _sub = Connectivity().onConnectivityChanged.listen(
        _onConnectivityChanged,
        onError: (_) {/* ignore plugin errors — reactive path still covers us */},
      );
      // Seed the current state once (also guarded).
      Connectivity().checkConnectivity().then(_onConnectivityChanged).catchError((_) {});
    } catch (_) {/* plugin unavailable (unit test) */}
  }

  void stopMonitoring() {
    try {
      _sub?.cancel().catchError((_) {});
    } catch (_) {}
    _sub = null;
    if (_observerRegistered) {
      try {
        WidgetsBinding.instance.removeObserver(this);
      } catch (_) {}
      _observerRegistered = false;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      forceRecheck();
    }
  }

  bool _hasNetwork(List<ConnectivityResult> results) {
    if (results.isEmpty) return false;
    return results.any((r) => r != ConnectivityResult.none);
  }

  void _onConnectivityChanged(List<ConnectivityResult> results) {
    if (_hasNetwork(results)) {
      // Device has a network. Optimistically online — if the SERVER is actually
      // down, the next real API call will flip us back via [markOffline].
      markOnline();
    } else {
      // No interface at all — definitively offline.
      markOffline();
    }
  }

  /// Manual "Retry" / app-resume. Re-reads OS connectivity only — **no server
  /// ping**. If the device has a network we go online; a still-down server is
  /// caught reactively by the next real request.
  Future<void> forceRecheck() async {
    try {
      final results = await Connectivity().checkConnectivity();
      _onConnectivityChanged(results);
    } catch (_) {
      // Plugin unavailable — assume online; reactive path will correct.
      markOnline();
    }
  }

  void _setOnline(bool value) {
    if (_isOnline != value) {
      _isOnline = value;
      notifyListeners();
    }
  }

  /// Called by [ApiService] on a real network failure (connection/timeout).
  void markOffline() => _setOnline(false);

  /// Called by [ApiService] on any successful response, and on connectivity-up.
  void markOnline() => _setOnline(true);
}
