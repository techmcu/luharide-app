import 'package:cross_file/cross_file.dart';
import 'package:dio/dio.dart';

import '../core/constants/api_constants.dart';
import 'api_service.dart';

/// Uses [XFile] + bytes so uploads work on **Web** (no dart:io / fromFile).
/// Keep min/max in sync with backend [uploadLimits.js] (default 50 KB min, 20 MB max).
class UploadService {
  final ApiService _api = ApiService();

  static const int kUploadMinBytes = 50 * 1024;
  static const int kUploadMaxBytes = 20 * 1024 * 1024;

  Future<MultipartFile> _filePartFromBytes(XFile file) async {
    final bytes = await file.readAsBytes();
    if (bytes.length < kUploadMinBytes) {
      throw Exception(
        'File too small (minimum about 50 KB). Please upload a clear JPEG or PNG.',
      );
    }
    if (bytes.length > kUploadMaxBytes) {
      throw Exception(
        'File too large (maximum 20 MB). Choose a smaller file.',
      );
    }
    final name = file.name;
    return MultipartFile.fromBytes(
      bytes,
      filename: name.isNotEmpty ? name : 'upload.jpg',
    );
  }

  String? _dioMessage(DioException e) {
    final data = e.response?.data;
    if (data is Map && data['message'] is String) {
      return data['message'] as String;
    }
    return null;
  }

  Future<String> uploadDriverDocument(XFile file) async {
    final formData = FormData.fromMap({
      'file': await _filePartFromBytes(file),
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
          _dioMessage(e) ??
              'File too large for server (max 20 MB). Choose a smaller file.',
        );
      }
      if (e.response?.statusCode == 400) {
        throw Exception(
          _dioMessage(e) ?? 'Upload rejected. Check file type and size.',
        );
      }
      rethrow;
    }
  }

  Future<String> uploadUnionDocument(XFile file) async {
    final formData = FormData.fromMap({
      'file': await _filePartFromBytes(file),
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
          _dioMessage(e) ??
              'File too large for server (max 20 MB). Choose a smaller file.',
        );
      }
      if (e.response?.statusCode == 400) {
        throw Exception(
          _dioMessage(e) ?? 'Upload rejected. Check file type and size.',
        );
      }
      rethrow;
    }
  }
}
