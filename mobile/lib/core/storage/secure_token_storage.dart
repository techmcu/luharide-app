import 'dart:async';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Encrypted token storage.
/// Android: EncryptedSharedPreferences, iOS: Keychain, Web: encrypted localStorage.
/// Auto-migrates plaintext tokens from SharedPreferences on first access.
class SecureTokenStorage {
  SecureTokenStorage._();
  static final SecureTokenStorage instance = SecureTokenStorage._();

  static const _accessTokenKey = 'access_token';
  static const _refreshTokenKey = 'refresh_token';
  static const _migratedFlag = '_secure_storage_migrated';

  final FlutterSecureStorage _secure = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  bool _migrated = false;
  Completer<void>? _migrationCompleter;

  Future<void> _ensureMigrated() async {
    if (_migrated) return;
    if (_migrationCompleter != null) {
      await _migrationCompleter!.future;
      return;
    }
    _migrationCompleter = Completer<void>();
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(_migratedFlag) != true) {
        final access = prefs.getString(_accessTokenKey);
        final refresh = prefs.getString(_refreshTokenKey);
        if (access != null && access.isNotEmpty) {
          await _secure.write(key: _accessTokenKey, value: access);
        }
        if (refresh != null && refresh.isNotEmpty) {
          await _secure.write(key: _refreshTokenKey, value: refresh);
        }
        await prefs.remove(_accessTokenKey);
        await prefs.remove(_refreshTokenKey);
        await prefs.setBool(_migratedFlag, true);
      }
      _migrated = true;
      _migrationCompleter!.complete();
    } catch (_) {
      _migrated = true;
      if (!_migrationCompleter!.isCompleted) {
        _migrationCompleter!.complete();
      }
    }
  }

  Future<String?> getAccessToken() async {
    await _ensureMigrated();
    return _secure.read(key: _accessTokenKey);
  }

  Future<String?> getRefreshToken() async {
    await _ensureMigrated();
    return _secure.read(key: _refreshTokenKey);
  }

  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    await _ensureMigrated();
    await Future.wait([
      _secure.write(key: _accessTokenKey, value: accessToken),
      _secure.write(key: _refreshTokenKey, value: refreshToken),
    ]);
  }

  Future<void> updateAccessToken(String accessToken) async {
    await _ensureMigrated();
    await _secure.write(key: _accessTokenKey, value: accessToken);
  }

  Future<void> updateRefreshToken(String refreshToken) async {
    await _ensureMigrated();
    await _secure.write(key: _refreshTokenKey, value: refreshToken);
  }

  Future<void> clearTokens() async {
    await _ensureMigrated();
    await Future.wait([
      _secure.delete(key: _accessTokenKey),
      _secure.delete(key: _refreshTokenKey),
    ]);
  }

  Future<bool> hasAccessToken() async {
    final token = await getAccessToken();
    return token != null && token.isNotEmpty;
  }

  /// Reset singleton state so migration re-runs. Only for tests.
  @visibleForTesting
  void resetForTesting() {
    _migrated = false;
    _migrationCompleter = null;
  }
}
