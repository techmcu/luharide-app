import 'dart:async';
import 'package:flutter/widgets.dart';
import 'api_service.dart';

/// Tracks connectivity by pinging the backend.
///
/// Design notes (why it behaves the way it does):
/// - A SINGLE failed ping does NOT flip the app offline. We require
///   [_failuresBeforeOffline] consecutive failures so a momentary blip
///   (e.g. the network waking up when the app is resumed) doesn't flash
///   the red banner.
/// - On app resume ([AppLifecycleState.resumed]) we immediately re-check
///   with a few quick retries, so the user never has to tap "Retry" manually.
/// - Any successful ping instantly marks online and resets the failure count.
class NetworkStatusService extends ChangeNotifier with WidgetsBindingObserver {
  NetworkStatusService._();
  static final NetworkStatusService instance = NetworkStatusService._();

  bool _isOnline = true;
  bool get isOnline => _isOnline;

  Timer? _timer;
  bool _checking = false;
  int _consecutiveFailures = 0;
  bool _observerRegistered = false;

  /// Number of back-to-back failed pings before we show "offline".
  /// 1 was too trigger-happy (every transient blip flashed the banner).
  static const int _failuresBeforeOffline = 2;

  void startMonitoring() {
    _timer?.cancel();
    // Auto re-check when the app comes back to foreground. Guarded so plain
    // unit tests (no WidgetsBinding) don't crash.
    if (!_observerRegistered) {
      try {
        WidgetsBinding.instance.addObserver(this);
        _observerRegistered = true;
      } catch (_) {
        // Binding not initialized (e.g. unit test) — periodic timer still works.
      }
    }
    _timer = Timer.periodic(const Duration(seconds: 15), (_) => check());
  }

  void stopMonitoring() {
    _timer?.cancel();
    _timer = null;
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
      // App reopened — give the network a moment to wake, then auto-recover.
      forceRecheck();
    }
  }

  /// Periodic / passive check. Debounced: only flips offline after repeated fails.
  Future<void> check() async {
    if (_checking) return;
    _checking = true;
    try {
      _applyResult(await _ping());
    } finally {
      _checking = false;
    }
  }

  /// Optimistic re-check used by manual "Retry" and on app resume.
  /// Tries a few times with a short delay before giving up, so a network
  /// that is still waking up gets a fair chance — no manual retry needed.
  Future<void> forceRecheck() async {
    if (_checking) return;
    _checking = true;
    try {
      for (var attempt = 0; attempt < 3; attempt++) {
        if (await _ping()) {
          _applyResult(true);
          return;
        }
        await Future<void>.delayed(const Duration(milliseconds: 800));
      }
      _applyResult(false);
    } finally {
      _checking = false;
    }
  }

  Future<bool> _ping() async {
    try {
      await ApiService().get('/health');
      return true;
    } catch (_) {
      return false;
    }
  }

  void _applyResult(bool ok) {
    if (ok) {
      _consecutiveFailures = 0;
      _setOnline(true);
    } else {
      _consecutiveFailures++;
      if (_consecutiveFailures >= _failuresBeforeOffline) {
        _setOnline(false);
      }
    }
  }

  void _setOnline(bool value) {
    if (_isOnline != value) {
      _isOnline = value;
      notifyListeners();
    }
  }

  void markOffline() => _setOnline(false);

  void markOnline() {
    _consecutiveFailures = 0;
    _setOnline(true);
  }
}
