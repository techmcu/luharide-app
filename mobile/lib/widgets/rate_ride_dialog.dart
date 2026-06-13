import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../core/feedback/app_feedback.dart';
import '../core/constants/input_limits.dart';
import '../core/localization/app_localizations.dart';
import '../services/review_service.dart';

const int _maxCommentWords = 20;

class RateRideDialog extends StatefulWidget {
  final String bookingId;
  final String title;
  final String? targetName;
  final String? targetPhoto;
  final List<int>? seatNumbers;
  final String? tripRoute;

  const RateRideDialog({
    super.key,
    required this.bookingId,
    this.title = 'Rate this ride',
    this.targetName,
    this.targetPhoto,
    this.seatNumbers,
    this.tripRoute,
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
  bool _loading = true;
  bool _alreadyRated = false;
  String _targetName = '';
  String? _targetPhoto;
  List<int> _seatNumbers = [];
  String _tripRoute = '';

  @override
  void initState() {
    super.initState();
    _commentController.addListener(_updateWordCount);
    _targetName = widget.targetName ?? '';
    _targetPhoto = widget.targetPhoto;
    _seatNumbers = widget.seatNumbers ?? [];
    _tripRoute = widget.tripRoute ?? '';
    _loadContext();
  }

  Future<void> _loadContext() async {
    final ctx = await _reviewService.getRatingContext(widget.bookingId);
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (ctx['success'] == true) {
        _targetName = ctx['target_name'] ?? _targetName;
        _targetPhoto = ctx['target_photo'] ?? _targetPhoto;
        final seats = ctx['seat_numbers'];
        if (seats is List && seats.isNotEmpty) {
          _seatNumbers = seats.map<int>((e) => (e as num).toInt()).toList();
        }
        _tripRoute = ctx['trip_route'] ?? _tripRoute;
        _alreadyRated = ctx['already_rated'] == true;
      }
    });
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

  Widget _buildTargetInfo() {
    if (_targetName.isEmpty && _seatNumbers.isEmpty) return const SizedBox.shrink();

    ImageProvider? photoProvider;
    if (_targetPhoto != null && _targetPhoto!.isNotEmpty) {
      if (_targetPhoto!.startsWith('data:image')) {
        try {
          final b64 = _targetPhoto!.substring(_targetPhoto!.indexOf(',') + 1);
          final Uint8List bytes = base64Decode(b64);
          photoProvider = MemoryImage(bytes);
        } catch (_) {}
      } else if (_targetPhoto!.startsWith('http')) {
        photoProvider = NetworkImage(_targetPhoto!);
      }
    }

    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade100),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: Colors.blue.shade100,
            backgroundImage: photoProvider,
            child: photoProvider == null
                ? Text(
                    _targetName.isNotEmpty ? _targetName[0].toUpperCase() : '?',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.blue.shade700),
                  )
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _targetName,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                if (_seatNumbers.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      'Seat ${_seatNumbers.join(', ')}',
                      style: TextStyle(fontSize: 13, color: Colors.grey[700], fontWeight: FontWeight.w500),
                    ),
                  ),
                if (_tripRoute.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      _tripRoute,
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);

    if (_loading) {
      return AlertDialog(
        title: Text(widget.title),
        content: const SizedBox(
          height: 80,
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    if (_alreadyRated) {
      return AlertDialog(
        title: Text(widget.title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildTargetInfo(),
            Icon(Icons.check_circle, color: Colors.green.shade400, size: 48),
            const SizedBox(height: 12),
            Text(
              loc.t('rating.already_rated'),
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(loc.t('app.ok')),
          ),
        ],
      );
    }

    return AlertDialog(
      title: Text(widget.title),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTargetInfo(),
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
