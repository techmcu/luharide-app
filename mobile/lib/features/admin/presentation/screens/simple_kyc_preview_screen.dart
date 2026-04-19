import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:pdfx/pdfx.dart';
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;

import '../../../../core/utils/auth_headers_sync.dart';

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
    final img = _looksRasterImage(url);
    
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
                ? _PdfWebIframePreview(url: url)
                : _ImageWebPreview(url: url))
            : (pdf
                ? _PdfMobilePreview(url: url)
                : _ImageMobilePreview(url: url)),
      ),
    );
  }
}

/// Web: Use HTML img tag (no CORS issues)
class _ImageWebPreview extends StatefulWidget {
  const _ImageWebPreview({required this.url});
  final String url;

  @override
  State<_ImageWebPreview> createState() => _ImageWebPreviewState();
}

class _ImageWebPreviewState extends State<_ImageWebPreview> {
  final String _viewId = 'kyc-img-${DateTime.now().millisecondsSinceEpoch}';

  @override
  void initState() {
    super.initState();
    // Register platform view
    ui_web.platformViewRegistry.registerViewFactory(_viewId, (int viewId) {
      final img = html.ImageElement()
        ..src = widget.url
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.objectFit = 'contain';
      return img;
    });
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: double.infinity,
      child: HtmlElementView(viewType: _viewId),
    );
  }
}

/// Web: Use HTML iframe for PDF (no CORS/XHR issues)
class _PdfWebIframePreview extends StatefulWidget {
  const _PdfWebIframePreview({required this.url});
  final String url;

  @override
  State<_PdfWebIframePreview> createState() => _PdfWebIframePreviewState();
}

class _PdfWebIframePreviewState extends State<_PdfWebIframePreview> {
  final String _viewId = 'kyc-pdf-${DateTime.now().millisecondsSinceEpoch}';

  @override
  void initState() {
    super.initState();
    // Register platform view
    ui_web.platformViewRegistry.registerViewFactory(_viewId, (int viewId) {
      final iframe = html.IFrameElement()
        ..src = widget.url
        ..style.border = 'none'
        ..style.width = '100%'
        ..style.height = '100%';
      return iframe;
    });
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: double.infinity,
      child: HtmlElementView(viewType: _viewId),
    );
  }
}

/// Mobile: Image with CachedNetworkImage
class _ImageMobilePreview extends StatefulWidget {
  const _ImageMobilePreview({required this.url});
  final String url;

  @override
  State<_ImageMobilePreview> createState() => _ImageMobilePreviewState();
}

class _ImageMobilePreviewState extends State<_ImageMobilePreview> {
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

/// Mobile: PDF with pdfx (authenticated Dio bytes)
class _PdfMobilePreview extends StatefulWidget {
  const _PdfMobilePreview({required this.url});
  final String url;

  @override
  State<_PdfMobilePreview> createState() => _PdfMobilePreviewState();
}

class _PdfMobilePreviewState extends State<_PdfMobilePreview> {
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
      await AuthHeadersSync.refreshAuthHeadersCache();
      final authHeaders = AuthHeadersSync.headers;
      if (authHeaders == null || authHeaders.isEmpty) {
        if (!mounted) return;
        setState(() {
          _error = 'Auth token missing. Try logging in again.';
          _loading = false;
        });
        if (kDebugMode) {
          debugPrint('[SimpleKycPreviewScreen] No auth headers available');
        }
        return;
      }

      final dio = Dio(
        BaseOptions(
          responseType: ResponseType.bytes,
          followRedirects: true,
          receiveTimeout: const Duration(seconds: 45),
          sendTimeout: const Duration(seconds: 30),
          headers: authHeaders,
        ),
      );

      if (kDebugMode) {
        debugPrint('[SimpleKycPreviewScreen] Loading PDF from: ${widget.url}');
      }

      final res = await dio.get<List<int>>(widget.url);
      final raw = res.data;
      final bytes = raw is Uint8List ? raw : Uint8List.fromList(raw ?? const []);

      if (kDebugMode) {
        debugPrint('[SimpleKycPreviewScreen] PDF bytes loaded: ${bytes.length}');
      }

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

      if (kDebugMode) {
        debugPrint('[SimpleKycPreviewScreen] PDF loaded successfully');
      }
    } catch (e, stack) {
      if (!mounted) return;
      String errorMsg = 'Could not load PDF';
      if (e is DioException) {
        if (e.response?.statusCode == 401 || e.response?.statusCode == 403) {
          errorMsg = 'Access denied. Please log in again.';
        } else if (e.response?.statusCode == 404) {
          errorMsg = 'Document not found';
        } else if (e.type == DioExceptionType.connectionTimeout ||
            e.type == DioExceptionType.receiveTimeout) {
          errorMsg = 'Connection timeout. Check your internet.';
        } else {
          errorMsg = 'Network error: ${e.response?.statusCode ?? "unknown"}';
        }
      }
      setState(() {
        _error = errorMsg;
        _loading = false;
      });
      if (kDebugMode) {
        debugPrint('[SimpleKycPreviewScreen] pdf load failed: $e');
        debugPrint('[SimpleKycPreviewScreen] stack: $stack');
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
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(color: Colors.white, strokeWidth: 3),
          const SizedBox(height: 24),
          Text(
            'Loading document...',
            style: TextStyle(color: Colors.grey[300], fontSize: 16),
          ),
        ],
      );
    }
    if (_error != null || _controller == null) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 80, color: Colors.orange[300]),
            const SizedBox(height: 16),
            Text(
              _error ?? 'Preview not available',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 16),
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: () {
                setState(() {
                  _loading = true;
                  _error = null;
                  _controller = null;
                });
                _load();
              },
              icon: const Icon(Icons.refresh, color: Colors.white),
              label: const Text('Retry', style: TextStyle(color: Colors.white)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.white54),
              ),
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
