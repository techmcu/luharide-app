import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/config/env_config.dart';
import '../../../../core/kyc/kyc_public_document_url.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../providers/auth_provider.dart';
import '../../../../services/submitted_documents_service.dart';
import '../../../admin/presentation/screens/kyc_document_viewer_screen.dart';
import 'driver_verification_form_screen.dart';
import 'union_documents_screen.dart';

/// Read-only list of KYC URLs the user has on file (watermarked uploads + merged PDFs).
class SubmittedDocumentsScreen extends StatefulWidget {
  const SubmittedDocumentsScreen({super.key});

  @override
  State<SubmittedDocumentsScreen> createState() => _SubmittedDocumentsScreenState();
}

class _SubmittedDocumentsScreenState extends State<SubmittedDocumentsScreen> {
  final _service = SubmittedDocumentsService();
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _docs = [];
  String _disclaimer = '';
  bool _fromCache = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load();
    });
  }

  Future<void> _load({bool forceRefresh = false}) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final uid = context.read<AuthProvider>().user?.id;
    final r = await _service.load(userId: uid, forceRefresh: forceRefresh);
    if (!mounted) return;
    if (r['success'] == true) {
      final data = r['data'] as Map<String, dynamic>?;
      final rawList = data?['documents'];
      final list = <Map<String, dynamic>>[];
      if (rawList is List) {
        for (final e in rawList) {
          if (e is Map) list.add(Map<String, dynamic>.from(e));
        }
      }
      setState(() {
        _disclaimer = (data?['disclaimer'] ?? '').toString();
        _docs = list;
        _fromCache = r['fromCache'] == true;
        _loading = false;
      });
    } else {
      setState(() {
        _error = r['message']?.toString() ?? 'Could not load';
        _loading = false;
      });
    }
  }

  String _thumbUrl(String relativeOrAbsolute) =>
      KycPublicDocumentUrl.resolve(relativeOrAbsolute, EnvConfig.publicFileBaseUrl);

  bool _isRasterUrl(String url) {
    final p = Uri.tryParse(url)?.path.toLowerCase() ?? url.toLowerCase();
    return p.endsWith('.jpg') ||
        p.endsWith('.jpeg') ||
        p.endsWith('.png') ||
        p.endsWith('.webp') ||
        p.endsWith('.gif');
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final role = auth.user?.role ?? 'passenger';
    final isUnionAdmin = role == 'union_admin';
    final drvStatus = auth.user?.driverVerificationStatus ?? 'none';
    final showDriverDocs = role == 'driver' ||
        drvStatus == 'pending' ||
        drvStatus == 'rejected';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Submitted documents'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _loading ? null : () => _load(forceRefresh: true),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(_error!, textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        FilledButton(
                          onPressed: () => _load(forceRefresh: true),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: () => _load(forceRefresh: true),
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      if (_fromCache)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text(
                            'Using saved list — pull to refresh for latest.',
                            style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                          ),
                        ),
                      if (_disclaimer.isNotEmpty)
                        Card(
                          color: Colors.blueGrey.shade50,
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Text(
                              _disclaimer,
                              style: TextStyle(
                                fontSize: 12.5,
                                height: 1.35,
                                color: Colors.blueGrey.shade900,
                              ),
                            ),
                          ),
                        ),
                      if (_docs.isEmpty) ...[
                        const SizedBox(height: 24),
                        Icon(Icons.folder_open_rounded, size: 56, color: Colors.grey[400]),
                        const SizedBox(height: 12),
                        Text(
                          role == 'passenger'
                              ? 'No documents on file. Passengers do not submit KYC here.'
                              : 'No documents on file yet. Upload from the options below when you are ready.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey[700]),
                        ),
                      ] else
                        ..._docs.map((d) {
                          final label = (d['label'] ?? 'Document').toString();
                          final url = (d['url'] ?? '').toString();
                          final full = _thumbUrl(url);
                          final raster = _isRasterUrl(full);
                          return Card(
                            child: ListTile(
                              leading: raster
                                  ? ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: CachedNetworkImage(
                                        imageUrl: full,
                                        width: 56,
                                        height: 56,
                                        fit: BoxFit.cover,
                                        memCacheWidth: 112,
                                        memCacheHeight: 112,
                                        placeholder: (_, __) => const SizedBox(
                                          width: 56,
                                          height: 56,
                                          child: Center(
                                            child: SizedBox(
                                              width: 20,
                                              height: 20,
                                              child: CircularProgressIndicator(strokeWidth: 2),
                                            ),
                                          ),
                                        ),
                                        errorWidget: (_, __, ___) => const Icon(Icons.broken_image_outlined),
                                      ),
                                    )
                                  : CircleAvatar(
                                      backgroundColor: Colors.orange.shade100,
                                      child: Icon(Icons.picture_as_pdf_rounded, color: Colors.orange.shade800),
                                    ),
                              title: Text(label),
                              subtitle: Text(
                                raster
                                    ? AppLocalizations.of(context).t('kyc.submitted_list.hint_image')
                                    : AppLocalizations.of(context).t('kyc.submitted_list.hint_file'),
                                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                              ),
                              trailing: const Icon(Icons.chevron_right_rounded),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => KycDocumentViewerScreen(storageUrl: url),
                                  ),
                                );
                              },
                            ),
                          );
                        }),
                      const SizedBox(height: 24),
                      if (isUnionAdmin)
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            icon: const Icon(Icons.upload_file_rounded),
                            label: const Text('Upload or change union documents'),
                            onPressed: () async {
                              final changed = await Navigator.push<bool>(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const UnionDocumentsScreen(),
                                ),
                              );
                              if (changed == true && mounted) {
                                final id = auth.user?.id;
                                if (id != null && id.isNotEmpty) {
                                  await _service.clearCacheForUser(id);
                                }
                                await _load(forceRefresh: true);
                              }
                            },
                          ),
                        ),
                      if (showDriverDocs)
                        Padding(
                          padding: EdgeInsets.only(top: isUnionAdmin ? 12 : 0),
                          child: SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              icon: const Icon(Icons.badge_rounded),
                              label: const Text('Driver verification & uploads'),
                              onPressed: () async {
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const DriverVerificationFormScreen(),
                                  ),
                                );
                                if (mounted) {
                                  await auth.refreshUser();
                                  final id = auth.user?.id;
                                  if (id != null && id.isNotEmpty) {
                                    await _service.clearCacheForUser(id);
                                  }
                                  await _load(forceRefresh: true);
                                }
                              },
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
    );
  }
}
