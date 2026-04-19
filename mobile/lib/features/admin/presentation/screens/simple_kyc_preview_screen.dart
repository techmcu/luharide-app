import 'package:flutter/material.dart';

import 'simple_kyc_preview_impl.dart';

/// In-app KYC preview (mobile + web). Same code path everywhere (no iframe / HtmlElementView).
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
        child: pdf ? KycPdfPreview(url: url) : KycImagePreview(url: url),
      ),
    );
  }
}
