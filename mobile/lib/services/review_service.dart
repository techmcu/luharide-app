import 'package:dio/dio.dart';
import 'api_service.dart';
import 'review_cache_store.dart';
import '../core/constants/api_constants.dart';

class ReviewService {
  final ApiService _apiService = ApiService();

  /// In-memory cache for rating summary (per userId) — trip cards / profile chips.
  static final Map<String, _CachedRating> _ratingCache = {};
  static const _cacheDuration = Duration(minutes: 15);

  static void _pruneExpiredCache() {
    final now = DateTime.now();
    _ratingCache.removeWhere((_, v) => now.difference(v.at).compareTo(_cacheDuration) > 0);
  }

  static void clearMemoryCacheForUser(String? userId) {
    if (userId == null || userId.isEmpty) return;
    _ratingCache.remove(userId);
  }

  static void clearAllMemoryCache() => _ratingCache.clear();

  /// One small summary request on login; if fingerprint changed, drop cached review list for that user.
  static Future<void> refreshFingerprintAfterLogin(String userId) async {
    if (userId.isEmpty) return;
    try {
      final api = ApiService();
      final response = await api.get(ApiConstants.userRatingSummary(userId));
      final raw = response.data['data'];
      if (raw is! Map) return;
      final data = Map<String, dynamic>.from(raw);
      final fp = ReviewCacheStore.fingerprintFromSummary(data);
      final old = await ReviewCacheStore.readFingerprint(userId);
      if (old != null && old != fp) {
        await ReviewCacheStore.clearBundle(userId);
        _ratingCache.remove(userId);
      }
      await ReviewCacheStore.writeFingerprint(userId, fp);
    } catch (_) {}
  }

  /// Submit rating for a booking (passenger rates driver, or driver rates passenger)
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
      final raw = response.data['data'];
      String? ratedUid;
      if (raw is Map) {
        final v = raw['rated_user_id'];
        if (v != null) ratedUid = v.toString();
      }
      if (ratedUid != null && ratedUid.isNotEmpty) {
        await ReviewCacheStore.clearBundle(ratedUid);
        _ratingCache.remove(ratedUid);
      }
      return {
        'success': true,
        'message': response.data['message'] ?? 'Thank you for your rating',
        if (ratedUid != null) 'rated_user_id': ratedUid,
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

  /// Get my received ratings (paginated). Server caps window (latest N in DB still grow unbounded).
  Future<Map<String, dynamic>> getMyReviews({int page = 1, int limit = 50}) async {
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

  /// Get reviews for a user — paginated within server window.
  Future<Map<String, dynamic>> getReviewsForUser(String userId, {int page = 1, int limit = 50}) async {
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

  /// One request: summary + up to [reviews_window_max] newest reviews; updates disk cache.
  Future<Map<String, dynamic>> fetchUserReviewBundle(String userId) async {
    try {
      final response = await _apiService.get(ApiConstants.userReviewBundle(userId));
      final raw = response.data['data'];
      if (raw is! Map) {
        return {'success': false, 'reviews': <dynamic>[], 'total': 0, 'has_more': false};
      }
      final data = Map<String, dynamic>.from(raw);
      final list = data['reviews'] as List? ?? [];
      final total = (data['total_ratings'] as num?)?.toInt() ?? 0;
      final fp = ReviewCacheStore.fingerprintFromSummary(data);
      await ReviewCacheStore.writeBundle(userId, data);
      await ReviewCacheStore.writeFingerprint(userId, fp);
      _ratingCache.remove(userId);
      return {
        'success': true,
        'reviews': list,
        'total': total,
        'has_more': data['has_more'] == true,
        'average_rating': (data['average_rating'] as num?)?.toDouble() ?? 0.0,
        'latest_review_at': data['latest_review_at'],
        'reviews_window_max': (data['reviews_window_max'] as num?)?.toInt() ?? 50,
        'from_cache': false,
      };
    } catch (e) {
      return {'success': false, 'reviews': <dynamic>[], 'total': 0, 'has_more': false};
    }
  }

  /// Network first; on failure (offline) fall back to last saved bundle for this user.
  Future<Map<String, dynamic>> loadUserReviewBundleWithCache(String userId) async {
    final net = await fetchUserReviewBundle(userId);
    if (net['success'] == true) return net;
    final cached = await ReviewCacheStore.readBundle(userId);
    if (cached != null) {
      final list = cached['reviews'] as List? ?? [];
      final total = (cached['total_ratings'] as num?)?.toInt() ?? 0;
      return {
        'success': true,
        'reviews': list,
        'total': total,
        'has_more': cached['has_more'] == true,
        'average_rating': (cached['average_rating'] as num?)?.toDouble() ?? 0.0,
        'from_cache': true,
        'reviews_window_max': (cached['reviews_window_max'] as num?)?.toInt() ?? 50,
      };
    }
    return net;
  }

  /// Get rating summary for a user (for trip details row) — short in-memory TTL.
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
        'latest_review_at': data?['latest_review_at'],
        'reviews_window_max': (data?['reviews_window_max'] as num?)?.toInt() ?? 50,
      };
      _ratingCache[userId] = _CachedRating(data: result, at: DateTime.now());
      return result;
    } catch (e) {
      return {'success': false, 'total_ratings': 0, 'average_rating': 0.0, 'reviews_window_max': 50};
    }
  }
}

class _CachedRating {
  final Map<String, dynamic> data;
  final DateTime at;
  _CachedRating({required this.data, required this.at});
}
