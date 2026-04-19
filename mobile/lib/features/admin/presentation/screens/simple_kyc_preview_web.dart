import 'dart:html' as html;
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';

import 'simple_kyc_preview_screen.dart';

Widget buildWebImagePreview(String url) => WebImagePreview(url: url);
Widget buildWebPdfPreview(String url) => WebPdfIframePreview(url: url);

/// Web: Use HTML img tag (no CORS issues)
class WebImagePreview extends StatefulWidget {
  const WebImagePreview({super.key, required this.url});
  final String url;

  @override
  State<WebImagePreview> createState() => _WebImagePreviewState();
}

class _WebImagePreviewState extends State<WebImagePreview> {
  final String _viewId = 'kyc-img-${DateTime.now().millisecondsSinceEpoch}';

  @override
  void initState() {
    super.initState();
    // Register platform view
    // ignore: undefined_prefixed_name
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
class WebPdfIframePreview extends StatefulWidget {
  const WebPdfIframePreview({super.key, required this.url});
  final String url;

  @override
  State<WebPdfIframePreview> createState() => _WebPdfIframePreviewState();
}

class _WebPdfIframePreviewState extends State<WebPdfIframePreview> {
  final String _viewId = 'kyc-pdf-${DateTime.now().millisecondsSinceEpoch}';

  @override
  void initState() {
    super.initState();
    // Register platform view
    // ignore: undefined_prefixed_name
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
