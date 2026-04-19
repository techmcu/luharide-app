import 'dart:convert';

import 'package:dio/dio.dart';

import '../core/utils/api_error_messages.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';
import '../core/constants/api_constants.dart';
import 'api_service.dart';

class AuthService {
  final ApiService _apiService;
  
  AuthService(this._apiService);

  // Storage keys - minimal, no extra keys
  static const String _accessTokenKey = 'access_token';
  static const String _refreshTokenKey = 'refresh_token';
  static const String _userDataKey = 'user_data';
  static const String _userIdKey = 'user_id'; // cached for quick access

  /// Send OTP to phone number
  Future<Map<String, dynamic>> sendOTP(String phone, {String purpose = 'login'}) async {
    try {
      final response = await _apiService.post(
        ApiConstants.sendOTP,
        data: {
          'phone': phone,
          'purpose': purpose,
        },
      );

      if (response.statusCode == 200 && response.data['success'] == true) {
        return response.data['data'];
      } else {
        throw Exception(response.data['message'] ?? 'Failed to send OTP');
      }
    } on DioException catch (e) {
      if (e.response != null) {
        throw Exception(e.response!.data['message'] ?? 'Failed to send OTP');
      }
      throw Exception(userMessageFromDio(e));
    }
  }

  /// Send OTP to email (for signup / login)
  Future<Map<String, dynamic>> sendOTPByEmail(String email, {String purpose = 'registration'}) async {
    try {
      final response = await _apiService.post(
        ApiConstants.sendOTP,
        data: {
          'email': email.trim().toLowerCase(),
          'purpose': purpose,
        },
      );

      if (response.statusCode == 200 && response.data['success'] == true) {
        return response.data['data'] as Map<String, dynamic>;
      } else {
        throw Exception(response.data['message'] ?? 'Failed to send OTP');
      }
    } on DioException catch (e) {
      if (e.response != null) {
        throw Exception(e.response!.data['message'] ?? 'Failed to send OTP');
      }
      throw Exception(userMessageFromDio(e));
    }
  }

  /// Verify OTP and login/register (email) – for signup pass name, role, password
  Future<Map<String, dynamic>> verifyOTPByEmail({
    required String email,
    required String otp,
    String? name,
    String role = 'passenger',
    String? password,
  }) async {
    try {
      final response = await _apiService.post(
        ApiConstants.verifyOTP,
        data: {
          'email': email.trim().toLowerCase(),
          'otp': otp,
          if (name != null && name.length >= 2) 'name': name,
          'role': role,
          if (password != null && password.isNotEmpty) 'password': password,
          'platform': 'mobile',
        },
      );

      if (response.statusCode == 200 && response.data['success'] == true) {
        final data = response.data['data'];
        final tokens = AuthTokens.fromJson(data['tokens']);
        final user = UserModel.fromJson(data['user']);
        await _saveAuthData(tokens, user);
        return {
          'user': user,
          'tokens': tokens,
          'isNewUser': data['isNewUser'] ?? false,
        };
      } else {
        throw Exception(response.data['message'] ?? 'Failed to verify OTP');
      }
    } on DioException catch (e) {
      if (e.response != null) {
        throw Exception(e.response!.data['message'] ?? 'Failed to verify OTP');
      }
      throw Exception(userMessageFromDio(e));
    }
  }

  /// Verify OTP and login/register (phone)
  Future<Map<String, dynamic>> verifyOTP({
    required String phone,
    required String otp,
    String? name,
    String role = 'passenger',
  }) async {
    try {
      final response = await _apiService.post(
        ApiConstants.verifyOTP,
        data: {
          'phone': phone,
          'otp': otp,
          if (name != null) 'name': name,
          'role': role,
          'platform': 'mobile',
        },
      );

      if (response.statusCode == 200 && response.data['success'] == true) {
        final data = response.data['data'];
        
        // Save tokens and user data
        final tokens = AuthTokens.fromJson(data['tokens']);
        final user = UserModel.fromJson(data['user']);
        
        await _saveAuthData(tokens, user);
        
        return {
          'user': user,
          'tokens': tokens,
          'isNewUser': data['isNewUser'] ?? false,
        };
      } else {
        throw Exception(response.data['message'] ?? 'Failed to verify OTP');
      }
    } on DioException catch (e) {
      if (e.response != null) {
        throw Exception(e.response!.data['message'] ?? 'Failed to verify OTP');
      }
      throw Exception(userMessageFromDio(e));
    }
  }

