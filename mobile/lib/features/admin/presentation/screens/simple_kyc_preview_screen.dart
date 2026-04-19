import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../../core/utils/auth_headers_sync.dart';
import 'simple_kyc_preview_mobile.dart'
    if (dart.library.html) 'simple_kyc_preview_web.dart';

/// In-app KYC preview (mobile + web). No browser tab.
/// - Mobile: Dio bytes + pdfx
/// - Web: HTML iframe (avoids CORS on XHR with auth headers)
class SimpleKycPreviewScreen extends StatelessWidget {
  const SimpleKycPreviewScreen({
    super.key,
    required this.url,
    required this.label,
  });

  final String url;
  final String label;

  bool _looksPdf(String u) {
    final path = Uri.tryParse(u)?.path.toLowerCase() ?? u.toLowerCase();
    return path.endsWith('.pdf');
  }

  bool _looksRasterImage(String u) {
    final path = Uri.tryParse(u)?.path.toLowerCase() ?? u.toLowerCase();
    return path.endsWith('.jpg') ||
        path.endsWith('.jpeg') ||
        path.endsWith('.png') ||
        path.endsWith('.webp') ||
        path.endsWith('.gif');
  }

  @override
  Widget build(BuildContext context) {
    final pdf = _looksPdf(url);
    
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(label, style: const TextStyle(fontSize: 15)),
      ),
      body: Center(
        child: kIsWeb
            ? (pdf
                ? buildWebPdfPreview(url)
                : buildWebImagePreview(url))
            : (pdf
                ? buildMobilePdfPreview(url)
                : buildMobileImagePreview(url)),
      ),
    );
  }
}

/// Mobile: Image with CachedNetworkImage
class ImageMobilePreview extends StatefulWidget {
  const ImageMobilePreview({super.key, required this.url});
  final String url;

  @override
  State<ImageMobilePreview> createState() => _ImageMobilePreviewState();
}

class _ImageMobilePreviewState extends State<ImageMobilePreview> {
  Map<String, String>? _headers;
  int _retryKey = 0;

  @override
  void initState() {
    super.initState();
    _refreshHeaders();
  }

  Future<void> _refreshHeaders() async {
    await AuthHeadersSync.refreshAuthHeadersCache();
    if (mounted) {
      setState(() {
        _headers = AuthHeadersSync.headers;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_headers == null) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(color: Colors.white),
          const SizedBox(height: 16),
          Text(
            'Loading...',
            style: TextStyle(color: Colors.grey[300]),
          ),
        ],
      );
    }

    return InteractiveViewer(
      minScale: 0.8,
      maxScale: 3,
      child: CachedNetworkImage(
        key: ValueKey('img_$_retryKey'),
        imageUrl: widget.url,
        httpHeaders: _headers,
        fit: BoxFit.contain,
        memCacheWidth: 500,
        memCacheHeight: 500,
        placeholder: (_, __) => Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: Colors.white, strokeWidth: 3),
            const SizedBox(height: 16),
            Text(
              'Loading image...',
              style: TextStyle(color: Colors.grey[300]),
            ),
          ],
        ),
        errorWidget: (_, __, ___) => Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 80, color: Colors.orange[300]),
              const SizedBox(height: 16),
              const Text(
                'Could not load image',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
              const SizedBox(height: 24),
              OutlinedButton.icon(
                onPressed: () {
                  setState(() {
                    _retryKey++;
                  });
                  _refreshHeaders();
                },
                icon: const Icon(Icons.refresh, color: Colors.white),
                label: const Text('Retry', style: TextStyle(color: Colors.white)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.white54),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
