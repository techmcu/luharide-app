import 'package:cross_file/cross_file.dart';
import 'package:dio/dio.dart';

import '../core/constants/api_constants.dart';
import '../core/utils/api_error_messages.dart';
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
      throw Exception('Too small — use at least ~50 KB.');
    }
    if (bytes.length > kUploadMaxBytes) {
      throw Exception('Too large — max 20 MB.');
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

  String? _extractUploadUrl(dynamic body) {
    if (body is! Map) return null;
    final m = Map<String, dynamic>.from(body);
    final top = m['url'];
    if (top is String && top.trim().isNotEmpty) return top.trim();
    final inner = m['data'];
    if (inner is Map) {
      final u = Map<String, dynamic>.from(inner)['url'];
      if (u is String && u.trim().isNotEmpty) return u.trim();
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
      final ok = (response.statusCode == 200 || response.statusCode == 201) &&
          response.data is Map &&
          response.data['success'] == true;
      final url = _extractUploadUrl(response.data);
      if (ok && url != null) return url;
      final msg = response.data is Map
          ? response.data['message'] as String?
          : null;
      throw Exception(msg ?? 'Failed to upload document');
    } on DioException catch (e) {
      throw Exception(_uploadFriendlyError(e));
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
      final ok = (response.statusCode == 200 || response.statusCode == 201) &&
          response.data is Map &&
          response.data['success'] == true;
      final url = _extractUploadUrl(response.data);
      if (ok && url != null) return url;
      final msg = response.data is Map
          ? response.data['message'] as String?
          : null;
      throw Exception(msg ?? 'Failed to upload document');
    } on DioException catch (e) {
      throw Exception(_uploadFriendlyError(e));
    }
  }

  String _uploadFriendlyError(DioException e) {
    final sc = e.response?.statusCode;
    if (sc == 413) {
      return _dioMessage(e) ?? 'Too large — max 20 MB.';
    }
    if (sc == 400) {
      return _dioMessage(e) ?? 'Upload rejected. Check file type and size.';
    }
    if (sc == 401) {
      return 'Session expired. Please log in again and retry.';
    }
    if (sc == 502 || sc == 503 || sc == 504) {
      return userMessageFromDio(e);
    }
    if (sc != null && sc >= 500) {
      return _dioMessage(e) ?? 'Upload failed (server error). Please try again.';
    }
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.sendTimeout ||
        e.type == DioExceptionType.receiveTimeout) {
      return userMessageFromDio(e);
    }
    if (e.type == DioExceptionType.connectionError) {
      return userMessageFromDio(e);
    }
    return _dioMessage(e) ?? 'Upload failed. Please try again.';
  }
}
