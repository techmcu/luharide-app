import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:pdfx/pdfx.dart';

import '../../../../core/utils/auth_headers_sync.dart';

/// In-app KYC preview (mobile + web). No browser tab.
/// PDF: one GET with auth headers, then [pdfx] (pdf.js on web).
/// Images: [CachedNetworkImage] with small mem cache.
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
    final img = _looksRasterImage(url);
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(label, style: const TextStyle(fontSize: 15)),
      ),
      body: Center(
        child: pdf
            ? _PdfInAppPreview(url: url)
            : img
                ? _ImageInAppPreview(url: url)
                : _ImageInAppPreview(url: url),
      ),
    );
  }
}

class _ImageInAppPreview extends StatelessWidget {
  const _ImageInAppPreview({required this.url});
  final String url;

  @override
  Widget build(BuildContext context) {
    return InteractiveViewer(
      minScale: 0.8,
      maxScale: 3,
      child: CachedNetworkImage(
        imageUrl: url,
        httpHeaders: AuthHeadersSync.headers,
        fit: BoxFit.contain,
        memCacheWidth: 500,
        memCacheHeight: 500,
        placeholder: (_, __) =>
            const CircularProgressIndicator(color: Colors.white54),
        errorWidget: (_, __, ___) => Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.broken_image_outlined, size: 64, color: Colors.grey[600]),
            const SizedBox(height: 12),
            Text(
              'Could not load document',
              style: TextStyle(color: Colors.grey[400]),
            ),
          ],
        ),
      ),
    );
  }
}

class _PdfInAppPreview extends StatefulWidget {
  const _PdfInAppPreview({required this.url});
  final String url;

  @override
  State<_PdfInAppPreview> createState() => _PdfInAppPreviewState();
}

class _PdfInAppPreviewState extends State<_PdfInAppPreview> {
  PdfController? _controller;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final dio = Dio(
        BaseOptions(
          responseType: ResponseType.bytes,
          followRedirects: true,
          receiveTimeout: const Duration(seconds: 45),
          sendTimeout: const Duration(seconds: 30),
          headers: AuthHeadersSync.headers,
        ),
      );
      final res = await dio.get<List<int>>(widget.url);
      final raw = res.data;
      final bytes = raw is Uint8List ? raw : Uint8List.fromList(raw ?? const []);
      if (!mounted) return;
      if (bytes.isEmpty) {
        setState(() {
          _error = 'Empty document';
          _loading = false;
        });
        return;
      }
      final ctrl = PdfController(
        document: PdfDocument.openData(bytes),
      );
      if (!mounted) return;
      setState(() {
        _controller = ctrl;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load PDF';
        _loading = false;
      });
      if (kDebugMode) {
        debugPrint('[SimpleKycPreviewScreen] pdf load failed: $e');
      }
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const CircularProgressIndicator(color: Colors.white54);
    }
    if (_error != null || _controller == null) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.picture_as_pdf_outlined, size: 80, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              _error ?? 'Preview not available',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[400], fontSize: 14),
            ),
          ],
        ),
      );
    }
    return PdfView(
      controller: _controller!,
      scrollDirection: Axis.vertical,
      physics: const BouncingScrollPhysics(),
      backgroundDecoration: const BoxDecoration(color: Colors.black),
      renderer: (page) => page.render(
        width: page.width * 1.25,
        height: page.height * 1.25,
        format: PdfPageImageFormat.jpeg,
        backgroundColor: '#FFFFFF',
      ),
    );
  }
}
