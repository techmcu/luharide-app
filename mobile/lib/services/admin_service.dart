import 'package:dio/dio.dart';
import '../core/constants/api_constants.dart';
import 'api_service.dart';

class AdminService {
  final ApiService _apiService = ApiService();

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
}
