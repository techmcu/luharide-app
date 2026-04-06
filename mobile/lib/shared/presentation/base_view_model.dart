import 'package:flutter/foundation.dart';

/// Lightweight base for feature ViewModels (ChangeNotifier).
/// Subclasses should call [notifyIfAlive] instead of [notifyListeners] when
/// async work might complete after dispose.
abstract class BaseViewModel extends ChangeNotifier {
  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  void notifyIfAlive() {
    if (!_disposed) notifyListeners();
  }
}
