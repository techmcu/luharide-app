import 'package:dio/dio.dart';
import '../core/constants/api_constants.dart';
import 'api_service.dart';

/// Normalizes API `requests` to a growable list (handles rare single-map payloads).
List<dynamic> coerceAdminRequestList(dynamic raw) {
  if (raw == null) return <dynamic>[];
  if (raw is List<dynamic>) return List<dynamic>.from(raw);
  if (raw is List) return List<dynamic>.from(raw);
  if (raw is Map) return <dynamic>[raw];
  return <dynamic>[];
}

String _camelToSnakeKey(String input) {
  var s = input.replaceAllMapped(RegExp(r'([a-z\d])([A-Z])'), (m) => '${m[1]}_${m[2]}');
  s = s.replaceAllMapped(RegExp(r'([A-Z]+)([A-Z][a-z])'), (m) => '${m[1]}_${m[2]}');
  return s.toLowerCase();
}

/// Merges nested `data`, copies camelCase fields to snake_case for KYC *_url columns
/// (admin list may arrive as raw PG rows or partially transformed JSON).
Map<String, dynamic> normalizeAdminKycMap(dynamic raw) {
  if (raw is! Map) return <String, dynamic>{};
  final src = Map<dynamic, dynamic>.from(raw);
  final out = <String, dynamic>{};

  void mergeIn(Map<dynamic, dynamic> m) {
    for (final e in m.entries) {
      out[e.key.toString()] = e.value;
    }
  }

  mergeIn(src);
  final nested = src['data'];
  if (nested is Map) mergeIn(Map<dynamic, dynamic>.from(nested));
  final reqNest = src['request'];
  if (reqNest is Map) mergeIn(Map<dynamic, dynamic>.from(reqNest));

  final keysCopy = List<String>.from(out.keys);
  for (final key in keysCopy) {
    if (!key.contains('_')) {
      final snake = _camelToSnakeKey(key);
      if (snake == key) continue;
      final v = out[key];
      if (v == null || v.toString().trim().isEmpty) continue;
      final cur = out[snake];
      if (cur == null || cur.toString().trim().isEmpty) {
        out[snake] = v;
      }
    }
  }

  return out;
}

List<dynamic> normalizeAdminRequestList(dynamic raw) {
  return coerceAdminRequestList(raw).map((e) => normalizeAdminKycMap(e)).toList();
}

/// Resolves `{ data: { requests } }`, `{ requests }`, or rows nested under `request`.
Map<String, dynamic> _adminResponseLayer(dynamic raw) {
  if (raw is! Map) return <String, dynamic>{};
  final root = Map<String, dynamic>.from(raw);
  final inner = root['data'];
  if (inner is Map) {
    return Map<String, dynamic>.from(inner);
  }
  return root;
}

dynamic _adminRequestsRaw(dynamic responseData) {
  final root = responseData is Map
      ? Map<String, dynamic>.from(responseData)
      : <String, dynamic>{};
  final layer = _adminResponseLayer(responseData);
  return layer['requests'] ?? root['requests'];
}

Map<String, dynamic> _unwrapDataMap(dynamic responseData) {
  if (responseData is! Map) return <String, dynamic>{};
  final root = Map<String, dynamic>.from(responseData);
  final inner = root['data'];
  if (inner is Map) return Map<String, dynamic>.from(inner);
  return root;
}

class AdminService {
  final ApiService _apiService = ApiService();

  /// Union admin dashboard stats: total_trips, total_bookings, drivers_verified
  Future<Map<String, dynamic>> getUnionDashboardStats() async {
    try {
      final response = await _apiService.get(ApiConstants.unionDashboard);
      final data = response.data['data'] ?? {};
      return {
        'success': true,
        'total_trips': data['total_trips'] ?? 0,
        'total_bookings': data['total_bookings'] ?? 0,
        'drivers_verified': data['drivers_verified'] ?? 0,
      };
    } on DioException catch (e) {
      return {
        'success': false,
        'total_trips': 0,
        'total_bookings': 0,
        'drivers_verified': 0,
        'message': e.response?.data['message'] ?? 'Failed',
      };
    } catch (e) {
      return {
        'success': false,
        'total_trips': 0,
        'total_bookings': 0,
        'drivers_verified': 0,
        'message': 'An error occurred',
      };
    }
  }

  /// Get pending driver verification requests
  Future<Map<String, dynamic>> getDriverRequests() async {
    try {
      final response = await _apiService.get(ApiConstants.adminDriverRequests);
      return {
        'success': true,
        'requests': normalizeAdminRequestList(_adminRequestsRaw(response.data)),
      };
    } on DioException catch (e) {
      return {
        'success': false,
        'requests': <dynamic>[],
        'message': e.response?.data['message'] ?? 'Failed',
      };
    } catch (e) {
      return {'success': false, 'requests': <dynamic>[], 'message': 'An error occurred'};
    }
  }

  /// Full independent-driver directory (excludes union_admin and plain passengers).
  Future<Map<String, dynamic>> getIndependentDriversDirectory({
    int limit = 200,
    int offset = 0,
  }) async {
    try {
      final response = await _apiService.get(
        '${ApiConstants.adminDirectoryIndependentDrivers}?limit=$limit&offset=$offset',
      );
      final d = _unwrapDataMap(response.data);
      return {
        'success': true,
        'drivers': d['drivers'] ?? [],
        'total': d['total'] ?? 0,
      };
    } on DioException catch (e) {
      return {
        'success': false,
        'drivers': <dynamic>[],
        'total': 0,
        'message': e.response?.data['message'] ?? 'Failed',
      };
    } catch (e) {
      return {'success': false, 'drivers': <dynamic>[], 'total': 0, 'message': 'An error occurred'};
    }
  }

