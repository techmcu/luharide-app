import 'package:flutter/material.dart';
import '../../../../services/review_service.dart';
import '../../../../services/review_cache_store.dart';
import 'user_reviews_screen.dart';

/// Ratings you received — latest window from server; full history stays in DB.
/// Uses stale-while-revalidate: shows cached data instantly, refreshes in background.
class RatingsScreen extends StatefulWidget {
  final String? userRole;
  final String? userId;

  const RatingsScreen({super.key, this.userRole, this.userId});

  @override
  State<RatingsScreen> createState() => _RatingsScreenState();
}

class _RatingsScreenState extends State<RatingsScreen> {
  final ReviewService _reviewService = ReviewService();
  final List<Map<String, dynamic>> _ratings = [];
  bool _isLoading = true;
  int _total = 0;
  int _windowMax = 50;
  bool _hasMore = false;
  bool _fromCache = false;
  bool _refreshing = false;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _loadCacheThenRefresh();
  }

  Future<void> _loadCacheThenRefresh() async {
    final uid = widget.userId?.trim();
    if (uid == null || uid.isEmpty) {
      setState(() {
        _isLoading = false;
        _loadError = 'Not signed in';
      });
      return;
    }

    final cached = await ReviewCacheStore.readBundle(uid);
    if (cached != null && mounted) {
      _applyData(cached, isCache: true);
    }

    if (!mounted) return;
    setState(() {
      _refreshing = true;
      _loadError = null;
    });
    final result = await _reviewService.fetchUserReviewBundle(uid);
    if (!mounted) return;
    if (result['success'] == true) {
      _applyData(result, isCache: false);
    } else if (_ratings.isEmpty) {
      setState(() {
        _isLoading = false;
        _refreshing = false;
        _loadError = 'Could not load ratings';
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
      _fromCache = isCache;
      _loadError = null;
      _ratings.clear();
      _ratings.addAll(List<Map<String, dynamic>>.from(list));
      _total = (rawTotal as num?)?.toInt() ?? 0;
      _hasMore = data['has_more'] == true;
      _windowMax = (data['reviews_window_max'] as num?)?.toInt() ?? 50;
    });
  }

  Future<void> _onRefresh() async {
    final uid = widget.userId?.trim();
    if (uid == null || uid.isEmpty) return;
    final result = await _reviewService.fetchUserReviewBundle(uid);
    if (!mounted) return;
    if (result['success'] == true) {
      _applyData(result, isCache: false);
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
          : _loadError != null
              ? Center(child: Text(_loadError!, style: TextStyle(color: Colors.grey[700])))
              : _ratings.isEmpty && _total == 0
                  ? _buildEmptyState()
                  : RefreshIndicator(
                      onRefresh: _onRefresh,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _ratings.length + 1,
                        itemBuilder: (context, i) {
                          if (i == 0) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (_refreshing)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 8),
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
                                    padding: const EdgeInsets.only(bottom: 12),
                                    child: Text(
                                      'Showing latest $_windowMax of $_total reviews. '
                                      'Older ones stay on the server for trust & safety.',
                                      style: TextStyle(fontSize: 12.5, color: Colors.grey[700], height: 1.35),
                                    ),
                                  ),
                                if (_fromCache && !_refreshing)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 8),
                                    child: Text(
                                      'Offline or cached — pull to refresh.',
                                      style: TextStyle(fontSize: 12, color: Colors.orange[800]),
                                    ),
                                  ),
                              ],
                            );
                          }
                          return _buildRatingCard(_ratings[i - 1]);
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
    final fromUserId = r['from_user_id']?.toString();
    final dateRaw = r['created_at'];
    final date = dateRaw != null ? (dateRaw is String ? dateRaw : dateRaw.toString()) : '';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: fromUserId != null && fromUserId.isNotEmpty
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
                  if (fromUserId != null)
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
