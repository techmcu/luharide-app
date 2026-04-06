import 'package:flutter/material.dart';
import '../../../../services/review_service.dart';

/// Ratings you received — latest window from server; full history stays in DB.
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
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _loadReviews();
  }

  Future<void> _loadReviews() async {
    final uid = widget.userId?.trim();
    if (uid == null || uid.isEmpty) {
      setState(() {
        _isLoading = false;
        _loadError = 'Not signed in';
      });
      return;
    }
    setState(() {
      _isLoading = true;
      _loadError = null;
    });
    final result = await _reviewService.loadUserReviewBundleWithCache(uid);
    if (!mounted) return;
    setState(() {
      _isLoading = false;
      if (result['success'] == true) {
        _ratings.clear();
        if (result['reviews'] != null) {
          _ratings.addAll(
            List<Map<String, dynamic>>.from(result['reviews'] as List),
          );
        }
        _total = (result['total'] as num?)?.toInt() ?? 0;
        _hasMore = result['has_more'] == true;
        _windowMax = (result['reviews_window_max'] as num?)?.toInt() ?? 50;
        _fromCache = result['from_cache'] == true;
      } else {
        _loadError = 'Could not load ratings';
      }
    });
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
                      onRefresh: _loadReviews,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _ratings.length + 1,
                        itemBuilder: (context, i) {
                          if (i == 0) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (_hasMore)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 12),
                                    child: Text(
                                      'Showing latest $_windowMax of $_total reviews. '
                                      'Older ones stay on the server for trust & safety.',
                                      style: TextStyle(fontSize: 12.5, color: Colors.grey[700], height: 1.35),
                                    ),
                                  ),
                                if (_fromCache)
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
