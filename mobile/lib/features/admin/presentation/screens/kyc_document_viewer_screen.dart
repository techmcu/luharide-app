import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:pdfx/pdfx.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../../../core/config/env_config.dart';
import '../../../../core/kyc/kyc_upload_auth_headers.dart';
import '../../../../core/localization/app_localizations.dart';

/// In-app preview for KYC files (`/uploads/...` or absolute). Mobile stays in-app only (no raw URLs in UI, no external browser). Web offers opening in a browser tab.
///
/// **PDF on Android/iOS:** WebView often never finishes loading a raw `.pdf` URL (spinner forever). PDFs use [pdfx] with a byte download instead.
class KycDocumentViewerScreen extends StatefulWidget {
  const KycDocumentViewerScreen({super.key, required this.storageUrl});

  /// Path from API e.g. `/uploads/driver-docs/x.jpg` or full `https://...` — not shown to the user.
  final String storageUrl;

  @override
  State<KycDocumentViewerScreen> createState() => _KycDocumentViewerScreenState();
}

class _KycDocumentViewerScreenState extends State<KycDocumentViewerScreen> {
  WebViewController? _controller;
  bool _loading = true;
  bool _webViewFailed = false;
  late final String _resolved;
  int _viewerRetryKey = 0;

  String _resolveUrl(String url) {
    final raw = url.trim();
    if (raw.isEmpty) return raw;
    if (raw.startsWith('http://') || raw.startsWith('https://')) return raw;
    if (raw.startsWith('/')) return '${EnvConfig.publicFileBaseUrl}$raw';
    return '${EnvConfig.publicFileBaseUrl}/$raw';
  }

  static bool _isRasterImageUrl(String url) {
    final path = Uri.tryParse(url)?.path.toLowerCase() ?? '';
    return path.endsWith('.jpg') ||
        path.endsWith('.jpeg') ||
        path.endsWith('.png') ||
        path.endsWith('.gif') ||
        path.endsWith('.webp') ||
        path.endsWith('.bmp');
  }

  static bool _isPdfUrl(String url) {
    final path = Uri.tryParse(url)?.path.toLowerCase() ?? url.toLowerCase();
    return path.endsWith('.pdf');
  }

  static bool get _useNativePdfRenderer {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }

  WebViewController _buildPdfController(Uri uri) {
    return WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) {
            if (mounted) setState(() => _loading = false);
          },
          onWebResourceError: (_) {
            if (mounted) {
              setState(() {
                _loading = false;
                _webViewFailed = true;
              });
            }
          },
        ),
      )
      ..loadRequest(uri);
  }

  void _retryWebDocument(Uri uri) {
    setState(() {
      _webViewFailed = false;
      _loading = true;
      _controller = _buildPdfController(uri);
    });
  }

  @override
  void initState() {
    super.initState();
    _resolved = _resolveUrl(widget.storageUrl);
    if (_isRasterImageUrl(_resolved)) {
      _loading = false;
      return;
    }
    if (_isPdfUrl(_resolved) && (_useNativePdfRenderer || kIsWeb)) {
      _loading = false;
      return;
    }
    if (kIsWeb) {
      _loading = false;
      return;
    }
    final uri = Uri.tryParse(_resolved);
    if (uri == null) {
      _webViewFailed = true;
      _loading = false;
      return;
    }
    _controller = _buildPdfController(uri);
  }

  Future<void> _openInBrowserTab() async {
    if (!kIsWeb) return;
    final uri = Uri.tryParse(_resolved);
    if (uri == null) return;
    await launchUrl(uri, webOnlyWindowName: '_blank');
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final uri = Uri.tryParse(_resolved);
    final isRaster = _isRasterImageUrl(_resolved);
    final isPdf = _isPdfUrl(_resolved);
    final showRaster = isRaster;
    final showPdfNative = isPdf && _useNativePdfRenderer && !kIsWeb;
    final showPdfWeb = kIsWeb && isPdf;

    return Scaffold(
      appBar: AppBar(
        title: Text(loc.t('admin.kyc.viewer_title')),
        actions: [
          if (kIsWeb)
            IconButton(
              tooltip: loc.t('admin.kyc.viewer_open_browser'),
              icon: const Icon(Icons.open_in_new),
              onPressed: _openInBrowserTab,
            ),
          if (!kIsWeb) ...[
            if (showRaster || showPdfNative)
              IconButton(
                tooltip: loc.t('app.refresh'),
                icon: const Icon(Icons.refresh),
                onPressed: () => setState(() => _viewerRetryKey++),
              )
            else if (uri != null && (_controller != null || _webViewFailed))
              IconButton(
                tooltip: loc.t('app.refresh'),
                icon: const Icon(Icons.refresh),
                onPressed: () => _retryWebDocument(uri),
              ),
          ],
          if (kIsWeb && (isRaster || showPdfWeb))
            IconButton(
              tooltip: loc.t('app.refresh'),
              icon: const Icon(Icons.refresh),
              onPressed: () => setState(() => _viewerRetryKey++),
            ),
        ],
      ),
      body: kIsWeb
          ? (isRaster
              ? _RasterKycPreview(
                  key: ValueKey<int>(_viewerRetryKey),
                  url: _resolved,
                  loc: loc,
                  onRetry: () => setState(() => _viewerRetryKey++),
                )
              : showPdfWeb
                  ? _PdfKycPreview(
                      key: ValueKey<int>(_viewerRetryKey),
                      url: _resolved,
                      loc: loc,
                      onRetry: () => setState(() => _viewerRetryKey++),
                    )
                  : Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(loc.t('admin.kyc.viewer_web_hint')),
                            const SizedBox(height: 16),
                            FilledButton.icon(
                              onPressed: _openInBrowserTab,
                              icon: const Icon(Icons.open_in_new),
                              label: Text(loc.t('admin.kyc.viewer_open_browser')),
                            ),
                          ],
                        ),
                      ),
                    ))
          : showRaster
              ? _RasterKycPreview(
                  key: ValueKey<int>(_viewerRetryKey),
                  url: _resolved,
                  loc: loc,
                  onRetry: () => setState(() => _viewerRetryKey++),
                )
              : showPdfNative
                  ? _PdfKycPreview(
                      key: ValueKey<int>(_viewerRetryKey),
                      url: _resolved,
                      loc: loc,
                      onRetry: () => setState(() => _viewerRetryKey++),
                    )
                  : Stack(
                      children: [
                        if (_controller != null && !_webViewFailed)
                          WebViewWidget(controller: _controller!),
                        if (_webViewFailed)
                          Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.broken_image_outlined, size: 48, color: Colors.grey[600]),
                                  const SizedBox(height: 12),
                                  Text(
                                    loc.t('admin.kyc.viewer_load_error'),
                                    textAlign: TextAlign.center,
                                    style: TextStyle(color: Colors.grey[800]),
                                  ),
                                  const SizedBox(height: 16),
                                  if (uri != null)
                                    FilledButton.icon(
                                      onPressed: () => _retryWebDocument(uri),
                                      icon: const Icon(Icons.refresh),
                                      label: Text(loc.t('app.retry')),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        if (_loading && !_webViewFailed && _controller != null)
                          const Center(child: CircularProgressIndicator()),
                      ],
                    ),
    );
  }
}

