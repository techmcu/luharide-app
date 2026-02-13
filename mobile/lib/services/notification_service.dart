import 'package:dio/dio.dart';
import '../core/constants/api_constants.dart';
import '../models/notification_model.dart';
import 'api_service.dart';

class NotificationService {
  final ApiService _apiService = ApiService();

  /// Get current user's notifications (raw map response)
  Future<Map<String, dynamic>> getNotifications() async {
    try {
      final response = await _apiService.get(ApiConstants.notifications);
      final data = response.data['data'] ?? {};
      return {
        'success': true,
        'notifications': data['notifications'] ?? [],
      };
    } on DioException catch (_) {
      return {'success': false, 'notifications': <dynamic>[]};
    } catch (_) {
      return {'success': false, 'notifications': <dynamic>[]};
    }
  }

  /// Get notifications as strongly-typed models
  Future<List<NotificationModel>> fetchNotificationModels() async {
    final result = await getNotifications();
    if (result['success'] != true) return [];
    final list = result['notifications'] as List? ?? [];
    return list
        .whereType<Map<String, dynamic>>()
        .map(NotificationModel.fromJson)
        .toList();
  }

  /// Mark notification as read
  Future<bool> markAsRead(String id) async {
    try {
      await _apiService.post('${ApiConstants.notifications}/$id/read');
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Mark all as read
  Future<bool> markAllAsRead() async {
    try {
      await _apiService.post('${ApiConstants.notifications}/read-all');
      return true;
    } catch (_) {
      return false;
    }
  }
}

