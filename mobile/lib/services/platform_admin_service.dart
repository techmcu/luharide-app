import 'package:dio/dio.dart';
import '../core/constants/api_constants.dart';
import '../core/utils/api_error_messages.dart';
import 'api_service.dart';

class PlatformAdminService {
  final ApiService _api = ApiService();

  Map<String, dynamic> _unwrap(dynamic data) {
    if (data is! Map) return <String, dynamic>{};
    final root = Map<String, dynamic>.from(data);
    final inner = root['data'];
    if (inner is Map) return Map<String, dynamic>.from(inner);
    return root;
  }

  Future<Map<String, dynamic>> getDashboard() async {
    try {
      final res = await _api.get(ApiConstants.platformDashboard);
      return {'success': true, ..._unwrap(res.data)};
    } on DioException catch (e) {
      return {'success': false, 'message': dioResponseMessage(e) ?? 'Failed to load dashboard'};
    } catch (_) {
      return {'success': false, 'message': 'An error occurred'};
    }
  }

  Future<Map<String, dynamic>> getUsers({
    String search = '',
    String role = '',
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final q = <String, String>{
        'page': '$page',
        'limit': '$limit',
      };
      if (search.isNotEmpty) q['search'] = search;
      if (role.isNotEmpty) q['role'] = role;
      final qs = q.entries.map((e) => '${e.key}=${Uri.encodeComponent(e.value)}').join('&');
      final res = await _api.get('${ApiConstants.platformUsers}?$qs');
      final d = _unwrap(res.data);
      return {
        'success': true,
        'users': d['users'] ?? [],
        'total': d['total'] ?? 0,
        'page': d['page'] ?? page,
        'totalPages': d['totalPages'] ?? 1,
      };
    } on DioException catch (e) {
      return {'success': false, 'users': [], 'total': 0, 'message': dioResponseMessage(e) ?? 'Failed'};
    } catch (_) {
      return {'success': false, 'users': [], 'total': 0, 'message': 'An error occurred'};
    }
  }

  Future<Map<String, dynamic>> getUserDetail(String userId) async {
    try {
      final res = await _api.get(ApiConstants.platformUserDetail(userId));
      return {'success': true, ..._unwrap(res.data)};
    } on DioException catch (e) {
      return {'success': false, 'message': dioResponseMessage(e) ?? 'Failed'};
    } catch (_) {
      return {'success': false, 'message': 'An error occurred'};
    }
  }

  Future<Map<String, dynamic>> toggleUserActive(String userId, bool isActive) async {
    try {
      final res = await _api.patch(
        ApiConstants.platformUserToggleActive(userId),
        data: {'is_active': isActive},
      );
      return {'success': true, ..._unwrap(res.data)};
    } on DioException catch (e) {
      return {'success': false, 'message': dioResponseMessage(e) ?? 'Failed'};
    } catch (_) {
      return {'success': false, 'message': 'An error occurred'};
    }
  }

  Future<Map<String, dynamic>> getTrips({
    String status = '',
    String date = '',
    String search = '',
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final q = <String, String>{'page': '$page', 'limit': '$limit'};
      if (status.isNotEmpty) q['status'] = status;
      if (date.isNotEmpty) q['date'] = date;
      if (search.isNotEmpty) q['search'] = search;
      final qs = q.entries.map((e) => '${e.key}=${Uri.encodeComponent(e.value)}').join('&');
      final res = await _api.get('${ApiConstants.platformTrips}?$qs');
      final d = _unwrap(res.data);
      return {
        'success': true,
        'trips': d['trips'] ?? [],
        'total': d['total'] ?? 0,
        'page': d['page'] ?? page,
        'totalPages': d['totalPages'] ?? 1,
      };
    } on DioException catch (e) {
      return {'success': false, 'trips': [], 'total': 0, 'message': dioResponseMessage(e) ?? 'Failed'};
    } catch (_) {
      return {'success': false, 'trips': [], 'total': 0, 'message': 'An error occurred'};
    }
  }

  Future<Map<String, dynamic>> getTripDetail(String tripId) async {
    try {
      final res = await _api.get(ApiConstants.platformTripDetail(tripId));
      return {'success': true, ..._unwrap(res.data)};
    } on DioException catch (e) {
      return {'success': false, 'message': dioResponseMessage(e) ?? 'Failed'};
    } catch (_) {
      return {'success': false, 'message': 'An error occurred'};
    }
  }

  Future<Map<String, dynamic>> cancelTrip(String tripId, {String? reason}) async {
    try {
      final body = (reason != null && reason.isNotEmpty) ? {'reason': reason} : null;
      final res = await _api.post(
        ApiConstants.platformTripCancel(tripId),
        data: body,
      );
      return {'success': true, ..._unwrap(res.data)};
    } on DioException catch (e) {
      return {'success': false, 'message': dioResponseMessage(e) ?? 'Failed'};
    } catch (_) {
      return {'success': false, 'message': 'An error occurred'};
    }
  }

