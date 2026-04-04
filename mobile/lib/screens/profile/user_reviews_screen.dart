import 'package:flutter/material.dart';
import '../../services/review_service.dart';

/// Rating summary + latest reviews for another user (e.g. driver on trip details).
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

  @override
  void initState() {
    super.initState();
    _loadBundle();
  }

  Future<void> _loadBundle() async {
    setState(() => _isLoading = true);
    final result = await _reviewService.loadUserReviewBundleWithCache(widget.userId);
    if (!mounted) return;
    setState(() {
      _isLoading = false;
      _summaryLoaded = true;
      _total = (result['total'] as num?)?.toInt() ?? 0;
      _avgRating = (result['average_rating'] as num?)?.toDouble() ?? 0.0;
      _hasMore = result['has_more'] == true;
      _windowMax = (result['reviews_window_max'] as num?)?.toInt() ?? 50;
      _fromCache = result['from_cache'] == true;
      _reviews.clear();
      if (result['success'] == true && result['reviews'] != null) {
        _reviews.addAll(List<Map<String, dynamic>>.from(result['reviews'] as List));
      }
    });
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
                  onRefresh: _loadBundle,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      if (_summaryLoaded) _buildSummaryChip(),
                      if (_hasMore)
                        Padding(
                          padding: const EdgeInsets.only(top: 8, bottom: 8),
                          child: Text(
                            'Showing latest $_windowMax of $_total reviews.',
                            style: TextStyle(fontSize: 12.5, color: Colors.grey[700], height: 1.35),
                          ),
                        ),
                      if (_fromCache)
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