  /// All unions in the database (admin directory).
  Future<Map<String, dynamic>> getUnionsDirectory({
    int limit = 200,
    int offset = 0,
  }) async {
    try {
      final response = await _apiService.get(
        '${ApiConstants.adminDirectoryUnions}?limit=$limit&offset=$offset',
      );
      final d = _unwrapDataMap(response.data);
      return {
        'success': true,
        'unions': d['unions'] ?? [],
        'total': d['total'] ?? 0,
      };
    } on DioException catch (e) {
      return {
        'success': false,
        'unions': <dynamic>[],
        'total': 0,
        'message': e.response?.data['message'] ?? 'Failed',
      };
    } catch (e) {
      return {'success': false, 'unions': <dynamic>[], 'total': 0, 'message': 'An error occurred'};
    }
  }

  /// Get pending union registration requests
  Future<Map<String, dynamic>> getUnionRequests() async {
    try {
      final response = await _apiService.get(ApiConstants.adminUnionRequests);
      return {
        'success': true,
        'requests': normalizeAdminRequestList(_adminRequestsRaw(response.data)),
      };
    } on DioException catch (e) {
      return {
        'success': false,
        'requests': <dynamic>[],
        'message': e.response?.data['message'] ?? 'Failed',
      };
    } catch (e) {
      return {
        'success': false,
        'requests': <dynamic>[],
        'message': 'An error occurred',
      };
    }
  }

  /// Approve driver request (JWT auth only; no extra approve password)
  Future<Map<String, dynamic>> approveDriver(String requestId) async {
    try {
      await _apiService.post(
        '${ApiConstants.adminDriverRequests}/$requestId/approve',
      );
      return {'success': true, 'message': 'Driver approved'};
    } on DioException catch (e) {
      return {'success': false, 'message': e.response?.data['message'] ?? 'Failed'};
    } catch (e) {
      return {'success': false, 'message': 'An error occurred'};
    }
  }

  /// Reject driver request
  Future<Map<String, dynamic>> rejectDriver(String requestId, {String? reason}) async {
    try {
      await _apiService.post(
        '${ApiConstants.adminDriverRequests}/$requestId/reject',
        data: {'reason': reason ?? 'Documents rejected'},
      );
      return {'success': true, 'message': 'Request rejected'};
    } on DioException catch (e) {
      return {'success': false, 'message': e.response?.data['message'] ?? 'Failed'};
    } catch (e) {
      return {'success': false, 'message': 'An error occurred'};
    }
  }

  /// Approve union request (JWT auth only; no extra approve password)
  Future<Map<String, dynamic>> approveUnion(String unionId) async {
    try {
      await _apiService.post(
        '${ApiConstants.adminUnionRequests}/$unionId/approve',
      );
      return {'success': true, 'message': 'Union approved'};
    } on DioException catch (e) {
      return {'success': false, 'message': e.response?.data['message'] ?? 'Failed'};
    } catch (e) {
      return {'success': false, 'message': 'An error occurred'};
    }
  }

  /// Reject union request
  Future<Map<String, dynamic>> rejectUnion(String unionId) async {
    try {
      await _apiService.post('${ApiConstants.adminUnionRequests}/$unionId/reject');
      return {'success': true, 'message': 'Union request rejected'};
    } on DioException catch (e) {
      return {'success': false, 'message': e.response?.data['message'] ?? 'Failed'};
    } catch (e) {
      return {'success': false, 'message': 'An error occurred'};
    }
  }

  /// Revoke driver verified badge, enable one-time re-upload, notify user (platform admin only).
  Future<Map<String, dynamic>> grantDriverKycReverify(
    String userId, {
    String? message,
    int? days,
  }) async {
    try {
      final body = <String, dynamic>{};
      if (message != null && message.trim().isNotEmpty) body['message'] = message.trim();
      if (days != null) body['days'] = days;
      await _apiService.post(
        ApiConstants.adminKycDriverReverify(userId),
        data: body.isEmpty ? null : body,
      );
      return {'success': true, 'message': 'Driver re-verification requested'};
    } on DioException catch (e) {
      return {'success': false, 'message': e.response?.data['message'] ?? 'Failed'};
    } catch (e) {
      return {'success': false, 'message': 'An error occurred'};
    }
  }

  /// Revoke union document verified state, enable one-time re-upload, notify union admins.
  Future<Map<String, dynamic>> grantUnionKycReverify(
    String unionId, {
    String? message,
    int? days,
  }) async {
    try {
      final body = <String, dynamic>{};
      if (message != null && message.trim().isNotEmpty) body['message'] = message.trim();
      if (days != null) body['days'] = days;
      await _apiService.post(
        ApiConstants.adminKycUnionReverify(unionId),
        data: body.isEmpty ? null : body,
      );
      return {'success': true, 'message': 'Union re-verification requested'};
    } on DioException catch (e) {
      return {'success': false, 'message': e.response?.data['message'] ?? 'Failed'};
    } catch (e) {
      return {'success': false, 'message': 'An error occurred'};
    }
  }
}
