import 'package:flutter/material.dart';

import 'simple_kyc_preview_impl.dart';

/// In-app KYC preview (mobile + web). Files load via `/api/kyc/document-file` or
/// `/api/admin/document-file` (JWT + same CORS as API — reliable on web).
class SimpleKycPreviewScreen extends StatelessWidget {
  const SimpleKycPreviewScreen({
    super.key,
    required this.url,
    required this.label,
    this.useAdminFileApi = false,
  });

  /// Storage URL from API (`/uploads/...` or absolute https URL).
  final String url;
  final String label;

  /// Union admin dashboard: use `/api/admin/document-file` (any KYC path on disk).
  final bool useAdminFileApi;

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
        child: pdf
            ? KycPdfPreview(url: url, useAdminFileApi: useAdminFileApi)
            : KycImagePreview(url: url, useAdminFileApi: useAdminFileApi),
      ),
    );
  }
}
