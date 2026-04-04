import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../core/config/env_config.dart';
import '../../core/localization/app_localizations.dart';

/// In-app preview for admin KYC URLs (`/uploads/...` or absolute). Falls back to browser on web.
class KycDocumentViewerScreen extends StatefulWidget {
  const KycDocumentViewerScreen({super.key, required this.storageUrl});

  /// Path from API e.g. `/uploads/driver-docs/x.jpg` or full `https://...`
  final String storageUrl;

  @override
  State<KycDocumentViewerScreen> createState() => _KycDocumentViewerScreenState();
}

class _KycDocumentViewerScreenState extends State<KycDocumentViewerScreen> {
  WebViewController? _controller;
  bool _loading = true;
  String? _error;
  late final String _resolved;

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
      _error = 'Invalid URL';
      _loading = false;
      return;
    }
    final c = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) {
            if (mounted) setState(() => _loading = false);
          },
          onWebResourceError: (WebResourceError err) {
            if (mounted) {
              setState(() {
                _loading = false;
                _error = err.description;
              });
            }
          },
        ),
      )
      ..loadRequest(uri);
    _controller = c;
  }

  Future<void> _openExternal() async {
    final uri = Uri.tryParse(_resolved);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(loc.t('admin.kyc.viewer_title')),
        actions: [
          IconButton(
            tooltip: loc.t('admin.kyc.viewer_open_browser'),
            icon: const Icon(Icons.open_in_browser),
            onPressed: _openExternal,
          ),
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
                      onPressed: _openExternal,
                      icon: const Icon(Icons.open_in_new),
                      label: Text(loc.t('admin.kyc.viewer_open_browser')),
                    ),
                  ],
                ),
              ),
            )
          : _isRasterImageUrl(_resolved)
              ? _RasterKycPreview(
                  url: _resolved,
                  onOpenExternal: _openExternal,
                  loc: loc,
                )
              : Stack(
                  children: [
                    if (_controller != null && _error == null)
                      WebViewWidget(controller: _controller!),
                    if (_error != null)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.broken_image_outlined, size: 48, color: Colors.grey[600]),
                              const SizedBox(height: 12),
                              Text(
                                _error!,
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.grey[800]),
                              ),
                              const SizedBox(height: 16),
                              FilledButton.icon(
                                onPressed: _openExternal,
                                icon: const Icon(Icons.open_in_browser),
                                label: Text(loc.t('admin.kyc.viewer_open_browser')),
                              ),
                            ],
                          ),
                        ),
                      ),
                    if (_loading && _error == null)
                      const Center(child: CircularProgressIndicator()),
                  ],
                ),
    );
  }
}

class _RasterKycPreview extends StatelessWidget {
  const _RasterKycPreview({
    required this.url,
    required this.onOpenExternal,
    required this.loc,
  });

  final String url;
  final VoidCallback onOpenExternal;
  final AppLocalizations loc;

  @override
  Widget build(BuildContext context) {
    return InteractiveViewer(
      minScale: 0.5,
      maxScale: 4,
      child: Center(
        child: Image.network(
          url,
          fit: BoxFit.contain,
          loadingBuilder: (context, child, progress) {
            if (progress == null) return child ?? const SizedBox.shrink();
            return const Padding(
              padding: EdgeInsets.all(48),
              child: CircularProgressIndicator(),
            );
          },
          errorBuilder: (context, err, stack) {
            return Padding(
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
                    onPressed: onOpenExternal,
                    icon: const Icon(Icons.open_in_browser),
                    label: Text(loc.t('admin.kyc.viewer_open_browser')),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
