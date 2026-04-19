import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// Lightweight in-app preview for watermarked KYC (no browser, compressed quality).
/// Shows low-res image/PDF thumbnail — keeps server + client load minimal.
class SimpleKycPreviewScreen extends StatelessWidget {
  const SimpleKycPreviewScreen({
    super.key,
    required this.url,
    required this.label,
  });

  final String url;
  final String label;

  bool get _isImage {
    final p = url.toLowerCase();
    return p.endsWith('.jpg') ||
        p.endsWith('.jpeg') ||
        p.endsWith('.png') ||
        p.endsWith('.webp');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(label, style: const TextStyle(fontSize: 15)),
      ),
      body: Center(
        child: _isImage
            ? InteractiveViewer(
                minScale: 0.8,
                maxScale: 3,
                child: CachedNetworkImage(
                  imageUrl: url,
                  fit: BoxFit.contain,
                  // Low-res cache (compress to ~400px max) — fast + light
                  memCacheWidth: 400,
                  memCacheHeight: 400,
                  placeholder: (_, __) => const CircularProgressIndicator(
                    color: Colors.white54,
                  ),
                  errorWidget: (_, __, ___) => Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.broken_image_outlined,
                          size: 64, color: Colors.grey[600]),
                      const SizedBox(height: 12),
                      Text(
                        'Could not load document',
                        style: TextStyle(color: Colors.grey[400]),
                      ),
                    ],
                  ),
                ),
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.picture_as_pdf_outlined,
                      size: 80, color: Colors.grey[300]),
                  const SizedBox(height: 16),
                  Text(
                    'PDF preview not available in-app',
                    style: TextStyle(color: Colors.grey[400], fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Document submitted (watermarked)',
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                ],
              ),
      ),
    );
  }
}
