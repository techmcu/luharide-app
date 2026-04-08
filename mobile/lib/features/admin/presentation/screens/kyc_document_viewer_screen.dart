import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../../../core/config/env_config.dart';
import '../../../../core/localization/app_localizations.dart';

/// In-app preview for KYC files (`/uploads/...` or absolute). Mobile stays in-app only (no raw URLs in UI, no external browser). Web offers opening in a browser tab.
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
  int _rasterRetryKey = 0;

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

  void _retryPdf(Uri uri, AppLocalizations loc) {
    setState(() {
      _webViewFailed = false;
      _loading = true;
      _controller = _buildPdfController(uri, loc);
    });
  }

  @override
  void initState() {
    super.initState();
    _resolved = _resolveUrl(widget.storageUrl);
    if (kIsWeb) {
      _loading = false;
      return;
    }
    if (_isRasterImageUrl(_resolved)) {
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

    return Scaffold(
      appBar: AppBar(
        title: Text(loc.t('admin.kyc.viewer_title')),
        actions: [
          if (kIsWeb)
            IconButton(
              tooltip: loc.t('admin.kyc.viewer_open_browser'),
              icon: const Icon(Icons.open_in_new),
              onPressed: _openInBrowserTab,
            )
          else ...[
            if (_isRasterImageUrl(_resolved))
              IconButton(
                tooltip: loc.t('app.refresh'),
                icon: const Icon(Icons.refresh),
                onPressed: () => setState(() => _rasterRetryKey++),
              )
            else if (uri != null && (_controller != null || _webViewFailed))
              IconButton(
                tooltip: loc.t('app.refresh'),
                icon: const Icon(Icons.refresh),
                onPressed: () => _retryPdf(uri),
              ),
          ],
        ],
      ),
      body: kIsWeb
          ? Center(
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
            )
          : _isRasterImageUrl(_resolved)
              ? _RasterKycPreview(
                  key: ValueKey<int>(_rasterRetryKey),
                  url: _resolved,
                  loc: loc,
                  onRetry: () => setState(() => _rasterRetryKey++),
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
                                  onPressed: () => _retryPdf(uri),
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

class _RasterKycPreview extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return InteractiveViewer(
      minScale: 0.5,
      maxScale: 4,
      child: Center(
        child: CachedNetworkImage(
          imageUrl: url,
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
                  loc.t('admin.kyc.viewer_image_error'),
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey[800]),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh),
                  label: Text(loc.t('app.retry')),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
