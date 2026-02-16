import 'api_service.dart';
import '../core/constants/api_constants.dart';

class ReviewService {
  final ApiService _apiService = ApiService();

  /// Submit rating for a booking (passenger rates driver, or driver rates passenger)
  /// Comment max 20 words (enforced in UI and backend)
  Future<Map<String, dynamic>> submitRating({
    required String bookingId,
    required int rating,
    String comment = '',
  }) async {
    try {
      final response = await _apiService.post(
        ApiConstants.rateBooking(bookingId),
        data: {
          'rating': rating,
          'comment': comment.trim(),
        },
      );
      return {
        'success': true,
        'message': response.data['message'] ?? 'Thank you for your rating',
      };
    } catch (e) {
      final message = e.toString().contains('400') || e.toString().contains('message')
          ? _extractMessage(e)
          : 'Failed to submit rating';
      return {'success': false, 'message': message};
    }
  }

  String _extractMessage(dynamic e) {
    try {
      if (e is Exception && e.toString().contains('message')) {
        final str = e.toString();
        final start = str.indexOf('"message":"') + 11;
        final end = str.indexOf('"', start);
        if (start > 10 && end > start) return str.substring(start, end);
      }
    } catch (_) {}
    return 'Failed to submit rating';
  }

  /// Get my received ratings (paginated). page 1-based, limit default 20.
  Future<Map<String, dynamic>> getMyReviews({int page = 1, int limit = 20}) async {
    try {
      final url = '${ApiConstants.myReviews}?page=$page&limit=$limit';
      final response = await _apiService.get(url);
      final data = response.data['data'];
      final list = data?['reviews'] as List? ?? [];
      final total = (data?['total'] as num?)?.toInt() ?? 0;
      final hasMore = data?['has_more'] == true;
      return {
        'success': true,
        'reviews': list,
        'total': total,
        'has_more': hasMore,
        'page': page,
      };
    } catch (e) {
      return {'success': false, 'reviews': <dynamic>[], 'total': 0, 'has_more': false};
    }
  }

  /// Get reviews for a user (e.g. driver on trip details) – paginated.
  Future<Map<String, dynamic>> getReviewsForUser(String userId, {int page = 1, int limit = 20}) async {
    try {
      final response = await _apiService.get(ApiConstants.userReviews(userId, page: page, limit: limit));
      final data = response.data['data'];
      final list = data?['reviews'] as List? ?? [];
      final total = (data?['total'] as num?)?.toInt() ?? 0;
      final hasMore = data?['has_more'] == true;
      return {
        'success': true,
        'reviews': list,
        'total': total,
        'has_more': hasMore,
        'page': page,
      };
    } catch (e) {
      return {'success': false, 'reviews': <dynamic>[], 'total': 0, 'has_more': false};
    }
  }

  /// Get rating summary for a user (for profile)
  Future<Map<String, dynamic>> getUserRatingSummary(String userId) async {
    try {
      final response = await _apiService.get(ApiConstants.userRatingSummary(userId));
      final data = response.data['data'];
      return {
        'success': true,
        'total_ratings': data?['total_ratings'] ?? 0,
        'average_rating': (data?['average_rating'] ?? 0.0).toDouble(),
      };
    } catch (e) {
      return {'success': false, 'total_ratings': 0, 'average_rating': 0.0};
    }
  }
}
