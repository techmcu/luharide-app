import 'package:flutter/foundation.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/realtime_socket_service.dart';

enum AuthStatus {
  initial,
  loading,
  authenticated,
  unauthenticated,
}

class AuthProvider with ChangeNotifier {
  final AuthService _authService;

  AuthProvider(this._authService) {
    _checkAuthStatus();
  }

  AuthStatus _status = AuthStatus.initial;
  UserModel? _user;
  String? _error;
  bool _isLoading = false;
  bool _isCheckingAuth = false;

  // Getters
  AuthStatus get status => _status;
  UserModel? get user => _user;
  String? get error => _error;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _status == AuthStatus.authenticated;

  /// Check if user is already logged in (runs once on startup; guard prevents concurrent runs)
  Future<void> _checkAuthStatus() async {
    if (_isCheckingAuth) return;
    _isCheckingAuth = true;
    try {
      final isLoggedIn = await _authService.isLoggedIn();
      
      if (isLoggedIn) {
        await _authService.restoreTokenIfCached();
        // 1. Use cached user for instant UI (no API call, minimal memory)
        final cachedUser = await _authService.getSavedUser();
        if (cachedUser != null) {
          _user = cachedUser;
          _status = AuthStatus.authenticated;
          notifyListeners(); // Show immediately
        }
        // 2. Refresh from API in background
        try {
          _user = await _authService.getCurrentUser();
          _status = AuthStatus.authenticated;
        } catch (_) {
          // Refresh may have failed & logged out - verify
          if (!await _authService.isLoggedIn()) {
            _user = null;
            _status = AuthStatus.unauthenticated;
          }
        }
        notifyListeners();
        await RealtimeSocketService.instance.connect();
      } else {
        _status = AuthStatus.unauthenticated;
        await RealtimeSocketService.instance.disconnect();
      }
    } catch (e) {
      _status = AuthStatus.unauthenticated;
      await RealtimeSocketService.instance.disconnect();
    } finally {
      _isCheckingAuth = false;
    }
    notifyListeners();
  }

  /// Send OTP to phone number
  Future<bool> sendOTP(String phone, {String purpose = 'login'}) async {
    try {
      _setLoading(true);
      _error = null;

      await _authService.sendOTP(phone, purpose: purpose);
      
      _setLoading(false);
      return true;
    } catch (e) {
      _error = e.toString().replaceAll('Exception: ', '');
      _setLoading(false);
      notifyListeners();
      return false;
    }
  }

  /// Verify OTP and login/register (phone)
  Future<bool> verifyOTP({
    required String phone,
    required String otp,
    String? name,
    String role = 'passenger',
  }) async {
    try {
      _setLoading(true);
      _error = null;

      final result = await _authService.verifyOTP(
        phone: phone,
        otp: otp,
        name: name,
        role: role,
      );

      _user = result['user'] as UserModel;
      _status = AuthStatus.authenticated;
      await RealtimeSocketService.instance.connect();
      _setLoading(false);
      return true;
    } catch (e) {
      _error = e.toString().replaceAll('Exception: ', '');
      _setLoading(false);
      notifyListeners();
      return false;
    }
  }

  /// Send OTP to email (for signup)
  Future<bool> sendOTPByEmail(String email, {String purpose = 'registration'}) async {
    try {
      _setLoading(true);
      _error = null;
      await _authService.sendOTPByEmail(email, purpose: purpose);
      _setLoading(false);
      return true;
    } catch (e) {
      _error = e.toString().replaceAll('Exception: ', '');
      _setLoading(false);
      notifyListeners();
      return false;
    }
  }

  /// Verify email OTP and sign up / login (name + password required for new user signup)
  Future<bool> verifyOTPByEmail({
    required String email,
    required String otp,
    required String name,
    required String password,
    String role = 'passenger',
  }) async {
    try {
      _setLoading(true);
      _error = null;

      final result = await _authService.verifyOTPByEmail(
        email: email,
        otp: otp,
        name: name,
        role: role,
        password: password,
      );

      _user = result['user'] as UserModel;
      _status = AuthStatus.authenticated;
      await RealtimeSocketService.instance.connect();
      _setLoading(false);
      return true;
    } catch (e) {
      _error = e.toString().replaceAll('Exception: ', '');
      _setLoading(false);
      notifyListeners();
      return false;
    }
  }

