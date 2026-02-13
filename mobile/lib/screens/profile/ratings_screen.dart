import 'package:flutter/material.dart';

/// Ratings - User can see all ratings they received (from passengers/drivers)
class RatingsScreen extends StatefulWidget {
  final String? userRole;

  const RatingsScreen({super.key, this.userRole});

  @override
  State<RatingsScreen> createState() => _RatingsScreenState();
}

class _RatingsScreenState extends State<RatingsScreen> {
  // TODO: Fetch from backend GET /api/reviews/my-reviews when implemented
  final List<Map<String, dynamic>> _ratings = [];
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    final isDriver = widget.userRole == 'driver';

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Ratings'),
        backgroundColor: isDriver ? Colors.green : Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _ratings.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _ratings.length,
                  itemBuilder: (context, i) => _buildRatingCard(_ratings[i]),
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
          Text(
            'No ratings yet',
            style: TextStyle(fontSize: 18, color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              widget.userRole == 'driver'
                  ? 'Passengers will rate you after completing rides'
                  : 'Complete rides to receive ratings',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey[500]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRatingCard(Map<String, dynamic> r) {
    final rating = r['rating'] as int? ?? 0;
    final comment = r['comment'] as String? ?? '';
    final fromName = r['from_name'] as String? ?? 'User';
    final date = r['created_at'] as String? ?? '';

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
