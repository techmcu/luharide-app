import 'package:dio/dio.dart';
import 'api_service.dart';
import '../core/constants/api_constants.dart';

class ReviewService {
  final ApiService _apiService = ApiService();

  /// In-memory cache for rating summary (per userId) — avoids repeated API calls on rebuild.
  static final Map<String, _CachedRating> _ratingCache = {};
  static const _cacheDuration = Duration(minutes: 5);

  static void _pruneExpiredCache() {
    final now = DateTime.now();
    _ratingCache.removeWhere((_, v) => now.difference(v.at).compareTo(_cacheDuration) > 0);
  }

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
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      final serverMsg = e.response?.data is Map
          ? (e.response!.data['message'] as String?) ?? ''
          : '';
      String message;
      if (status == 404) {
        message = 'Booking not found. It may have been cancelled or expired.';
      } else if (status == 400 && serverMsg.isNotEmpty) {
        message = serverMsg;
      } else if (status == 403) {
        message = 'You can only rate your own ride.';
      } else {
        message = serverMsg.isNotEmpty ? serverMsg : 'Failed to submit rating. Please try again.';
      }
      return {'success': false, 'message': message};
    } catch (e) {
      return {'success': false, 'message': 'Failed to submit rating. Please try again.'};
    }
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

  /// Get rating summary for a user (for profile) — cached 5 min to reduce server load.
  Future<Map<String, dynamic>> getUserRatingSummary(String userId) async {
    _pruneExpiredCache();
    final cached = _ratingCache[userId];
    if (cached != null) return cached.data;

    try {
      final response = await _apiService.get(ApiConstants.userRatingSummary(userId));
      final data = response.data['data'];
      final result = {
        'success': true,
        'total_ratings': data?['total_ratings'] ?? 0,
        'average_rating': (data?['average_rating'] ?? 0.0).toDouble(),
      };
      _ratingCache[userId] = _CachedRating(data: result, at: DateTime.now());
      return result;
    } catch (e) {
      return {'success': false, 'total_ratings': 0, 'average_rating': 0.0};
    }
  }
}

class _CachedRating {
  final Map<String, dynamic> data;
  final DateTime at;
  _CachedRating({required this.data, required this.at});
}
