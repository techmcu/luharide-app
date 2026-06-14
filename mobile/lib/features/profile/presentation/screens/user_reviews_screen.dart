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

  Widget _buildRatingCard(Map<String, dynamic> r) {
    final rating = (r['rating'] is int) ? r['rating'] as int : int.tryParse(r['rating']?.toString() ?? '0') ?? 0;
    final comment = r['comment'] as String? ?? '';
    final fromName = r['from_name'] as String? ?? 'User';
    final fromUserId = r['from_user_id']?.toString();
    final dateRaw = r['created_at'];
    final date = dateRaw != null ? (dateRaw is String ? dateRaw : dateRaw.toString()) : '';

    final canNavigate = fromUserId != null && fromUserId.isNotEmpty && fromUserId != widget.userId;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: canNavigate
            ? () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => UserReviewsScreen(
                      userId: fromUserId,
                      displayName: fromName,
                    ),
                  ),
                )
            : null,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: Colors.amber[100],
                    child: Text(
                      fromName.isNotEmpty ? fromName[0].toUpperCase() : '?',
                      style: TextStyle(color: Colors.amber[800], fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(fromName, style: const TextStyle(fontWeight: FontWeight.bold)),
                        if (date.isNotEmpty)
                          Text(date, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                      ],
                    ),
                  ),
                  Row(
                    children: List.generate(
                      5,
                      (i) => Icon(
                        i < rating ? Icons.star : Icons.star_border,
                        color: Colors.amber,
                        size: 20,
                      ),
                    ),
                  ),
                  if (canNavigate)
                    Icon(Icons.chevron_right, size: 18, color: Colors.grey[400]),
                ],
              ),
              if (comment.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(comment, style: TextStyle(fontSize: 14, color: Colors.grey[700])),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
