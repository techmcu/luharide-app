import 'dart:io';

import 'package:dio/dio.dart';

import '../core/constants/api_constants.dart';
import 'api_service.dart';

class UploadService {
  final ApiService _api = ApiService();

  Future<String> uploadDriverDocument(File file) async {
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(file.path),
    });
    final response = await _api.post(
      ApiConstants.uploadDriverDoc,
      data: formData,
      options: Options(contentType: 'multipart/form-data'),
    );
    if (response.statusCode == 200 && response.data['success'] == true) {
      return response.data['url'] as String;
    }
    throw Exception(response.data['message'] ?? 'Failed to upload document');
  }

  Future<String> uploadUnionDocument(File file) async {
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(file.path),
    });
    final response = await _api.post(
      ApiConstants.uploadUnionDoc,
      data: formData,
      options: Options(contentType: 'multipart/form-data'),
    );
    if (response.statusCode == 200 && response.data['success'] == true) {
      return response.data['url'] as String;
    }
    throw Exception(response.data['message'] ?? 'Failed to upload document');
  }
}

