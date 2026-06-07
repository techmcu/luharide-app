import 'package:flutter/material.dart';
import '../core/feedback/app_feedback.dart';
import '../core/constants/input_limits.dart';
import '../core/localization/app_localizations.dart';
import '../services/review_service.dart';

const int _maxCommentWords = 20;

class RateRideDialog extends StatefulWidget {
  final String bookingId;
  final String title;

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
  final TextEditingController _commentController = TextEditingController();
  int _rating = 0;
  bool _submitting = false;
  int _wordCount = 0;

  @override
  void initState() {
    super.initState();
    _commentController.addListener(_updateWordCount);
  }

  void _updateWordCount() {
    final text = _commentController.text.trim();
    setState(() {
      _wordCount = text.isEmpty ? 0 : text.split(RegExp(r'\s+')).length;
    });
  }

  @override
  void dispose() {
    _commentController.removeListener(_updateWordCount);
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final loc = AppLocalizations.of(context);
    if (_rating < 1 || _rating > 5) {
      AppFeedback.show(
        context,
        loc.t('rating.select_stars'),
        kind: AppFeedbackKind.warning,
      );
      return;
    }
    if (_wordCount > _maxCommentWords) {
      AppFeedback.show(
        context,
        loc.t('rating.comment_limit'),
        kind: AppFeedbackKind.error,
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
      final messenger = ScaffoldMessenger.of(context);
      final msg = result['message'] ?? 'Thank you!';
      Navigator.of(context).pop(true);
      AppFeedback.showFromMessenger(
        messenger,
        msg,
        kind: AppFeedbackKind.success,
      );
    } else {
      AppFeedback.show(
        context,
        result['message'] ?? 'Failed',
        kind: AppFeedbackKind.error,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(widget.title),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              loc.t('rating.info'),
              style: TextStyle(fontSize: 12, color: Colors.grey[600], fontStyle: FontStyle.italic),
            ),
            const SizedBox(height: 12),
            Text(loc.t('rating.your_rating'), style: const TextStyle(fontWeight: FontWeight.w600)),
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
            Text(loc.t('rating.comment_label'), style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            TextField(
              controller: _commentController,
              maxLines: 3,
              maxLength: InputLimits.comment,
              decoration: InputDecoration(
                hintText: loc.t('rating.comment_hint'),
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
          child: Text(loc.t('app.cancel')),
        ),
        ElevatedButton(
          onPressed: _submitting ? null : _submit,
          child: _submitting
              ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))
              : Text(loc.t('rating.submit')),
        ),
      ],
    );
  }
}
