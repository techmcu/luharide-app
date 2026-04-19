import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:pdfx/pdfx.dart';

import 'simple_kyc_preview_screen.dart';
import '../../../../core/utils/auth_headers_sync.dart';

Widget buildMobileImagePreview(String url) => ImageMobilePreview(url: url);
Widget buildMobilePdfPreview(String url) => PdfMobilePreview(url: url);

/// Mobile: PDF with pdfx (authenticated Dio bytes)
class PdfMobilePreview extends StatefulWidget {
  const PdfMobilePreview({super.key, required this.url});
  final String url;

  @override
  State<PdfMobilePreview> createState() => _PdfMobilePreviewState();
}

class _PdfMobilePreviewState extends State<PdfMobilePreview> {
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
