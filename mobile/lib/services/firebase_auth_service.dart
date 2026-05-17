import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/utils/api_error_messages.dart';
import '../models/user_model.dart';
import 'api_service.dart';

class FirebaseAuthService {
  final ApiService _apiService;
  fb.FirebaseAuth get _firebaseAuth => fb.FirebaseAuth.instance;

  static const String _accessTokenKey = 'access_token';
  static const String _refreshTokenKey = 'refresh_token';
  static const String _userDataKey = 'user_data';
  static const String _userIdKey = 'user_id';

  FirebaseAuthService(this._apiService);

  static const _webClientId = '698013485373-fkd9oupqd5srtgrnle155t4h4elkvc9o.apps.googleusercontent.com';

  /// Google Sign-In: one-tap login, creates account if new
  Future<Map<String, dynamic>> signInWithGoogle({String role = 'passenger'}) async {
    try {
      final googleSignIn = GoogleSignIn.instance;
      await googleSignIn.initialize(serverClientId: _webClientId);

      final GoogleSignInAccount account = await googleSignIn.authenticate();
      final googleIdToken = account.authentication.idToken;

      if (googleIdToken == null || googleIdToken.isEmpty) {
        throw Exception('Failed to get Google ID token');
      }

      // Sign in with Firebase (for local state tracking)
      final credential = fb.GoogleAuthProvider.credential(idToken: googleIdToken);
      await _firebaseAuth.signInWithCredential(credential);

      // Send the GOOGLE ID token to backend (not Firebase token)
      final tokenToSend = googleIdToken;

      // Send token to our backend
      final response = await _apiService.post(
        '/simple-auth/google',
        data: {
          'idToken': tokenToSend,
          'role': role,
        },
      );

      if ((response.statusCode == 200 || response.statusCode == 201) &&
          response.data['success'] == true) {
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
        throw Exception(response.data['message'] ?? 'Google sign-in failed');
      }
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) {
        throw Exception('Google sign-in cancelled');
      }
      throw Exception(e.description ?? 'Google sign-in error');
    } on DioException catch (e) {
      throw Exception(dioResponseMessage(e) ?? userMessageFromDio(e));
    } on fb.FirebaseAuthException catch (e) {
      throw Exception(e.message ?? 'Firebase auth error');
    }
  }

  /// Firebase Email Link: send sign-in link to email
  Future<void> sendSignInLink({required String email}) async {
    final actionCodeSettings = fb.ActionCodeSettings(
      url: 'https://luharide.cloud/app/login?email=${Uri.encodeComponent(email)}',
      handleCodeInApp: true,
      androidPackageName: 'cloud.luharide.app',
      androidInstallApp: true,
      androidMinimumVersion: '21',
    );

    await _firebaseAuth.sendSignInLinkToEmail(
      email: email,
      actionCodeSettings: actionCodeSettings,
    );

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('pending_email_link', email);
  }

  /// Verify email link and sign in
  Future<Map<String, dynamic>> verifyEmailLink({
    required String emailLink,
    String? name,
    String role = 'passenger',
  }) async {
    try {
      if (!_firebaseAuth.isSignInWithEmailLink(emailLink)) {
        throw Exception('Invalid email link');
      }

      final prefs = await SharedPreferences.getInstance();
      final email = prefs.getString('pending_email_link');

      if (email == null || email.isEmpty) {
        throw Exception('Email not found. Please try signing in again.');
      }

      final userCredential = await _firebaseAuth.signInWithEmailLink(
        email: email,
        emailLink: emailLink,
      );

      final idToken = await userCredential.user?.getIdToken();
      if (idToken == null) {
        throw Exception('Failed to get Firebase token');
      }

      final response = await _apiService.post(
        '/simple-auth/firebase-email',
        data: {
          'idToken': idToken,
          'name': name,
          'role': role,
        },
      );

      if ((response.statusCode == 200 || response.statusCode == 201) &&
          response.data['success'] == true) {
        final data = response.data['data'];
        final tokens = AuthTokens.fromJson(data['tokens']);
        final user = UserModel.fromJson(data['user']);
        await _saveAuthData(tokens, user);

        await prefs.remove('pending_email_link');

        return {
          'user': user,
          'tokens': tokens,
          'isNewUser': data['isNewUser'] ?? false,
        };
      } else {
        throw Exception(response.data['message'] ?? 'Email link sign-in failed');
      }
    } on DioException catch (e) {
      throw Exception(dioResponseMessage(e) ?? userMessageFromDio(e));
    } on fb.FirebaseAuthException catch (e) {
      throw Exception(e.message ?? 'Firebase auth error');
    }
  }

  bool isSignInWithEmailLink(String link) {
    return _firebaseAuth.isSignInWithEmailLink(link);
  }

  Future<void> signOut() async {
    await GoogleSignIn.instance.signOut();
    await _firebaseAuth.signOut();
  }

  Future<void> _saveAuthData(AuthTokens tokens, UserModel user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_accessTokenKey, tokens.accessToken);
    await prefs.setString(_refreshTokenKey, tokens.refreshToken);
    await prefs.setString(_userDataKey, jsonEncode(user.toJson()));
    await prefs.setString(_userIdKey, user.id);
    _apiService.setAuthToken(tokens.accessToken);
  }
}
