import 'package:dio/dio.dart';

import '../core/constants/api_constants.dart';
import '../core/utils/api_error_messages.dart';
import 'api_service.dart';

class UnionService {
  final ApiService _api = ApiService();

  /// Register a new taxi union for the current logged-in user.
  Future<Map<String, dynamic>> registerUnion({
    required String name,
    required String location,
    String? contactPhone,
    String? contactEmail,
    String? ownerName,
    String? ownerAadhaarUrl,
    String? ownerAadhaarFrontUrl,
    String? ownerAadhaarBackUrl,
    String? officePhotoUrl,
    String? unionPhotoUrl,
    String? unionDriverListPhotoUrl,
    String? leaderDrivingLicenseFrontUrl,
    String? leaderDrivingLicenseBackUrl,
    String? ownerVehicleRcUrl,
    String? ownerVehicleRcFrontUrl,
    String? ownerVehicleRcBackUrl,
    String? unionShareNotes,
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
          if (ownerName != null && ownerName.isNotEmpty)
            'owner_name': ownerName,
          if (ownerAadhaarUrl != null && ownerAadhaarUrl.isNotEmpty)
            'owner_aadhaar_url': ownerAadhaarUrl,
          if (ownerAadhaarFrontUrl != null && ownerAadhaarFrontUrl.isNotEmpty)
            'owner_aadhaar_front_url': ownerAadhaarFrontUrl,
          if (ownerAadhaarBackUrl != null && ownerAadhaarBackUrl.isNotEmpty)
            'owner_aadhaar_back_url': ownerAadhaarBackUrl,
          if (officePhotoUrl != null && officePhotoUrl.isNotEmpty)
            'office_photo_url': officePhotoUrl,
          if (unionPhotoUrl != null && unionPhotoUrl.isNotEmpty)
            'union_photo_url': unionPhotoUrl,
          if (unionDriverListPhotoUrl != null && unionDriverListPhotoUrl.isNotEmpty)
            'union_driver_list_photo_url': unionDriverListPhotoUrl,
          if (leaderDrivingLicenseFrontUrl != null && leaderDrivingLicenseFrontUrl.isNotEmpty)
            'leader_driving_license_front_url': leaderDrivingLicenseFrontUrl,
          if (leaderDrivingLicenseBackUrl != null && leaderDrivingLicenseBackUrl.isNotEmpty)
            'leader_driving_license_back_url': leaderDrivingLicenseBackUrl,
          if (ownerVehicleRcUrl != null && ownerVehicleRcUrl.isNotEmpty)
            'owner_vehicle_rc_url': ownerVehicleRcUrl,
          if (ownerVehicleRcFrontUrl != null && ownerVehicleRcFrontUrl.isNotEmpty)
            'owner_vehicle_rc_front_url': ownerVehicleRcFrontUrl,
          if (ownerVehicleRcBackUrl != null && ownerVehicleRcBackUrl.isNotEmpty)
            'owner_vehicle_rc_back_url': ownerVehicleRcBackUrl,
          if (unionShareNotes != null && unionShareNotes.trim().isNotEmpty)
            'union_share_notes': unionShareNotes.trim(),
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
        'message': dioResponseMessage(e) ?? 'Failed to register union',
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
        'message': dioResponseMessage(e) ?? 'Failed to load dashboard',
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
        'message': dioResponseMessage(e) ?? 'Failed to load union status',
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
        'message': dioResponseMessage(e) ?? 'Failed to load drivers',
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
        'message': dioResponseMessage(e) ?? 'Failed to add driver',
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
        'message': dioResponseMessage(e) ?? 'Failed to load routes',
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
        'message': dioResponseMessage(e) ?? 'Failed to add route',
      };
    } catch (_) {
      return {
        'success': false,
        'message': 'An unexpected error occurred',
      };
    }
  }

  /// Remove a driver from the union.
  Future<Map<String, dynamic>> deleteDriver(String driverId) async {
    try {
      await _api.delete('/union/drivers/$driverId');
      return {'success': true};
    } on DioException catch (e) {
      return {
        'success': false,
        'message': dioResponseMessage(e) ?? 'Failed to remove driver',
      };
    } catch (_) {
      return {'success': false, 'message': 'An unexpected error occurred'};
    }
  }

  /// Remove a preset route from the union.
  Future<Map<String, dynamic>> deleteRoute(String routeId) async {
    try {
      await _api.delete('/union/routes/$routeId');
      return {'success': true};
    } on DioException catch (e) {
      return {
        'success': false,
        'message': dioResponseMessage(e) ?? 'Failed to remove route',
      };
    } catch (_) {
      return {'success': false, 'message': 'An unexpected error occurred'};
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
            dioResponseMessage(e) ?? 'Failed to create rides for drivers',
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
        'message': dioResponseMessage(e) ?? 'Failed to load schedules',
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
        'message': dioResponseMessage(e) ?? 'Failed to cancel ride',
      };
    } catch (_) {
      return {
        'success': false,
        'message': 'An unexpected error occurred',
      };
    }
  }

  /// Update KYC document URLs and optional stand/share notes (approved union admin).
  Future<Map<String, dynamic>> updateUnionDocuments({
    String? ownerName,
    String? ownerAadhaarUrl,
    String? officePhotoUrl,
    String? ownerVehicleRcUrl,
    String? unionShareNotes,
  }) async {
    try {
      final response = await _api.patch(
        '/union/me/documents',
        data: {
          if (ownerName != null) 'owner_name': ownerName,
          if (ownerAadhaarUrl != null) 'owner_aadhaar_url': ownerAadhaarUrl,
          if (officePhotoUrl != null) 'office_photo_url': officePhotoUrl,
          if (ownerVehicleRcUrl != null) 'owner_vehicle_rc_url': ownerVehicleRcUrl,
          if (unionShareNotes != null) 'union_share_notes': unionShareNotes,
        },
      );
      return {
        'success': true,
        'union': response.data['data']?['union'],
        'message': response.data['message'] ?? 'Updated',
      };
    } on DioException catch (e) {
      return {
        'success': false,
        'message': dioResponseMessage(e) ?? 'Failed to update documents',
      };
    } catch (_) {
      return {'success': false, 'message': 'An unexpected error occurred'};
    }
  }

  /// Update poster branding/settings for this union.
  Future<Map<String, dynamic>> updateBranding({
    required String posterHeader,
    String? posterCustomText,
    String? posterCustomTextPosition,
    String? posterLayoutType,
    String? posterTheme,
  }) async {
    try {
      final response = await _api.patch(
        '/union/branding',
        data: {
          'poster_header': posterHeader,
          'poster_custom_text': posterCustomText,
          'poster_custom_text_position': posterCustomTextPosition,
          'poster_layout_type': posterLayoutType,
          'poster_theme': posterTheme,
        },
      );
      return {
        'success': true,
        'poster_header': response.data['data']?['poster_header'],
        'poster_custom_text': response.data['data']?['poster_custom_text'],
        'poster_custom_text_position': response.data['data']?['poster_custom_text_position'],
        'poster_layout_type': response.data['data']?['poster_layout_type'],
        'poster_theme': response.data['data']?['poster_theme'],
        'message': response.data['message'] ?? 'Branding updated',
      };
    } on DioException catch (e) {
      return {
        'success': false,
        'message': dioResponseMessage(e) ?? 'Failed to update branding',
      };
    } catch (_) {
      return {'success': false, 'message': 'An unexpected error occurred'};
    }
  }

  /// Download a combined PDF poster for multiple schedules (all on one page, grouped by route).
  Future<Map<String, dynamic>> getCombinedPosterBytes(List<String> ids) async {
    if (ids.isEmpty) return {'success': false, 'message': 'No schedules provided'};
    try {
      final response = await _api.get(
        '/union/schedules/poster-combined',
        queryParameters: {'ids': ids.join(',')},
        options: Options(responseType: ResponseType.bytes),
      );
      final data  = response.data;
      final bytes = data is List<int>
          ? data
          : (data is List<dynamic> ? data.cast<int>() : <int>[]);
      return {'success': true, 'bytes': bytes};
    } on DioException catch (e) {
      return {
        'success': false,
        'message': dioResponseMessage(e) ?? 'Failed to download poster',
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
        'message': dioResponseMessage(e) ?? 'Failed to download poster',
      };
    } catch (_) {
      return {
        'success': false,
        'message': 'An unexpected error occurred while downloading poster',
      };
    }
  }
}

