import 'package:flutter/material.dart';
import '../../../../services/review_service.dart';
import '../../../../services/review_cache_store.dart';

/// Rating summary + latest reviews for another user (e.g. driver on trip details).
/// Uses stale-while-revalidate: shows cached data instantly, refreshes in background.
class UserReviewsScreen extends StatefulWidget {
  final String userId;
  final String displayName;

  const UserReviewsScreen({super.key, required this.userId, required this.displayName});

  @override
  State<UserReviewsScreen> createState() => _UserReviewsScreenState();
}

class _UserReviewsScreenState extends State<UserReviewsScreen> {
  final ReviewService _reviewService = ReviewService();
  final List<Map<String, dynamic>> _reviews = [];
  int _total = 0;
  double _avgRating = 0;
  bool _summaryLoaded = false;
  bool _isLoading = true;
  bool _hasMore = false;
  int _windowMax = 50;
  bool _fromCache = false;
  bool _refreshing = false;

  @override
  void initState() {
    super.initState();
    _loadCacheThenRefresh();
  }

  Future<void> _loadCacheThenRefresh() async {
    final cached = await ReviewCacheStore.readBundle(widget.userId);
    if (cached != null && mounted) {
      _applyData(cached, isCache: true);
    }

    if (!mounted) return;
    setState(() => _refreshing = true);
    final result = await _reviewService.fetchUserReviewBundle(widget.userId);
    if (!mounted) return;
    if (result['success'] == true) {
      _applyData(result, isCache: false);
    } else if (_reviews.isEmpty) {
      setState(() {
        _isLoading = false;
        _refreshing = false;
      });
    } else {
      setState(() => _refreshing = false);
    }
  }

  void _applyData(Map<String, dynamic> data, {required bool isCache}) {
    final list = data['reviews'] as List? ?? [];
    final rawTotal = data['total'] ?? data['total_ratings'];
    setState(() {
      _isLoading = false;
      _refreshing = false;
      _summaryLoaded = true;
      _fromCache = isCache;
      _total = (rawTotal as num?)?.toInt() ?? 0;
      _avgRating = (data['average_rating'] as num?)?.toDouble() ?? 0.0;
      _hasMore = data['has_more'] == true;
      _windowMax = (data['reviews_window_max'] as num?)?.toInt() ?? 50;
      _reviews.clear();
      _reviews.addAll(List<Map<String, dynamic>>.from(list));
    });
  }

  Future<void> _onRefresh() async {
    final result = await _reviewService.fetchUserReviewBundle(widget.userId);
    if (!mounted) return;
    if (result['success'] == true) {
      _applyData(result, isCache: false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.displayName}\'s ratings'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: _isLoading && _reviews.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : _reviews.isEmpty && _total == 0
              ? _buildEmptyState()
              : RefreshIndicator(
                  onRefresh: _onRefresh,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      if (_summaryLoaded) _buildSummaryChip(),
                      if (_refreshing)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Row(
                            children: [
                              const SizedBox(
                                width: 14, height: 14,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Updating...',
                                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                              ),
                            ],
                          ),
                        ),
                      if (_hasMore)
                        Padding(
                          padding: const EdgeInsets.only(top: 8, bottom: 8),
                          child: Text(
                            'Showing latest $_windowMax of $_total reviews.',
                            style: TextStyle(fontSize: 12.5, color: Colors.grey[700], height: 1.35),
                          ),
                        ),
                      if (_fromCache && !_refreshing)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text(
                            'Cached — pull to refresh.',
                            style: TextStyle(fontSize: 12, color: Colors.orange[800]),
                          ),
                        ),
                      const SizedBox(height: 8),
                      ..._reviews.map((r) => _buildRatingCard(r)),
                    ],
                  ),
                ),
    );
  }

  Widget _buildSummaryChip() {
    final avgStr = _avgRating > 0 ? _avgRating.toStringAsFixed(1) : '0';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.amber[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber[200]!),
      ),
      child: Row(
        children: [
          Icon(Icons.star, color: Colors.amber[700], size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _total == 0 ? 'No ratings yet' : '$avgStr ★ ($_total reviews)',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.amber[900]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.star_outline, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text('No ratings yet', style: TextStyle(fontSize: 18, color: Colors.grey[600])),
        ],
      ),
    );
  }

  static String _timeAgo(String? raw) {
    if (raw == null || raw.isEmpty) return '';
    final dt = DateTime.tryParse(raw.endsWith('Z') ? raw : '${raw}Z');
    if (dt == null) return '';
    final diff = DateTime.now().toUtc().difference(dt.toUtc());
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    if (diff.inDays < 30) return '${(diff.inDays / 7).floor()}w ago';
    if (diff.inDays < 365) return '${(diff.inDays / 30).floor()}mo ago';
    return '${(diff.inDays / 365).floor()}y ago';
  }

  Widget _buildRatingCard(Map<String, dynamic> r) {
    final rating = (r['rating'] is int) ? r['rating'] as int : int.tryParse(r['rating']?.toString() ?? '0') ?? 0;
    final comment = r['comment'] as String? ?? '';
    final fromName = r['from_name'] as String? ?? 'User';
    final fromRole = r['from_role']?.toString() ?? '';
    final timeAgo = _timeAgo(r['created_at']?.toString());
    final tripContext = r['trip_context'] as String? ?? '';
    final isDriver = fromRole == 'driver';
    final roleLabel = isDriver ? 'Driver' : 'Passenger';
    final roleColor = isDriver ? Colors.green : Colors.blue;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0.5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text.rich(
                    TextSpan(children: [
                      TextSpan(
                        text: fromName,
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                      ),
                      if (fromRole.isNotEmpty)
                        TextSpan(
                          text: ' ($roleLabel)',
                          style: TextStyle(fontSize: 12, color: roleColor, fontWeight: FontWeight.w500),
                        ),
                    ]),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (timeAgo.isNotEmpty)
                  Text(timeAgo, style: TextStyle(fontSize: 11, color: Colors.grey[400])),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                ...List.generate(
                  5,
                  (i) => Icon(
                    i < rating ? Icons.star_rounded : Icons.star_outline_rounded,
                    color: Colors.amber,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  '$rating/5',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.grey[600]),
                ),
              ],
            ),
            if (comment.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                '"$comment"',
                style: TextStyle(fontSize: 13, color: Colors.grey[700], fontStyle: FontStyle.italic),
              ),
            ],
            if (tripContext.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                tripContext,
                style: TextStyle(fontSize: 11, color: Colors.grey[400]),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