  /// Logout user
  Future<void> logout() async {
    try {
      _setLoading(true);
      await RealtimeSocketService.instance.disconnect();
      await _authService.logout();
      
      _user = null;
      _status = AuthStatus.unauthenticated;
      _error = null;
      
      _setLoading(false);
      notifyListeners(); // Notify UI to rebuild
    } catch (e) {
      _error = e.toString();
      _user = null;
      _status = AuthStatus.unauthenticated;
      _setLoading(false);
      notifyListeners();
    }
  }

  /// Update user profile
  Future<bool> updateProfile({
    String? name,
    String? phone,
    String? email,
    String? whatsappNumber,
    String? profileImageUrl,
    String? bio,
    String? luggageAllowancePerPassenger,
  }) async {
    try {
      _setLoading(true);
      _error = null;

      _user = await _authService.updateProfile(
        name: name,
        phone: phone,
        email: email,
        whatsappNumber: whatsappNumber,
        profileImageUrl: profileImageUrl,
        bio: bio,
        luggageAllowancePerPassenger: luggageAllowancePerPassenger,
      );
      
      _setLoading(false);
      return true;
    } catch (e) {
      _error = e.toString().replaceAll('Exception: ', '');
      _setLoading(false);
      notifyListeners();
      return false;
    }
  }

  /// Change password (email/password users)
  Future<bool> changePassword({
    required String current,
    required String newPassword,
  }) async {
    try {
      _setLoading(true);
      _error = null;

      final ok = await _authService.changePassword(
        currentPassword: current,
        newPassword: newPassword,
      );

      _setLoading(false);
      return ok;
    } catch (e) {
      _error = e.toString().replaceAll('Exception: ', '');
      _setLoading(false);
      notifyListeners();
      return false;
    }
  }

  /// Request password reset (send OTP to email)
  Future<bool> requestPasswordReset(String email) async {
    try {
      _setLoading(true);
      _error = null;
      final ok = await _authService.requestPasswordReset(email: email);
      _setLoading(false);
      return ok;
    } catch (e) {
      _error = e.toString().replaceAll('Exception: ', '');
      _setLoading(false);
      notifyListeners();
      return false;
    }
  }

  /// Reset password using email + OTP
  Future<bool> resetPasswordWithEmailOtp({
    required String email,
    required String otp,
    required String newPassword,
  }) async {
    try {
      _setLoading(true);
      _error = null;
      final ok = await _authService.resetPasswordWithEmailOtp(
        email: email,
        otp: otp,
        newPassword: newPassword,
      );
      _setLoading(false);
      return ok;
    } catch (e) {
      _error = e.toString().replaceAll('Exception: ', '');
      _setLoading(false);
      notifyListeners();
      return false;
    }
  }

  /// Refresh current user data
  Future<void> refreshUser() async {
    try {
      _user = await _authService.getCurrentUser();
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  /// Set loading state
  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  /// Clear error
  void clearError() {
    _error = null;
    notifyListeners();
  }

  /// Simple Login - Email + Password
  Future<bool> simpleLogin({
    required String email,
    required String password,
  }) async {
    try {
      _setLoading(true);
      _error = null;

      final result = await _authService.simpleLogin(
        email: email,
        password: password,
      );

      _user = result['user'] as UserModel;
      _status = AuthStatus.authenticated;
      _error = null;
      await RealtimeSocketService.instance.connect();
      _setLoading(false);
      notifyListeners(); // Ensure UI rebuilds
      return true;
    } catch (e) {
      _error = e.toString().replaceAll('Exception: ', '');
      _user = null;
      _status = AuthStatus.unauthenticated;
      _setLoading(false);
      notifyListeners();
      return false;
    }
  }

  /// Create demo accounts (does not require auth)
  Future<bool> createDemoAccounts() async {
    try {
      return await _authService.createDemoAccounts();
    } catch (_) {
      return false;
    }
  }

  /// Simple Signup - Email + Password
  Future<bool> simpleSignup({
    required String email,
    required String password,
    required String name,
    String role = 'passenger',
  }) async {
    try {
      _setLoading(true);
      _error = null;

      final result = await _authService.simpleSignup(
        email: email,
        password: password,
        name: name,
        role: role,
      );

      _user = result['user'] as UserModel;
      _status = AuthStatus.authenticated;
      _error = null;
      await RealtimeSocketService.instance.connect();
      _setLoading(false);
      notifyListeners(); // Ensure UI rebuilds
      return true;
    } catch (e) {
      _error = e.toString().replaceAll('Exception: ', '');
      _user = null;
      _status = AuthStatus.unauthenticated;
      _setLoading(false);
      notifyListeners();
      return false;
    }
  }
}
