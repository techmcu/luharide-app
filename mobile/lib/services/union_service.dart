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

  /// Get current user's union + status (pending/approved/rejected/none).
  Future<Map<String, dynamic>> getMyUnion() async {
    try {
      final response = await _api.get('/union/me');
      final data = response.data['data'] ?? {};
      return {
        'success': true,
        'union': data['union'],
        'status': data['status'] ?? 'none',
      };
    } on DioException catch (e) {
      return {
        'success': false,
        'message': e.response?.data['message'] ?? 'Failed to load union status',
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

  /// Add a driver to the union-managed list.
  Future<Map<String, dynamic>> addDriver({
    required String name,
    required String vehicleNumber,
    String? phone,
    String? whatsappNumber,
  }) async {
    try {
      final response = await _api.post(
        '/union/drivers',
        data: {
          'name': name,
          'vehicle_number': vehicleNumber,
          if (phone != null && phone.isNotEmpty) 'phone': phone,
          if (whatsappNumber != null && whatsappNumber.isNotEmpty)
            'whatsapp_number': whatsappNumber,
        },
      );
      return {
        'success': true,
        'driver': response.data['data']?['driver'] ?? response.data['data'],
      };
    } on DioException catch (e) {
      return {
        'success': false,
        'message': e.response?.data['message'] ?? 'Failed to add driver',
      };
    } catch (_) {
      return {
        'success': false,
        'message': 'An unexpected error occurred',
      };
    }
  }

  /// Get preset routes (from/to) for this union.
  Future<Map<String, dynamic>> getRoutes() async {
    try {
      final response = await _api.get('/union/routes');
      return {
        'success': true,
        'routes': response.data['data']?['routes'] ?? [],
      };
    } on DioException catch (e) {
      return {
        'success': false,
        'message': e.response?.data['message'] ?? 'Failed to load routes',
      };
    } catch (_) {
      return {
        'success': false,
        'message': 'An unexpected error occurred',
      };
    }
  }

  /// Add a new preset route.
  Future<Map<String, dynamic>> addRoute({
    required String fromLocation,
    required String toLocation,
  }) async {
    try {
      final response = await _api.post(
        '/union/routes',
        data: {
          'from_location': fromLocation,
          'to_location': toLocation,
        },
      );
      return {
        'success': true,
        'route': response.data['data']?['route'] ?? response.data['data'],
      };
    } on DioException catch (e) {
      return {
        'success': false,
        'message': e.response?.data['message'] ?? 'Failed to add route',
      };
    } catch (_) {
      return {
        'success': false,
        'message': 'An unexpected error occurred',
      };
    }
  }

  /// Bulk create schedules (rides) for multiple drivers.
  Future<Map<String, dynamic>> createSchedulesBulk({
    required String fromLocation,
    required String toLocation,
    required DateTime departureTime,
    required List<String> unionDriverIds,
  }) async {
    try {
      final response = await _api.post(
        '/union/schedules/bulk',
        data: {
          'from_location': fromLocation,
          'to_location': toLocation,
          'departure_time': departureTime.toIso8601String(),
          'union_driver_ids': unionDriverIds,
        },
      );
      return {
        'success': true,
        'schedules': response.data['data']?['schedules'] ?? [],
      };
    } on DioException catch (e) {
      return {
        'success': false,
        'message':
            e.response?.data['message'] ?? 'Failed to create rides for drivers',
      };
    } catch (_) {
      return {
        'success': false,
        'message': 'An unexpected error occurred',
      };
    }
  }

  /// Get union schedules: scope = 'current' or 'recent'.
  Future<Map<String, dynamic>> getSchedules({String scope = 'current'}) async {
    try {
      final response = await _api.get(
        '/union/schedules',
        queryParameters: {'scope': scope},
      );
      return {
        'success': true,
        'schedules': response.data['data']?['schedules'] ?? [],
      };
    } on DioException catch (e) {
      return {
        'success': false,
        'message': e.response?.data['message'] ?? 'Failed to load schedules',
      };
    } catch (_) {
      return {
        'success': false,
        'message': 'An unexpected error occurred',
      };
    }
  }

  /// Cancel a single schedule (if allowed by backend).
  Future<Map<String, dynamic>> cancelSchedule(String id) async {
    try {
      await _api.delete('/union/schedules/$id');
      return {
        'success': true,
        'message': 'Ride cancelled successfully',
      };
    } on DioException catch (e) {
      return {
        'success': false,
        'message': e.response?.data['message'] ?? 'Failed to cancel ride',
      };
    } catch (_) {
      return {
        'success': false,
        'message': 'An unexpected error occurred',
      };
    }
  }

  /// Update the poster branding (custom header line) for this union.
  Future<Map<String, dynamic>> updateBranding({required String posterHeader}) async {
    try {
      final response = await _api.patch(
        '/union/branding',
        data: {'poster_header': posterHeader},
      );
      return {
        'success': true,
        'poster_header': response.data['data']?['poster_header'],
        'message': response.data['message'] ?? 'Branding updated',
      };
    } on DioException catch (e) {
      return {
        'success': false,
        'message': e.response?.data['message'] ?? 'Failed to update branding',
      };
    } catch (_) {
      return {'success': false, 'message': 'An unexpected error occurred'};
    }
  }

  /// Download poster PDF bytes for a given schedule (for sharing/downloading).
  Future<Map<String, dynamic>> getSchedulePosterBytes(String id) async {
    try {
      final response = await _api.get(
        '/union/schedules/$id/poster',
        options: Options(responseType: ResponseType.bytes),
      );
      final data = response.data;
      final bytes = data is List<int>
          ? data
          : (data is List<dynamic> ? data.cast<int>() : <int>[]);
      return {
        'success': true,
        'bytes': bytes,
      };
    } on DioException catch (e) {
      return {
        'success': false,
        'message': e.response?.data['message'] ?? 'Failed to download poster',
      };
    } catch (_) {
      return {
        'success': false,
        'message': 'An unexpected error occurred while downloading poster',
      };
    }
  }
}

