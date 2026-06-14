import 'dart:async';
import 'package:flutter/foundation.dart';
import 'api_service.dart';

class NetworkStatusService extends ChangeNotifier {
  NetworkStatusService._();
  static final NetworkStatusService instance = NetworkStatusService._();

  bool _isOnline = true;
  bool get isOnline => _isOnline;

  Timer? _timer;
  bool _checking = false;

  void startMonitoring() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 15), (_) => check());
  }

  void stopMonitoring() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> check() async {
    if (_checking) return;
    _checking = true;
    try {
      await ApiService().get('/health');
      _setOnline(true);
    } catch (_) {
      _setOnline(false);
    } finally {
      _checking = false;
    }
  }

  void _setOnline(bool value) {
    if (_isOnline != value) {
      _isOnline = value;
      notifyListeners();
    }
  }

  void markOffline() => _setOnline(false);
  void markOnline() => _setOnline(true);
}
