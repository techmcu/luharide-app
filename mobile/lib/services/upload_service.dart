import 'package:cross_file/cross_file.dart';
import 'package:dio/dio.dart';

import '../core/constants/api_constants.dart';
import 'api_service.dart';

/// Uses [XFile] + bytes so uploads work on **Web** (no dart:io / fromFile).
class UploadService {
  final ApiService _api = ApiService();

  Future<MultipartFile> _filePart(XFile file) async {
    final bytes = await file.readAsBytes();
    final name = file.name;
    return MultipartFile.fromBytes(
      bytes,
      filename: name.isNotEmpty ? name : 'upload.jpg',
    );
  }

  Future<String> uploadDriverDocument(XFile file) async {
    final formData = FormData.fromMap({
      'file': await _filePart(file),
    });
    try {
      final response = await _api.post(
        ApiConstants.uploadDriverDoc,
        data: formData,
        options: Options(contentType: 'multipart/form-data'),
      );
      if (response.statusCode == 200 && response.data['success'] == true) {
        return response.data['url'] as String;
      }
      throw Exception(response.data['message'] ?? 'Failed to upload document');
    } on DioException catch (e) {
      if (e.response?.statusCode == 413) {
        throw Exception(
          'Photo file too large for server. Please choose the photo again (smaller size).',
        );
      }
      rethrow;
    }
  }

  Future<String> uploadUnionDocument(XFile file) async {
    final formData = FormData.fromMap({
      'file': await _filePart(file),
    });
    try {
      final response = await _api.post(
        ApiConstants.uploadUnionDoc,
        data: formData,
        options: Options(contentType: 'multipart/form-data'),
      );
      if (response.statusCode == 200 && response.data['success'] == true) {
        return response.data['url'] as String;
      }
      throw Exception(response.data['message'] ?? 'Failed to upload document');
    } on DioException catch (e) {
      if (e.response?.statusCode == 413) {
        throw Exception(
          'Photo file too large for server. Please choose the photo again (smaller size).',
        );
      }
      rethrow;
    }
  }
}