  /// Get current user profile
  Future<UserModel> getCurrentUser() async {
    try {
      final response = await _apiService.get(ApiConstants.currentUser);

      if (response.statusCode == 200 && response.data['success'] == true) {
        return UserModel.fromJson(response.data['data']);
      } else {
        throw Exception('Failed to get user profile');
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        // Token expired, try to refresh
        await refreshToken();
        return getCurrentUser();
      }
      throw Exception('Failed to get user profile');
    }
  }

  /// Refresh access token
  Future<void> refreshToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final refreshToken = prefs.getString(_refreshTokenKey);

      if (refreshToken == null) {
        throw Exception('No refresh token found');
      }

      final response = await _apiService.post(
        ApiConstants.refreshToken,
        data: {
          'refreshToken': refreshToken,
          'platform': 'mobile',
        },
      );

      if (response.statusCode == 200 && response.data['success'] == true) {
        final tokens = AuthTokens.fromJson(response.data['data']['tokens']);
        await _saveTokens(tokens);
      } else {
        throw Exception('Failed to refresh token');
      }
    } catch (e) {
      // If refresh fails, logout user
      await logout();
      rethrow;
    }
  }

  /// Logout user
  Future<void> logout() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final refreshToken = prefs.getString(_refreshTokenKey);

      if (refreshToken != null) {
        await _apiService.post(
          ApiConstants.logout,
          data: {'refreshToken': refreshToken},
        );
      }
    } catch (e) {
      // Ignore logout errors
    } finally {
      await _clearAuthData();
    }
  }

  /// Update user profile
  Future<UserModel> updateProfile({
    String? name,
    String? phone,
    String? email,
    String? whatsappNumber,
    String? profileImageUrl,
    String? bio,
    String? luggageAllowancePerPassenger,
  }) async {
    try {
      final payload = {
        if (name != null) 'name': name,
        if (phone != null) 'phone': phone,
        if (email != null) 'email': email,
        if (whatsappNumber != null) 'whatsapp_number': whatsappNumber,
        if (profileImageUrl != null) 'profile_image_url': profileImageUrl,
        if (bio != null) 'bio': bio,
        if (luggageAllowancePerPassenger != null) 'luggage_allowance_per_passenger': luggageAllowancePerPassenger,
      };
      Response response;
      try {
        response = await _apiService.put(ApiConstants.updateProfile, data: payload);
      } on DioException catch (e) {
        // Some older deployments may expose profile update on legacy endpoint.
        if (e.response?.statusCode == 404) {
          response = await _apiService.put(ApiConstants.userProfile, data: payload);
        } else {
          rethrow;
        }
      }

      if (response.statusCode == 200 && response.data['success'] == true) {
        final user = UserModel.fromJson(response.data['data']);
        await _saveUserData(user);
        return user;
      } else {
        throw Exception('Failed to update profile');
      }
    } on DioException catch (e) {
      if (e.response != null) {
        throw Exception(e.response!.data['message'] ?? 'Failed to update profile');
      }
      throw Exception(userMessageFromDio(e));
    }
  }

  /// Change password for email/password users
  Future<bool> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      final response = await _apiService.post(
        '/simple-auth/change-password',
        data: {
          'currentPassword': currentPassword,
          'newPassword': newPassword,
        },
      );

      if (response.statusCode == 200 && response.data['success'] == true) {
        return true;
      }
      throw Exception(response.data['message'] ?? 'Failed to update password');
    } on DioException catch (e) {
      if (e.response != null) {
        throw Exception(e.response!.data['message'] ?? 'Failed to update password');
      }
      throw Exception(userMessageFromDio(e));
    }
  }

  /// Forgot password - request OTP to email
  Future<bool> requestPasswordReset({
    required String email,
  }) async {
    DioException? lastTimeout;
    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        final response = await _apiService.post(
          '/simple-auth/forgot-password',
          data: {
            'email': email.trim().toLowerCase(),
          },
        );

        if (response.statusCode == 200 && response.data['success'] == true) {
          return true;
        }
        final body = response.data;
        final msg = body is Map ? body['message']?.toString() : null;
        throw Exception(msg ?? 'Failed to request password reset');
      } on DioException catch (e) {
        final canRetry = attempt == 0 &&
            (e.type == DioExceptionType.connectionTimeout ||
                e.type == DioExceptionType.receiveTimeout ||
                e.type == DioExceptionType.connectionError);
        if (canRetry) {
          lastTimeout = e;
          await Future<void>.delayed(const Duration(milliseconds: 900));
          continue;
        }
        if (e.response != null) {
          final data = e.response!.data;
          final msg = data is Map ? data['message']?.toString() : null;
          throw Exception(msg ?? 'Failed to request password reset');
        }
        throw Exception(userMessageFromDio(lastTimeout ?? e));
      }
    }
    throw Exception(userMessageFromDio(lastTimeout!));
  }

  /// Reset password using email + OTP
  Future<bool> resetPasswordWithEmailOtp({
    required String email,
    required String otp,
    required String newPassword,
  }) async {
    try {
      final response = await _apiService.post(
        '/simple-auth/reset-password',
        data: {
          'email': email.trim().toLowerCase(),
          'otp': otp,
          'newPassword': newPassword,
        },
      );

      if (response.statusCode == 200 && response.data['success'] == true) {
        return true;
      }
      throw Exception(response.data['message'] ?? 'Failed to reset password');
    } on DioException catch (e) {
      if (e.response != null) {
        throw Exception(e.response!.data['message'] ?? 'Failed to reset password');
      }
      throw Exception(userMessageFromDio(e));
    }
  }

  /// Check if user is logged in
  Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey(_accessTokenKey);
  }

  /// Restore token to ApiService (call on app start when cached session exists)
  Future<void> restoreTokenIfCached() async {
    final token = await getAccessToken();
    if (token != null && token.isNotEmpty) {
      _apiService.setAuthToken(token);
    }
  }

  /// Get cached user from local storage (no API call)
  Future<UserModel?> getSavedUser() async {
    final prefs = await SharedPreferences.getInstance();
    final userData = prefs.getString(_userDataKey);
    if (userData == null || userData.isEmpty) return null;
    try {
      final map = jsonDecode(userData) as Map<String, dynamic>;
      return UserModel.fromJson(map);
    } catch (_) {
      return null;
    }
  }

  /// Get cached user ID (lightweight, single string read)
  Future<String?> getCachedUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_userIdKey);
  }

  /// Save auth data (tokens + user)
  Future<void> _saveAuthData(AuthTokens tokens, UserModel user) async {
    await _saveTokens(tokens);
    await _saveUserData(user);
  }

  /// Save tokens
  Future<void> _saveTokens(AuthTokens tokens) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_accessTokenKey, tokens.accessToken);
    await prefs.setString(_refreshTokenKey, tokens.refreshToken);
    
    // Set token in API service
    _apiService.setAuthToken(tokens.accessToken);
  }

  /// Save user data (minimal JSON, ~200-500 bytes)
  Future<void> _saveUserData(UserModel user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userDataKey, jsonEncode(user.toJson()));
    await prefs.setString(_userIdKey, user.id);
  }

  /// Clear all auth data
  Future<void> _clearAuthData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_accessTokenKey);
    await prefs.remove(_refreshTokenKey);
    await prefs.remove(_userDataKey);
    await prefs.remove(_userIdKey);
    _apiService.clearAuthToken();
  }

  /// Get access token
  Future<String?> getAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_accessTokenKey);
  }

  /// Simple Login - Email + Password
  Future<Map<String, dynamic>> simpleLogin({
    required String email,
    required String password,
  }) async {
    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        final response = await _apiService.post(
          '/simple-auth/login',
          data: {
            'email': email,
            'password': password,
          },
        );

        final raw = response.data;
        if (raw is! Map) {
          throw Exception(
            'Server se sahi jawab nahi mila (format). App update karke try karein.',
          );
        }
        final body = Map<String, dynamic>.from(raw);
        if (response.statusCode == 200 && body['success'] == true) {
          final data = body['data'];
          if (data is! Map) {
            throw Exception('Login data invalid');
          }
          final dataMap = Map<String, dynamic>.from(data);

          final tokens = AuthTokens.fromJson(
            Map<String, dynamic>.from(dataMap['tokens'] as Map),
          );
          final user = UserModel.fromJson(
            Map<String, dynamic>.from(dataMap['user'] as Map),
          );

          await _saveAuthData(tokens, user);

          return {
            'user': user,
            'tokens': tokens,
          };
        } else {
          throw Exception(body['message']?.toString() ?? 'Login failed');
        }
      } on DioException catch (e) {
        if (_isRetryableNetwork(e) && attempt == 0) {
          await Future<void>.delayed(const Duration(milliseconds: 500));
          continue;
        }
        if (e.response?.statusCode == 404) {
          throw Exception(userMessageFromDio(e));
        }
        if (e.response?.statusCode == 429) {
          throw Exception(
            e.message ?? 'Too many requests. Please wait 1–2 minutes and try again.',
          );
        }
        if (e.response != null) {
          final data = e.response!.data;
          final msg = data is Map ? data['message'] : null;
          throw Exception(msg?.toString() ?? 'Login failed');
        }
        throw Exception(userMessageFromDio(e));
      }
    }
    throw Exception('Login failed');
  }

  static bool _isRetryableNetwork(DioException e) {
    if (e.response != null) return false;
    return e.type == DioExceptionType.connectionError ||
        e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.sendTimeout;
  }

  /// Create demo accounts (passenger, driver, admin) - first time setup
  Future<bool> createDemoAccounts() async {
    try {
      final response = await _apiService.post('/simple-auth/create-demo');
      return response.statusCode == 200 && response.data['success'] == true;
    } catch (_) {
      return false;
    }
  }

  /// Simple Signup - Email + Password
  Future<Map<String, dynamic>> simpleSignup({
    required String email,
    required String password,
    required String name,
    String role = 'passenger',
  }) async {
    try {
      final response = await _apiService.post(
        '/simple-auth/signup',
        data: {
          'email': email,
          'password': password,
          'name': name,
          'role': role,
        },
      );

      if (response.statusCode == 201 && response.data['success'] == true) {
        final data = response.data['data'];
        
        final tokens = AuthTokens.fromJson(data['tokens']);
        final user = UserModel.fromJson(data['user']);
        
        await _saveAuthData(tokens, user);
        
        return {
          'user': user,
          'tokens': tokens,
        };
      } else {
        throw Exception(response.data['message'] ?? 'Signup failed');
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        throw Exception(userMessageFromDio(e));
      }
      if (e.response?.statusCode == 429) {
        throw Exception(
          e.message ?? 'Too many requests. Please wait 1–2 minutes and try again.',
        );
      }
      if (e.response != null) {
        final data = e.response!.data;
        final msg = data is Map ? data['message'] : null;
        throw Exception(msg?.toString() ?? 'Signup failed');
      }
      throw Exception(userMessageFromDio(e));
    }
  }

  /// Delete user account (requires password confirmation)
  Future<void> deleteAccount(String password) async {
    try {
      // Ensure we have a valid access token before attempting deletion
      final token = await getAccessToken();
      if (token == null || token.isEmpty) {
        throw Exception('Please login again to delete your account');
      }
      
      // Explicitly set token (ensures fresh token is used)
      _apiService.setAuthToken(token);
      
      final response = await _apiService.delete(
        '/auth/account',
        data: {'password': password},
      );

      if (response.statusCode == 200 && response.data['success'] == true) {
        // Clear all local data after successful deletion
        await _clearAuthData();
        return;
      } else {
        throw Exception(response.data['message'] ?? 'Failed to delete account');
      }
    } on DioException catch (e) {
      // 401 can mean either wrong password OR expired token
      if (e.response?.statusCode == 401) {
        final data = e.response?.data;
        final errorMsg = data is Map ? data['error'] : null;
        
        // If backend says "Incorrect password", show that
        if (errorMsg?.toString().toLowerCase().contains('password') == true) {
          throw Exception('Incorrect password');
        }
        
        // Otherwise it's a token/auth issue
        throw Exception('Session expired. Please logout and login again to delete your account.');
      }
      if (e.response?.statusCode == 400) {
        final data = e.response!.data;
        final msg = data is Map ? data['message'] : null;
        throw Exception(msg?.toString() ?? 'Cannot delete account');
      }
      if (e.response != null) {
        final data = e.response!.data;
        final msg = data is Map ? data['message'] : null;
        throw Exception(msg?.toString() ?? 'Failed to delete account');
      }
      throw Exception(userMessageFromDio(e));
    }
  }
}
