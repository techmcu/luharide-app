import 'dart:async';

import 'package:flutter/foundation.dart';
import '../core/utils/api_error_messages.dart';
import '../core/utils/auth_headers_sync.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/firebase_auth_service.dart';
import '../services/realtime_socket_service.dart';
import '../services/push_notification_service.dart'
    if (dart.library.html) '../services/push_notification_service_web.dart';
import '../services/review_cache_store.dart';
import '../services/review_service.dart';
import '../services/submitted_documents_service.dart';

enum AuthStatus {
  initial,
  loading,
  authenticated,
  unauthenticated,
}

class AuthProvider with ChangeNotifier {
  final AuthService _authService;
  late final FirebaseAuthService _firebaseAuthService;
  StreamSubscription<void>? _tokenRefreshSub;
  StreamSubscription<void>? _sessionLostSub;
  StreamSubscription<String>? _suspendedSub;

  AuthProvider(this._authService) {
    _firebaseAuthService = FirebaseAuthService(_authService.apiService);
    _listenToAuthEvents();
    _checkAuthStatus();
  }

  AuthStatus _status = AuthStatus.initial;
  UserModel? _user;
  String? _error;
  String? _suspensionMessage;
  bool _isLoading = false;
  bool _isCheckingAuth = false;

  // Getters
  AuthStatus get status => _status;
  UserModel? get user => _user;
  String? get error => _error;
  String? get suspensionMessage => _suspensionMessage;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _status == AuthStatus.authenticated;

  void _listenToAuthEvents() {
    final api = _authService.apiService;
    _tokenRefreshSub = api.onTokenRefreshed.listen((_) {
      _syncUserAfterTokenRefresh();
    });
    _sessionLostSub = api.onAuthSessionLost.listen((_) {
      if (_status == AuthStatus.authenticated) {
        _user = null;
        _status = AuthStatus.unauthenticated;
        _error = null;
        unawaited(RealtimeSocketService.instance.disconnect());
        unawaited(AuthHeadersSync.refreshAuthHeadersCache());
        notifyListeners();
      }
    });
    _suspendedSub = api.onAccountSuspended.listen((msg) {
      _user = null;
      _status = AuthStatus.unauthenticated;
      _suspensionMessage = msg;
      _error = null;
      unawaited(RealtimeSocketService.instance.disconnect());
      unawaited(AuthHeadersSync.refreshAuthHeadersCache());
      notifyListeners();
    });
  }

