import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/constants/api_constants.dart';
import '../core/kyc/submitted_documents_cache_keys.dart';
import 'api_service.dart';

/// Fetches `/api/kyc/submitted-documents` with a per-user local cache.
///
/// Cache keys include [userId] so another account on the same phone never
/// sees the previous user's list (privacy).
class SubmittedDocumentsService {
  SubmittedDocumentsService();

  final ApiService _api = ApiService();

  Future<void> _dropLegacyKeys(SharedPreferences p) async {
    await p.remove(SubmittedDocumentsCacheKeys.legacyJsonKey);
    await p.remove(SubmittedDocumentsCacheKeys.legacyAtKey);
  }

  /// Call on logout for the account that is signing out.
  Future<void> clearCacheForUser(String userId) async {
    if (userId.isEmpty) return;
    final p = await SharedPreferences.getInstance();
    await _dropLegacyKeys(p);
    await p.remove(SubmittedDocumentsCacheKeys.jsonKey(userId));
    await p.remove(SubmittedDocumentsCacheKeys.atKey(userId));
  }

  Future<Map<String, dynamic>> load({
    required String? userId,
    bool forceRefresh = false,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await _dropLegacyKeys(prefs);

    final uid = userId?.trim();
    final canCache = uid != null && uid.isNotEmpty;

    if (canCache && !forceRefresh) {
      final at = prefs.getInt(SubmittedDocumentsCacheKeys.atKey(uid)) ?? 0;
      if (at > 0 &&
          DateTime.now().millisecondsSinceEpoch - at <
              SubmittedDocumentsCacheKeys.ttl.inMilliseconds) {
        final raw = prefs.getString(SubmittedDocumentsCacheKeys.jsonKey(uid));
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
          } catch (_) {}
        }
      }
    }

    try {
      final response = await _api.get(ApiConstants.submittedDocuments);
      final body = response.data;
      if (body is Map && body['success'] == true && body['data'] is Map) {
        final dataMap = Map<String, dynamic>.from(body['data'] as Map);
        if (canCache) {
          final payload = {
            'message': body['message'],
            'data': dataMap,
          };
          await prefs.setString(
            SubmittedDocumentsCacheKeys.jsonKey(uid),
            jsonEncode(payload),
          );
          await prefs.setInt(
            SubmittedDocumentsCacheKeys.atKey(uid),
            DateTime.now().millisecondsSinceEpoch,
          );
        }
        return {
          'success': true,
          'fromCache': false,
          'message': body['message']?.toString() ?? 'OK',
          'data': dataMap,
        };
      }
      return {
        'success': false,
        'message': body is Map ? body['message']?.toString() ?? 'Failed' : 'Failed',
      };
    } on DioException catch (e) {
      if (canCache) {
        final raw = prefs.getString(SubmittedDocumentsCacheKeys.jsonKey(uid));
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
