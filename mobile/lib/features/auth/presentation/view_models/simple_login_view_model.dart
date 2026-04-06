import '../../../../shared/presentation/base_view_model.dart';

class SimpleLoginViewModel extends BaseViewModel {
  bool _isLoading = false;
  bool _obscurePassword = true;

  bool get isLoading => _isLoading;
  bool get obscurePassword => _obscurePassword;

  void setLoading(bool value) {
    if (_isLoading == value) return;
    _isLoading = value;
    notifyIfAlive();
  }

  void toggleObscurePassword() {
    _obscurePassword = !_obscurePassword;
    notifyIfAlive();
  }
}
