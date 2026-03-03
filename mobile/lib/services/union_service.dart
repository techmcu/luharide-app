import 'package:dio/dio.dart';

import '../core/constants/api_constants.dart';
import 'api_service.dart';

class UnionService {
  final ApiService _api = ApiService();

  /// Register a new taxi union for the current logged-in user.
  Future<Map<String, dynamic>> registerUnion({
    required String name,
    required String location,
    String? contactPhone,
    String? contactEmail,
  }) async {
    try {
      final response = await _api.post(
        '/union/register',
        data: {
          'name': name,
          'location': location,
          if (contactPhone != null && contactPhone.isNotEmpty)
            'contact_phone': contactPhone,
          if (contactEmail != null && contactEmail.isNotEmpty)
            'contact_email': contactEmail,
        },
      );

      return {
        'success': true,
        'union': response.data['data']?['union'] ?? response.data['data'],
        'message': response.data['message'] ?? 'Union registered',
      };
    } on DioException catch (e) {
      return {
        'success': false,
        'message': e.response?.data['message'] ?? 'Failed to register union',
      };
    } catch (_) {
      return {
        'success': false,
        'message': 'An unexpected error occurred',
      };
    }
  }

  /// Get union dashboard stats for the current union admin.
  Future<Map<String, dynamic>> getDashboard() async {
    try {
      final response = await _api.get(ApiConstants.unionDashboard);
      return {
        'success': true,
        'data': response.data['data'] ?? {},
      };
    } on DioException catch (e) {
      return {
        'success': false,
        'message': e.response?.data['message'] ?? 'Failed to load dashboard',
      };
    } catch (_) {
      return {
        'success': false,
        'message': 'An unexpected error occurred',
      };
    }
  }

  /// Get basic read-only list of drivers for this union admin.
  Future<Map<String, dynamic>> getDrivers() async {
    try {
      final response = await _api.get('/union/drivers');
      return {
        'success': true,
        'drivers': response.data['data']?['drivers'] ?? [],
      };
    } on DioException catch (e) {
      return {
        'success': false,
        'message': e.response?.data['message'] ?? 'Failed to load drivers',
      };
    } catch (_) {
      return {
        'success': false,
        'message': 'An unexpected error occurred',
      };
    }
  }
}

