import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../core/kyc/kyc_upload_auth_headers.dart';

/// Small square thumbnail for KYC URLs — sends JWT so protected `/uploads/` works (web + mobile).
class KycCachedThumb extends StatefulWidget {
  const KycCachedThumb({
    super.key,
    required this.imageUrl,
    this.size = 56,
  });

  final String imageUrl;
  final double size;

  @override
  State<KycCachedThumb> createState() => _KycCachedThumbState();
}

class _KycCachedThumbState extends State<KycCachedThumb> {
  late final Future<Map<String, String>?> _headersFuture = kycUploadAuthHeaders();

  @override
  Widget build(BuildContext context) {
    final s = widget.size;
    return FutureBuilder<Map<String, String>?>(
      future: _headersFuture,
      builder: (context, snap) {
        return CachedNetworkImage(
          imageUrl: widget.imageUrl,
          httpHeaders: snap.data,
          width: s,
          height: s,
          fit: BoxFit.cover,
          memCacheWidth: (s * 2).round(),
          memCacheHeight: (s * 2).round(),
          placeholder: (_, __) => SizedBox(
            width: s,
            height: s,
            child: const Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          ),
          errorWidget: (_, __, ___) => const Icon(Icons.broken_image_outlined),
        );
      },
    );
  }
}