  Future<void> _syncUserAfterTokenRefresh() async {
    if (_status != AuthStatus.authenticated) return;
    try {
      final fresh = await _authService.getCurrentUser(retriable: false)
          .timeout(const Duration(seconds: 8));
      if (_status == AuthStatus.authenticated) {
        _user = fresh;
        unawaited(AuthHeadersSync.refreshAuthHeadersCache());
        notifyListeners();
      }
    } catch (_) {}
  }

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
        // 2. Refresh from API in background (with timeout so startup never stalls)
        try {
          _user = await _authService.getCurrentUser()
              .timeout(const Duration(seconds: 10));
          _status = AuthStatus.authenticated;
        } catch (_) {
          if (!await _authService.isLoggedIn()) {
            _user = null;
            _status = AuthStatus.unauthenticated;
          }
        }
        notifyListeners();
        await RealtimeSocketService.instance.connect()
            .timeout(const Duration(seconds: 5))
            .catchError((_) {});
        unawaited(AuthHeadersSync.refreshAuthHeadersCache());
        unawaited(PushNotificationService.instance.registerToken());
        final uid = _user?.id;
        if (uid != null && uid.isNotEmpty) {
          unawaited(ReviewService.refreshFingerprintAfterLogin(uid));
        }
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
      _error = userFacingAuthError(e);
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
      unawaited(AuthHeadersSync.refreshAuthHeadersCache());
      unawaited(PushNotificationService.instance.registerToken());
      final uid = _user?.id;
      if (uid != null && uid.isNotEmpty) {
        unawaited(ReviewService.refreshFingerprintAfterLogin(uid));
      }
      _setLoading(false);
      return true;
    } catch (e) {
      _error = userFacingAuthError(e);
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
      _error = userFacingAuthError(e);
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
      unawaited(AuthHeadersSync.refreshAuthHeadersCache());
      unawaited(PushNotificationService.instance.registerToken());
      final uid = _user?.id;
      if (uid != null && uid.isNotEmpty) {
        unawaited(ReviewService.refreshFingerprintAfterLogin(uid));
      }
      _setLoading(false);
      return true;
    } catch (e) {
      _error = userFacingAuthError(e);
      _setLoading(false);
      notifyListeners();
      return false;
    }
  }

  /// Google Sign-In (one-tap)
  Future<bool> signInWithGoogle({String role = 'passenger'}) async {
    try {
      _setLoading(true);
      _error = null;

      final result = await _firebaseAuthService.signInWithGoogle(role: role);

      _user = result['user'] as UserModel;
      _status = AuthStatus.authenticated;
      await RealtimeSocketService.instance.connect();
      unawaited(AuthHeadersSync.refreshAuthHeadersCache());
      unawaited(PushNotificationService.instance.registerToken());
      final uid = _user?.id;
      if (uid != null && uid.isNotEmpty) {
        unawaited(ReviewService.refreshFingerprintAfterLogin(uid));
      }
      _setLoading(false);
      return true;
    } on AccountSuspendedException catch (e) {
      _suspensionMessage = e.message;
      _error = null;
      _user = null;
      _status = AuthStatus.unauthenticated;
      _setLoading(false);
      notifyListeners();
      return false;
    } catch (e) {
      _error = userFacingAuthError(e);
      _setLoading(false);
      notifyListeners();
      return false;
    }
  }

  /// Firebase Email Link: send sign-in link
  Future<bool> sendEmailLink(String email) async {
    try {
      _setLoading(true);
      _error = null;
      await _firebaseAuthService.sendSignInLink(email: email);
      _setLoading(false);
      return true;
    } catch (e) {
      _error = userFacingAuthError(e);
      _setLoading(false);
      notifyListeners();
      return false;
    }
  }

  /// Firebase Email Link: verify and sign in
  Future<bool> verifyEmailLink({
    required String emailLink,
    String? name,
    String role = 'passenger',
  }) async {
    try {
      _setLoading(true);
      _error = null;

      final result = await _firebaseAuthService.verifyEmailLink(
        emailLink: emailLink,
        name: name,
        role: role,
      );

      _user = result['user'] as UserModel;
      _status = AuthStatus.authenticated;
      await RealtimeSocketService.instance.connect();
      unawaited(AuthHeadersSync.refreshAuthHeadersCache());
      unawaited(PushNotificationService.instance.registerToken());
      final uid = _user?.id;
      if (uid != null && uid.isNotEmpty) {
        unawaited(ReviewService.refreshFingerprintAfterLogin(uid));
      }
      _setLoading(false);
      return true;
    } on AccountSuspendedException catch (e) {
      _suspensionMessage = e.message;
      _error = null;
      _user = null;
      _status = AuthStatus.unauthenticated;
      _setLoading(false);
      notifyListeners();
      return false;
    } catch (e) {
      _error = userFacingAuthError(e);
      _setLoading(false);
      notifyListeners();
      return false;
    }
  }

  /// Logout user
  Future<void> logout() async {
    final uid = _user?.id;

    _user = null;
    _status = AuthStatus.unauthenticated;
    _error = null;
    notifyListeners();

    try {
      await _authService.logout();
    } catch (_) {}

    unawaited(PushNotificationService.instance.unregisterToken());
    unawaited(RealtimeSocketService.instance.disconnect());
    unawaited(_firebaseAuthService.signOut().catchError((_) {}));
    unawaited(AuthHeadersSync.refreshAuthHeadersCache());
    if (uid != null && uid.isNotEmpty) {
      unawaited(ReviewCacheStore.clearBundle(uid));
      unawaited(SubmittedDocumentsService().clearCacheForUser(uid));
    }
    ReviewService.clearAllMemoryCache();
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
      _error = userFacingAuthError(e);
      _setLoading(false);
      notifyListeners();
      return false;
    }
  }

  /// Change or set password. currentPassword is optional for Google-only users.
  Future<bool> changePassword({
    String? current,
    required String newPassword,
  }) async {
    try {
      _setLoading(true);
      _error = null;

      final ok = await _authService.changePassword(
        currentPassword: current ?? '',
        newPassword: newPassword,
      );

      if (ok && _user != null && !_user!.hasPassword) {
        _user = _user!.copyWith(hasPassword: true);
      }

      _setLoading(false);
      return ok;
    } catch (e) {
      _error = userFacingAuthError(e);
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
      _error = userFacingAuthError(e);
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
      _error = userFacingAuthError(e);
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
      _error = userFacingAuthError(e);
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
      unawaited(PushNotificationService.instance.registerToken());
      final uid = _user?.id;
      if (uid != null && uid.isNotEmpty) {
        unawaited(ReviewService.refreshFingerprintAfterLogin(uid));
      }
      _setLoading(false);
      notifyListeners(); // Ensure UI rebuilds
      return true;
    } on AccountSuspendedException catch (e) {
      _suspensionMessage = e.message;
      _error = null;
      _user = null;
      _status = AuthStatus.unauthenticated;
      _setLoading(false);
      notifyListeners();
      return false;
    } catch (e) {
      _error = userFacingAuthError(e);
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
      unawaited(PushNotificationService.instance.registerToken());
      final uid = _user?.id;
      if (uid != null && uid.isNotEmpty) {
        unawaited(ReviewService.refreshFingerprintAfterLogin(uid));
      }
      _setLoading(false);
      notifyListeners(); // Ensure UI rebuilds
      return true;
    } catch (e) {
      _error = userFacingAuthError(e);
      _user = null;
      _status = AuthStatus.unauthenticated;
      _setLoading(false);
      notifyListeners();
      return false;
    }
  }

  void clearSuspensionMessage() {
    _suspensionMessage = null;
  }

  @override
  void dispose() {
    _tokenRefreshSub?.cancel();
    _sessionLostSub?.cancel();
    _suspendedSub?.cancel();
    super.dispose();
  }

  /// Delete user account (requires password confirmation)
  Future<void> deleteAccount(String password) async {
    try {
      _setLoading(true);
      _error = null;

      await _authService.deleteAccount(password);

      // Clear local state
      _user = null;
      _status = AuthStatus.unauthenticated;
      _error = null;
      
      // Disconnect socket
      await RealtimeSocketService.instance.disconnect();
      
      _setLoading(false);
      notifyListeners();
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
      _setLoading(false);
      notifyListeners();
      rethrow; // Re-throw so UI can show specific error
    }
  }
}
