import 'package:flutter/material.dart';
import '../../services/review_service.dart';

/// Ratings - User can see all ratings they received (from passengers/drivers)
class RatingsScreen extends StatefulWidget {
  final String? userRole;

  const RatingsScreen({super.key, this.userRole});

  @override
  State<RatingsScreen> createState() => _RatingsScreenState();
}

class _RatingsScreenState extends State<RatingsScreen> {
  final ReviewService _reviewService = ReviewService();
  final List<Map<String, dynamic>> _ratings = [];
  bool _isLoading = true;
  bool _loadingMore = false;
  int _page = 1;
  bool _hasMore = true;
  static const int _pageSize = 20;

  @override
  void initState() {
    super.initState();
    _loadReviews();
  }

  Future<void> _loadReviews() async {
    setState(() { _isLoading = true; _page = 1; _hasMore = true; });
    final result = await _reviewService.getMyReviews(page: 1, limit: _pageSize);
    if (mounted) {
      setState(() {
        _isLoading = false;
        _ratings.clear();
        if (result['success'] == true && result['reviews'] != null) {
          _ratings.addAll(List<Map<String, dynamic>>.from(result['reviews'] as List));
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
    final result = await _reviewService.getMyReviews(page: nextPage, limit: _pageSize);
    if (mounted) {
      setState(() {
        _loadingMore = false;
        if (result['success'] == true && result['reviews'] != null) {
          _ratings.addAll(List<Map<String, dynamic>>.from(result['reviews'] as List));
        }
        _hasMore = result['has_more'] == true;
        _page = nextPage;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDriver = widget.userRole == 'driver';

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Ratings'),
        backgroundColor: isDriver ? Colors.green : Colors.blue,
        foregroundColor: Colors.white,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(36),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Ratings you received from drivers & passengers',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.white.withValues(alpha: 0.9),
                ),
              ),
            ),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _ratings.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  onRefresh: _loadReviews,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _ratings.length + (_hasMore ? 1 : 0),
                    itemBuilder: (context, i) {
                      if (i == _ratings.length) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          child: Center(
                            child: _loadingMore
                                ? const SizedBox(height: 32, width: 32, child: CircularProgressIndicator(strokeWidth: 2))
                                : TextButton.icon(
                                    onPressed: _hasMore ? _loadMore : null,
                                    icon: const Icon(Icons.expand_more),
                                    label: const Text('More'),
                                  ),
                          ),
                        );
                      }
                      return _buildRatingCard(_ratings[i]);
                    },
                  ),
                ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.star_outline, size: 80, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              'No ratings yet',
              style: TextStyle(fontSize: 18, color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                'Here you’ll see ratings others gave you after a ride.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              widget.userRole == 'driver'
                  ? 'Passengers will rate you after completing rides.'
                  : 'Complete rides to receive ratings from drivers.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.grey[500]),
            ),
          ],
        ),
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
