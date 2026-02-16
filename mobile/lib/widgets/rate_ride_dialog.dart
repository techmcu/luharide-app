import 'package:flutter/material.dart';
import '../services/review_service.dart';

const int _maxCommentWords = 20;

class RateRideDialog extends StatefulWidget {
  final String bookingId;
  final String title; // e.g. "Rate your driver" or "Rate your passenger"

  const RateRideDialog({
    super.key,
    required this.bookingId,
    this.title = 'Rate this ride',
  });

  @override
  State<RateRideDialog> createState() => _RateRideDialogState();
}

class _RateRideDialogState extends State<RateRideDialog> {
  final ReviewService _reviewService = ReviewService();
  int _rating = 0;
  final TextEditingController _commentController = TextEditingController();
  int _wordCount = 0;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _commentController.addListener(_updateWordCount);
  }

  void _updateWordCount() {
    final words = _commentController.text.trim().split(RegExp(r'\s+')).where((s) => s.isNotEmpty).length;
    if (words != _wordCount) setState(() => _wordCount = words);
  }

  @override
  void dispose() {
    _commentController.removeListener(_updateWordCount);
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_rating < 1 || _rating > 5) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a rating (1-5 stars)'), backgroundColor: Colors.orange),
      );
      return;
    }
    if (_wordCount > _maxCommentWords) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Comment cannot exceed $_maxCommentWords words'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _submitting = true);

    final comment = _commentController.text.trim();
    final result = await _reviewService.submitRating(
      bookingId: widget.bookingId,
      rating: _rating,
      comment: comment,
    );

    if (!mounted) return;
    setState(() => _submitting = false);

    if (result['success'] == true) {
      Navigator.of(context).pop(true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result['message'] ?? 'Thank you!'), backgroundColor: Colors.green),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result['message'] ?? 'Failed'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Your rating', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (i) {
                final star = i + 1;
                return IconButton(
                  icon: Icon(
                    _rating >= star ? Icons.star : Icons.star_border,
                    color: Colors.amber,
                    size: 36,
                  ),
                  onPressed: () => setState(() => _rating = star),
                );
              }),
            ),
            const SizedBox(height: 16),
            const Text('Comment (optional, max 20 words)', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            TextField(
              controller: _commentController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'How was your experience?',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                counterText: '$_wordCount / $_maxCommentWords words',
              ),
              onChanged: (_) => _updateWordCount(),
            ),
            const SizedBox(height: 4),
            Text(
              '$_wordCount / $_maxCommentWords words',
              style: TextStyle(fontSize: 12, color: _wordCount > _maxCommentWords ? Colors.red : Colors.grey[600]),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _submitting ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _submitting ? null : _submit,
          child: _submitting
              ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Submit'),
        ),
      ],
    );
  }
}
