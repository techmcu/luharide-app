import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/constants/api_constants.dart';
import 'api_service.dart';

/// Fetches `/api/kyc/submitted-documents` with a small local cache to avoid repeat calls.
class SubmittedDocumentsService {
  SubmittedDocumentsService();

  static const _prefsJsonKey = 'kyc_submitted_docs_cache_v1';
  static const _prefsAtKey = 'kyc_submitted_docs_cache_v1_at';
  static const _ttl = Duration(minutes: 20);

  final ApiService _api = ApiService();

  Future<void> clearCache() async {
    final p = await SharedPreferences.getInstance();
    await p.remove(_prefsJsonKey);
    await p.remove(_prefsAtKey);
  }

  Future<Map<String, dynamic>> load({bool forceRefresh = false}) async {
    final prefs = await SharedPreferences.getInstance();

    if (!forceRefresh) {
      final at = prefs.getInt(_prefsAtKey) ?? 0;
      if (at > 0 &&
          DateTime.now().millisecondsSinceEpoch - at < _ttl.inMilliseconds) {
        final raw = prefs.getString(_prefsJsonKey);
        if (raw != null && raw.isNotEmpty) {
          try {
            final map = jsonDecode(raw) as Map<String, dynamic>;
            final data = map['data'];
            if (data is Map) {
              return {
                'success': true,
                'fromCache': true,
                'message': map['message']?.toString() ?? 'OK',
                'data': Map<String, dynamic>.from(data),
              };
            }
          } catch (_) {
            // fall through to network
          }
        }
      }
    }

    try {
      final response = await _api.get(ApiConstants.submittedDocuments);
      final body = response.data;
      if (body is Map && body['success'] == true && body['data'] is Map) {
        final payload = {
          'message': body['message'],
          'data': body['data'],
        };
        await prefs.setString(_prefsJsonKey, jsonEncode(payload));
        await prefs.setInt(_prefsAtKey, DateTime.now().millisecondsSinceEpoch);
        return {
          'success': true,
          'fromCache': false,
          'message': body['message']?.toString() ?? 'OK',
          'data': Map<String, dynamic>.from(body['data'] as Map),
        };
      }
      return {
        'success': false,
        'message': body is Map ? body['message']?.toString() ?? 'Failed' : 'Failed',
      };
    } on DioException catch (e) {
      final raw = prefs.getString(_prefsJsonKey);
      if (raw != null && raw.isNotEmpty) {
        try {
          final map = jsonDecode(raw) as Map<String, dynamic>;
          final data = map['data'];
          if (data is Map) {
            return {
              'success': true,
              'fromCache': true,
              'staleOffline': true,
              'message': map['message']?.toString() ?? 'Showing saved copy',
              'data': Map<String, dynamic>.from(data),
            };
          }
        } catch (_) {}
      }
      final msg = e.response?.data is Map
          ? (e.response!.data as Map)['message']?.toString()
          : null;
      return {
        'success': false,
        'message': msg ?? 'Could not load documents',
      };
    }
  }
}