  Future<Map<String, dynamic>> getRevenueOverview({String period = 'month'}) async {
    try {
      final res = await _api.get('${ApiConstants.platformRevenue}?period=$period');
      return {'success': true, ..._unwrap(res.data)};
    } on DioException catch (e) {
      return {'success': false, 'message': dioResponseMessage(e) ?? 'Failed'};
    } catch (_) {
      return {'success': false, 'message': 'An error occurred'};
    }
  }

  // ---- Phase 2: Notifications, Complaints, Config ----

  Future<Map<String, dynamic>> sendBulkNotification({
    required String segment,
    required String title,
    required String body,
  }) async {
    try {
      final res = await _api.post(
        ApiConstants.platformBulkNotification,
        data: {'segment': segment, 'title': title, 'body': body},
      );
      return {'success': true, ..._unwrap(res.data)};
    } on DioException catch (e) {
      return {'success': false, 'message': dioResponseMessage(e) ?? 'Failed to send'};
    } catch (_) {
      return {'success': false, 'message': 'An error occurred'};
    }
  }

  Future<Map<String, dynamic>> getBroadcastHistory({int page = 1, int limit = 20}) async {
    try {
      final res = await _api.get('${ApiConstants.platformBroadcastHistory}?page=$page&limit=$limit');
      final d = _unwrap(res.data);
      return {'success': true, 'broadcasts': d['broadcasts'] ?? [], 'total': d['total'] ?? 0};
    } on DioException catch (e) {
      return {'success': false, 'broadcasts': [], 'message': dioResponseMessage(e) ?? 'Failed'};
    } catch (_) {
      return {'success': false, 'broadcasts': [], 'message': 'An error occurred'};
    }
  }

  Future<Map<String, dynamic>> getComplaints({
    String status = '',
    String search = '',
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final q = <String, String>{'page': '$page', 'limit': '$limit'};
      if (status.isNotEmpty) q['status'] = status;
      if (search.isNotEmpty) q['search'] = search;
      final qs = q.entries.map((e) => '${e.key}=${Uri.encodeComponent(e.value)}').join('&');
      final res = await _api.get('${ApiConstants.platformComplaints}?$qs');
      final d = _unwrap(res.data);
      return {
        'success': true,
        'complaints': d['complaints'] ?? [],
        'total': d['total'] ?? 0,
        'page': d['page'] ?? page,
        'totalPages': d['totalPages'] ?? 1,
      };
    } on DioException catch (e) {
      return {'success': false, 'complaints': [], 'message': dioResponseMessage(e) ?? 'Failed'};
    } catch (_) {
      return {'success': false, 'complaints': [], 'message': 'An error occurred'};
    }
  }

  Future<Map<String, dynamic>> getComplaintDetail(String id) async {
    try {
      final res = await _api.get(ApiConstants.platformComplaintDetail(id));
      return {'success': true, ..._unwrap(res.data)};
    } on DioException catch (e) {
      return {'success': false, 'message': dioResponseMessage(e) ?? 'Failed'};
    } catch (_) {
      return {'success': false, 'message': 'An error occurred'};
    }
  }

  Future<Map<String, dynamic>> resolveComplaint(String id, {required String note}) async {
    try {
      final res = await _api.post(
        ApiConstants.platformComplaintResolve(id),
        data: {'resolution_note': note},
      );
      return {'success': true, ..._unwrap(res.data)};
    } on DioException catch (e) {
      return {'success': false, 'message': dioResponseMessage(e) ?? 'Failed'};
    } catch (_) {
      return {'success': false, 'message': 'An error occurred'};
    }
  }

  Future<Map<String, dynamic>> getAppConfig() async {
    try {
      final res = await _api.get(ApiConstants.platformConfig);
      return {'success': true, ..._unwrap(res.data)};
    } on DioException catch (e) {
      return {'success': false, 'message': dioResponseMessage(e) ?? 'Failed'};
    } catch (_) {
      return {'success': false, 'message': 'An error occurred'};
    }
  }

  Future<Map<String, dynamic>> updateAppConfig(Map<String, dynamic> settings) async {
    try {
      final res = await _api.patch(ApiConstants.platformConfig, data: settings);
      return {'success': true, ..._unwrap(res.data)};
    } on DioException catch (e) {
      return {'success': false, 'message': dioResponseMessage(e) ?? 'Failed'};
    } catch (_) {
      return {'success': false, 'message': 'An error occurred'};
    }
  }

}
