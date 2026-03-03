import 'package:dio/dio.dart';
import '../core/constants/api_constants.dart';
import 'api_service.dart';

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
      final data = response.data['data'] ?? {};
      return {
        'success': true,
        'requests': data['requests'] ?? [],
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

  /// Get pending union registration requests
  Future<Map<String, dynamic>> getUnionRequests() async {
    try {
      final response = await _apiService.get(ApiConstants.adminUnionRequests);
      final data = response.data['data'] ?? {};
      return {
        'success': true,
        'requests': data['requests'] ?? [],
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

  /// Approve driver request
  Future<Map<String, dynamic>> approveDriver(String requestId) async {
    try {
      await _apiService.post('${ApiConstants.adminDriverRequests}/$requestId/approve');
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

  /// Approve union request
  Future<Map<String, dynamic>> approveUnion(String unionId) async {
    try {
      await _apiService.post('${ApiConstants.adminUnionRequests}/$unionId/approve');
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
}
