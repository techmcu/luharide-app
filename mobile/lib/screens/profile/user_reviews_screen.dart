import 'package:flutter/material.dart';
import '../../services/review_service.dart';

/// Shows rating summary + paginated reviews for a user (e.g. driver on trip details).
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
  bool _loadingMore = false;
  int _page = 1;
  bool _hasMore = true;
  static const int _pageSize = 20;

  @override
  void initState() {
    super.initState();
    _loadSummary();
    _loadPage();
  }

  Future<void> _loadSummary() async {
    final result = await _reviewService.getUserRatingSummary(widget.userId);
    if (mounted) {
      setState(() {
        _summaryLoaded = true;
        _total = (result['total_ratings'] as num?)?.toInt() ?? 0;
        _avgRating = (result['average_rating'] as num?)?.toDouble() ?? 0.0;
      });
    }
  }

  Future<void> _loadPage() async {
    setState(() => _isLoading = true);
    final result = await _reviewService.getReviewsForUser(widget.userId, page: 1, limit: _pageSize);
    if (mounted) {
      setState(() {
        _isLoading = false;
        _reviews.clear();
        if (result['success'] == true && result['reviews'] != null) {
          _reviews.addAll(List<Map<String, dynamic>>.from(result['reviews'] as List));
        }
        _hasMore = result['has_more'] == true;
        _page = 1;
      });
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore) return;
    setState(() => _loadingMore = true);
    final nextPage = _page + 1;
    final result = await _reviewService.getReviewsForUser(widget.userId, page: nextPage, limit: _pageSize);
    if (mounted) {
      setState(() {
        _loadingMore = false;
        if (result['success'] == true && result['reviews'] != null) {
          _reviews.addAll(List<Map<String, dynamic>>.from(result['reviews'] as List));
        }
        _hasMore = result['has_more'] == true;
        _page = nextPage;
      });
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
                  onRefresh: () async {
                    await _loadSummary();
                    await _loadPage();
                  },
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      if (_summaryLoaded) _buildSummaryChip(),
                      const SizedBox(height: 16),
                      ..._reviews.map((r) => _buildRatingCard(r)),
                      if (_hasMore)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          child: Center(
                            child: _loadingMore
                                ? const SizedBox(height: 32, width: 32, child: CircularProgressIndicator(strokeWidth: 2))
                                : TextButton.icon(
                                    onPressed: _loadMore,
                                    icon: const Icon(Icons.expand_more),
                                    label: const Text('More'),
                                  ),
                          ),
                        ),
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
          Text(
            _total == 0 ? 'No ratings yet' : '$avgStr ★ ($_total reviews)',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.amber[900]),
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
    final dateRaw = r['created_at'];
    final date = dateRaw != null ? (dateRaw is String ? dateRaw : dateRaw.toString()) : '';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                    fromName[0].toUpperCase(),
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
                  children: List.generate(5, (i) => Icon(
                    i < rating ? Icons.star : Icons.star_border,
                    color: Colors.amber,
                    size: 20,
                  )),
                ),
              ],
            ),
            if (comment.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(comment, style: TextStyle(fontSize: 14, color: Colors.grey[700])),
            ],
          ],
        ),
      ),
    );
  }
}
