import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/config/env_config.dart';
import '../../../../core/feedback/app_feedback.dart';
import '../../../../core/kyc/kyc_public_document_url.dart';
import '../../../../core/kyc/submitted_document_slots.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../providers/auth_provider.dart';
import '../../../../services/submitted_documents_service.dart';
import '../../../../services/union_service.dart';
import '../../../admin/presentation/screens/simple_kyc_preview_screen.dart';
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
  /// Union KYC review state from GET /union/me (only meaningful for union_admin).
  String _unionDocumentsStatus = 'approved';

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
    final auth = context.read<AuthProvider>();
    final uid = auth.user?.id;
    final role = auth.user?.role ?? 'passenger';

    var unionDocStatus = 'approved';
    if (role == 'union_admin') {
      final ur = await UnionService().getMyUnion();
      if (ur['success'] == true) {
        final u = ur['union'];
        if (u is Map) {
          unionDocStatus = (u['documents_status'] ?? 'approved').toString();
        }
      } else {
        // Avoid showing "Verified" for union rows if status could not be loaded.
        unionDocStatus = 'pending';
      }
    }

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
        _unionDocumentsStatus = unionDocStatus;
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

  Map<String, dynamic>? _docForSlot(SubmittedDocumentSlot slot) {
    for (final d in _docs) {
      if ((d['label'] ?? '').toString() == slot.label &&
          (d['category'] ?? '').toString() == slot.category) {
        return d;
      }
    }
    return null;
  }

  String _statusLocKey({
    required bool hasFile,
    required String category,
    required String driverVerificationStatus,
    required String unionDocumentsStatus,
  }) {
    if (!hasFile) return 'kyc.submitted.status.not_uploaded';
    if (category == 'driver') {
      switch (driverVerificationStatus) {
        case 'approved':
          return 'kyc.submitted.status.submitted_verified';
        case 'pending':
          return 'kyc.submitted.status.submitted_pending';
        case 'rejected':
          return 'kyc.submitted.status.submitted_rejected';
        default:
          return 'kyc.submitted.status.submitted';
      }
    }
    if (category == 'union') {
      switch (unionDocumentsStatus) {
        case 'approved':
          return 'kyc.submitted.status.submitted_verified';
        case 'pending':
          return 'kyc.submitted.status.submitted_pending';
        case 'rejected':
          return 'kyc.submitted.status.submitted_rejected';
        case 'needs_reverify':
          return 'kyc.submitted.status.submitted_reupload';
        default:
          return 'kyc.submitted.status.submitted_pending';
      }
    }
    return 'kyc.submitted.status.submitted';
  }

  Color _statusColorForKey(String locKey) {
    if (locKey == 'kyc.submitted.status.not_uploaded') {
      return const Color(0xFF757575);
    }
    if (locKey == 'kyc.submitted.status.submitted_verified') {
      return const Color(0xFF2E7D32);
    }
    if (locKey == 'kyc.submitted.status.submitted_rejected' ||
        locKey == 'kyc.submitted.status.submitted_reupload') {
      return const Color(0xFFC62828);
    }
    if (locKey == 'kyc.submitted.status.submitted_pending') {
      return const Color(0xFFEF6C00);
    }
    return const Color(0xFF1565C0);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final loc = AppLocalizations.of(context);
    final role = auth.user?.role ?? 'passenger';
    final isUnionAdmin = role == 'union_admin';
    final drvStatus = auth.user?.driverVerificationStatus ?? 'none';
    final showDriverDocs = role == 'driver' ||
        drvStatus == 'pending' ||
        drvStatus == 'rejected';
    final expectedSlots = submittedSlotsForRoles(
      includeUnion: isUnionAdmin,
      includeDriver: showDriverDocs,
    );

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
                      if (expectedSlots.isNotEmpty) ...[
                        ...expectedSlots.map((slot) {
                          final d = _docForSlot(slot);
                          final url = (d?['url'] ?? '').toString();
                          final hasFile = url.isNotEmpty;
                          final full = hasFile ? _thumbUrl(url) : '';
                          final raster = hasFile && _isRasterUrl(full);
                          final statusKey = _statusLocKey(
                            hasFile: hasFile,
                            category: slot.category,
                            driverVerificationStatus: drvStatus,
                            unionDocumentsStatus: _unionDocumentsStatus,
                          );
                          final statusColor = _statusColorForKey(statusKey);
                          return Card(
                            child: ListTile(
                              leading: Opacity(
                                opacity: hasFile ? 1 : 0.45,
                                child: hasFile && raster
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
                                                width: 16,
                                                height: 16,
                                                child: CircularProgressIndicator(strokeWidth: 2),
                                              ),
                                            ),
                                          ),
                                          errorWidget: (_, __, ___) =>
                                              const Icon(Icons.broken_image_outlined, size: 20),
                                        ),
                                      )
                                    : hasFile
                                        ? CircleAvatar(
                                            backgroundColor: Colors.orange.shade100,
                                            child: Icon(Icons.picture_as_pdf_rounded,
                                                color: Colors.orange.shade800),
                                          )
                                        : CircleAvatar(
                                            backgroundColor: Colors.grey.shade200,
                                            child: Icon(Icons.upload_file_outlined,
                                                color: Colors.grey.shade600),
                                          ),
                              ),
                              title: Text(slot.label),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    loc.t(statusKey),
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: statusColor,
                                    ),
                                  ),
                                  if (hasFile) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      raster
                                          ? loc.t('kyc.submitted_list.hint_image')
                                          : loc.t('kyc.submitted_list.hint_file'),
                                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                                    ),
                                  ],
                                ],
                              ),
                              trailing: Icon(
                                hasFile ? Icons.chevron_right_rounded : Icons.lock_outline_rounded,
                                color: Colors.grey[500],
                              ),
                              onTap: hasFile
                                  ? () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => SimpleKycPreviewScreen(
                                            url: full,
                                            label: slot.label,
                                          ),
                                        ),
                                      );
                                    }
                                  : () {
                                      AppFeedback.show(
                                        context,
                                        loc.t('kyc.submitted.tap_disabled'),
                                        kind: AppFeedbackKind.info,
                                      );
                                    },
                            ),
                          );
                        }),
                      ] else if (_docs.isEmpty) ...[
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
                          final cat = (d['category'] ?? 'driver').toString();
                          final url = (d['url'] ?? '').toString();
                          final full = _thumbUrl(url);
                          final raster = _isRasterUrl(full);
                          final statusKey = _statusLocKey(
                            hasFile: url.isNotEmpty,
                            category: cat,
                            driverVerificationStatus: drvStatus,
                            unionDocumentsStatus: _unionDocumentsStatus,
                          );
                          final statusColor = _statusColorForKey(statusKey);
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
                                              width: 16,
                                              height: 16,
                                              child: CircularProgressIndicator(strokeWidth: 2),
                                            ),
                                          ),
                                        ),
                                        errorWidget: (_, __, ___) =>
                                            const Icon(Icons.broken_image_outlined, size: 20),
                                      ),
                                    )
                                  : CircleAvatar(
                                      backgroundColor: Colors.orange.shade100,
                                      child: Icon(Icons.picture_as_pdf_rounded,
                                          color: Colors.orange.shade800),
                                    ),
                              title: Text(label),
                              subtitle: Text(
                                loc.t(statusKey),
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: statusColor,
                                ),
                              ),
                              trailing: const Icon(Icons.chevron_right_rounded),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => SimpleKycPreviewScreen(
                                      url: full,
                                      label: label,
                                    ),
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
