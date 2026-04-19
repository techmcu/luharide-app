import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:pdfx/pdfx.dart';

import '../../../../core/utils/auth_headers_sync.dart';

/// Authenticated image preview (mobile + web).
class KycImagePreview extends StatefulWidget {
  const KycImagePreview({super.key, required this.url});
  final String url;

  @override
  State<KycImagePreview> createState() => _KycImagePreviewState();
}

class _KycImagePreviewState extends State<KycImagePreview> {
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

/// PDF via Dio bytes + pdfx (mobile + web). Avoids iframe/new-tab issues on web.
class KycPdfPreview extends StatefulWidget {
  const KycPdfPreview({super.key, required this.url});
  final String url;

  @override
  State<KycPdfPreview> createState() => _KycPdfPreviewState();
}

class _KycPdfPreviewState extends State<KycPdfPreview> {
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
          debugPrint('[KycPdfPreview] No auth headers available');
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
        debugPrint('[KycPdfPreview] Loading PDF from: ${widget.url}');
      }

      final res = await dio.get<List<int>>(widget.url);
      final raw = res.data;
      final bytes = raw is Uint8List ? raw : Uint8List.fromList(raw ?? const []);

      if (kDebugMode) {
        debugPrint('[KycPdfPreview] PDF bytes loaded: ${bytes.length}');
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
        debugPrint('[KycPdfPreview] PDF loaded successfully');
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
        } else if (e.type == DioExceptionType.connectionError) {
          errorMsg =
              'Network error (web: check CORS on server for /uploads + Authorization).';
        } else {
          errorMsg = 'Network error: ${e.response?.statusCode ?? "unknown"}';
        }
      }
      setState(() {
        _error = errorMsg;
        _loading = false;
      });
      if (kDebugMode) {
        debugPrint('[KycPdfPreview] pdf load failed: $e');
        debugPrint('[KycPdfPreview] stack: $stack');
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
