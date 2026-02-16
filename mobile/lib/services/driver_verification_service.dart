import 'package:dio/dio.dart';
import '../core/constants/api_constants.dart';
import 'api_service.dart';

class DriverVerificationService {
  final ApiService _apiService = ApiService();

  /// Get my verification status
  Future<Map<String, dynamic>> getMyStatus() async {
    try {
      final response = await _apiService.get(ApiConstants.driverVerification);
      final data = response.data['data'] ?? {};
      return {
        'success': true,
        'status': data['status'] ?? 'none',
        'request': data['request'],
      };
    } on DioException catch (e) {
      return {
        'success': false,
        'status': 'none',
        'message': e.response?.data['message'] ?? 'Failed to get status',
      };
    } catch (e) {
      return {'success': false, 'status': 'none', 'message': 'An error occurred'};
    }
  }

  /// Submit driver verification
  Future<Map<String, dynamic>> submitVerification({
    required String drivingLicenseNumber,
    String? drivingLicenseUrl,
    required String vehicleRegistration,
    required String vehicleType,
    required String vehicleModel,
    String? vehicleModelId,
    required int vehicleCapacity,
    String? rcDocumentUrl,
    String? permitDocumentUrl,
    String? insuranceDocumentUrl,
    String? aadhaarDocumentUrl,
  }) async {
    try {
      final response = await _apiService.post(
        ApiConstants.driverVerification,
        data: {
          'driving_license_number': drivingLicenseNumber,
          if (drivingLicenseUrl != null) 'driving_license_url': drivingLicenseUrl,
          'vehicle_registration': vehicleRegistration,
          'vehicle_type': vehicleType,
          'vehicle_model': vehicleModel,
          if (vehicleModelId != null) 'vehicle_model_id': vehicleModelId,
          'vehicle_capacity': vehicleCapacity,
          if (rcDocumentUrl != null) 'rc_document_url': rcDocumentUrl,
          if (permitDocumentUrl != null) 'permit_document_url': permitDocumentUrl,
          if (insuranceDocumentUrl != null) 'insurance_document_url': insuranceDocumentUrl,
          if (aadhaarDocumentUrl != null) 'aadhaar_document_url': aadhaarDocumentUrl,
        },
      );
      return {
        'success': true,
        'message': response.data['message'] ?? 'Verification submitted',
      };
    } on DioException catch (e) {
      return {
        'success': false,
        'message': e.response?.data['message'] ?? 'Failed to submit',
      };
    } catch (e) {
      return {'success': false, 'message': 'An error occurred'};
    }
  }
}