class _RasterKycPreview extends StatefulWidget {
  const _RasterKycPreview({
    super.key,
    required this.url,
    required this.loc,
    required this.onRetry,
  });

  final String url;
  final AppLocalizations loc;
  final VoidCallback onRetry;

  @override
  State<_RasterKycPreview> createState() => _RasterKycPreviewState();
}

class _RasterKycPreviewState extends State<_RasterKycPreview> {
  late final Future<Map<String, String>?> _authHeaders = kycUploadAuthHeaders();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return InteractiveViewer(
          minScale: 0.5,
          maxScale: 4,
          child: SizedBox(
            width: constraints.maxWidth,
            height: constraints.maxHeight,
            child: Center(
              child: FutureBuilder<Map<String, String>?>(
                future: _authHeaders,
                builder: (context, snap) {
                  return CachedNetworkImage(
                    imageUrl: widget.url,
                    httpHeaders: snap.data,
                    fit: BoxFit.contain,
                    placeholder: (_, __) => const Padding(
                      padding: EdgeInsets.all(48),
                      child: CircularProgressIndicator(),
                    ),
                    errorWidget: (_, __, ___) => Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.broken_image_outlined, size: 48, color: Colors.grey[600]),
                          const SizedBox(height: 12),
                          Text(
                            widget.loc.t('admin.kyc.viewer_image_error'),
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey[800]),
                          ),
                          const SizedBox(height: 16),
                          FilledButton.icon(
                            onPressed: widget.onRetry,
                            icon: const Icon(Icons.refresh),
                            label: Text(widget.loc.t('app.retry')),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}

class _PdfKycPreview extends StatefulWidget {
  const _PdfKycPreview({
    super.key,
    required this.url,
    required this.loc,
    required this.onRetry,
  });

  final String url;
  final AppLocalizations loc;
  final VoidCallback onRetry;

  @override
  State<_PdfKycPreview> createState() => _PdfKycPreviewState();
}

class _PdfKycPreviewState extends State<_PdfKycPreview> {
  PdfControllerPinch? _pdfController;
  bool _loadingBytes = true;
  bool _loadFailed = false;

  @override
  void initState() {
    super.initState();
    _loadPdf();
  }

  Future<void> _loadPdf() async {
    setState(() {
      _loadingBytes = true;
      _loadFailed = false;
    });
    try {
      final bytes = await _fetchPdfBytes();
      if (!mounted) return;
      _pdfController?.dispose();
      _pdfController = PdfControllerPinch(
        document: PdfDocument.openData(bytes),
      );
      setState(() => _loadingBytes = false);
    } catch (_) {
      if (mounted) {
        setState(() {
          _loadingBytes = false;
          _loadFailed = true;
        });
      }
    }
  }

  Future<Uint8List> _fetchPdfBytes() async {
    final headers = <String, dynamic>{
      'Accept': 'application/pdf,*/*',
    };
    final auth = await kycUploadAuthHeaders();
    if (auth != null) {
      headers.addAll(auth);
    }
    final dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 120),
        responseType: ResponseType.bytes,
        headers: headers,
      ),
    );
    final response = await dio.get<List<int>>(widget.url);
    final raw = response.data;
    if (raw == null || raw.isEmpty) {
      throw DioException(
        requestOptions: response.requestOptions,
        message: 'Empty PDF body',
      );
    }
    return Uint8List.fromList(raw);
  }

  @override
  void dispose() {
    _pdfController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingBytes) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_loadFailed || _pdfController == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.picture_as_pdf_outlined, size: 48, color: Colors.grey[600]),
              const SizedBox(height: 12),
              Text(
                widget.loc.t('admin.kyc.viewer_load_error'),
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[800]),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: widget.onRetry,
                icon: const Icon(Icons.refresh),
                label: Text(widget.loc.t('app.retry')),
              ),
            ],
          ),
        ),
      );
    }

    return PdfViewPinch(
      controller: _pdfController!,
      onDocumentError: (_) {
        if (mounted) setState(() => _loadFailed = true);
      },
    );
  }
}
