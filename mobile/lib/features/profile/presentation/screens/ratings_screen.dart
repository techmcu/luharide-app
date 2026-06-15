import 'package:flutter/material.dart';
import '../../../../services/review_service.dart';
import '../../../../services/review_cache_store.dart';

class RatingsScreen extends StatefulWidget {
  final String? userRole;
  final String? userId;

  const RatingsScreen({super.key, this.userRole, this.userId});

  @override
  State<RatingsScreen> createState() => _RatingsScreenState();
}

class _RatingsScreenState extends State<RatingsScreen> with SingleTickerProviderStateMixin {
  final ReviewService _reviewService = ReviewService();
  final List<Map<String, dynamic>> _ratings = [];
  bool _isLoading = true;
  int _total = 0;
  int _windowMax = 50;
  bool _hasMore = false;
  bool _fromCache = false;
  bool _refreshing = false;
  String? _loadError;

  late TabController _tabController;

  static const _pageSize = 20;
  int _driverVisible = _pageSize;
  int _passengerVisible = _pageSize;

  List<Map<String, dynamic>> get _asDriverRatings =>
      _ratings.where((r) => r['from_role'] == 'passenger').toList();

  List<Map<String, dynamic>> get _asPassengerRatings =>
      _ratings.where((r) => r['from_role'] == 'driver').toList();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadCacheThenRefresh();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
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
        _loadError = result['error'] as String? ?? 'Could not load ratings';
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
      _driverVisible = _pageSize;
      _passengerVisible = _pageSize;
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
        bottom: _isLoading || _loadError != null || (_ratings.isEmpty && _total == 0)
            ? null
            : TabBar(
                controller: _tabController,
                indicatorColor: Colors.white,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white70,
                tabs: [
                  Tab(text: 'As Driver (${_asDriverRatings.length})'),
                  Tab(text: 'As Passenger (${_asPassengerRatings.length})'),
                ],
              ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _loadError != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.wifi_off_rounded, size: 48, color: Colors.grey[300]),
                      const SizedBox(height: 12),
                      Text(_loadError!, style: TextStyle(color: Colors.grey[700])),
                      const SizedBox(height: 12),
                      TextButton.icon(
                        onPressed: _loadCacheThenRefresh,
                        icon: const Icon(Icons.refresh, size: 18),
                        label: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : _ratings.isEmpty && _total == 0
                  ? _buildEmptyState()
                  : TabBarView(
                      controller: _tabController,
                      children: [
                        _buildRatingsList(
                          _asDriverRatings,
                          'No ratings as driver yet',
                          _driverVisible,
                          () => setState(() { _driverVisible += _pageSize; }),
                        ),
                        _buildRatingsList(
                          _asPassengerRatings,
                          'No ratings as passenger yet',
                          _passengerVisible,
                          () => setState(() { _passengerVisible += _pageSize; }),
                        ),
                      ],
                    ),
    );
  }

  Widget _buildRatingsList(
    List<Map<String, dynamic>> ratings,
    String emptyMsg,
    int visibleCount,
    VoidCallback onShowMore,
  ) {
    if (ratings.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.star_outline, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 12),
            Text(emptyMsg, style: TextStyle(fontSize: 16, color: Colors.grey[600])),
          ],
        ),
      );
    }

    final shown = visibleCount.clamp(0, ratings.length);
    final canShowMore = shown < ratings.length;

    return RefreshIndicator(
      onRefresh: _onRefresh,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: shown + 2, // header + visible items + footer
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
                        const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
                        const SizedBox(width: 8),
                        Text('Updating...', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                      ],
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    _hasMore
                        ? 'Showing $shown of latest $_windowMax (${_total} total)'
                        : 'Showing $shown of ${ratings.length} reviews',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ),
                if (_fromCache && !_refreshing)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text('Offline or cached — pull to refresh.',
                        style: TextStyle(fontSize: 12, color: Colors.orange[800])),
                  ),
              ],
            );
          }
          if (i <= shown) {
            return _buildRatingCard(ratings[i - 1]);
          }
          // Footer
          if (canShowMore) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Center(
                child: OutlinedButton.icon(
                  onPressed: onShowMore,
                  icon: const Icon(Icons.expand_more, size: 18),
                  label: Text('Show more (${ratings.length - shown} remaining)'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.blue[700],
                    side: BorderSide(color: Colors.blue[200]!),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  ),
                ),
              ),
            );
          }
          return const SizedBox(height: 16);
        },
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
            Text('No ratings yet', style: TextStyle(fontSize: 18, color: Colors.grey[600])),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                'Here you\'ll see ratings others gave you after a ride.',
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
    final isFromDriver = fromRole == 'driver';
    final roleLabel = isFromDriver ? 'Driver' : 'Passenger';
    final roleColor = isFromDriver ? Colors.green : Colors.blue;

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
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Text.rich(
                    TextSpan(children: [
                      TextSpan(text: fromName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                      TextSpan(text: ' ($roleLabel)', style: TextStyle(fontSize: 12, color: roleColor, fontWeight: FontWeight.w500)),
                      TextSpan(text: ' rated you', style: TextStyle(fontSize: 13, color: Colors.grey[600])),
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
                ...List.generate(5, (i) => Icon(
                  i < rating ? Icons.star_rounded : Icons.star_outline_rounded, color: Colors.amber, size: 18,
                )),
                const SizedBox(width: 6),
                Text('$rating/5', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.grey[600])),
              ],
            ),
            if (comment.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text('"$comment"', style: TextStyle(fontSize: 13, color: Colors.grey[700], fontStyle: FontStyle.italic)),
            ],
            if (tripContext.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(tripContext, style: TextStyle(fontSize: 11, color: Colors.grey[400]), overflow: TextOverflow.ellipsis),
            ],
          ],
        ),
      ),
    );
  }
}
