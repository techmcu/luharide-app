import 'package:flutter/material.dart';

import '../../core/config/env_config.dart';
import '../../core/feedback/app_feedback.dart';
import '../../core/utils/kyc_image_picker.dart';
import '../../services/union_service.dart';
import '../../services/upload_service.dart';

/// View / update union KYC (same flow as registration — upload + HTTPS URLs stored on server).
class UnionDocumentsScreen extends StatefulWidget {
  const UnionDocumentsScreen({super.key});

  @override
  State<UnionDocumentsScreen> createState() => _UnionDocumentsScreenState();
}

class _UnionDocumentsScreenState extends State<UnionDocumentsScreen> {
  final _upload = UploadService();
  final _notes = TextEditingController();
  final _ownerName = TextEditingController();
  bool _loading = true;
  bool _saving = false;
  String? _aadhaarUrl;
  String? _officeUrl;
  String? _rcUrl;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _notes.dispose();
    _ownerName.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final r = await UnionService().getMyUnion();
    if (!mounted) return;
    if (r['success'] == true) {
      final u = r['union'] as Map<String, dynamic>?;
      setState(() {
        _ownerName.text = (u?['owner_name'] ?? '').toString();
        _aadhaarUrl = u?['owner_aadhaar_url']?.toString();
        _officeUrl = u?['office_photo_url']?.toString();
        _rcUrl = u?['owner_vehicle_rc_url']?.toString();
        _notes.text = (u?['union_share_notes'] ?? '').toString();
        _loading = false;
      });
    } else {
      setState(() => _loading = false);
    }
  }

  String _fullUrl(String? u) {
    if (u == null || u.isEmpty) return '';
    if (u.startsWith('http://') || u.startsWith('https://')) return u;
    final base = EnvConfig.socketUrl.replaceAll(RegExp(r'/+$'), '');
    if (u.startsWith('/')) return '$base$u';
    return '$base/$u';
  }

  Future<void> _pick(void Function(String url) setUrl) async {
    final img = await pickKycGalleryPhoto();
    if (img == null) return;
    setState(() => _saving = true);
    try {
      final url = await _upload.uploadUnionDocument(img);
      setUrl(url);
    } catch (e) {
      if (mounted) {
        AppFeedback.show(
          context,
          '$e',
          kind: AppFeedbackKind.error,
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final r = await UnionService().updateUnionDocuments(
      ownerName: _ownerName.text.trim(),
      ownerAadhaarUrl: _aadhaarUrl,
      officePhotoUrl: _officeUrl,
      ownerVehicleRcUrl: _rcUrl,
      unionShareNotes: _notes.text.trim(),
    );
    if (!mounted) return;
    setState(() => _saving = false);
    AppFeedback.show(
      context,
      r['success'] == true ? (r['message'] ?? 'Saved') : (r['message'] ?? 'Error'),
      kind: r['success'] == true ? AppFeedbackKind.success : AppFeedbackKind.error,
    );
    if (r['success'] == true) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Union documents'),
        backgroundColor: const Color(0xFFFF6B00),
        foregroundColor: Colors.white,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                TextField(
                  controller: _ownerName,
                  decoration: const InputDecoration(
                    labelText: 'Union head name',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                const Text('Photos (tap to change)', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                _thumbRow(
                  'Aadhaar',
                  _aadhaarUrl,
                  () => _pick((u) => setState(() => _aadhaarUrl = u)),
                ),
                _thumbRow(
                  'Union center / office',
                  _officeUrl,
                  () => _pick((u) => setState(() => _officeUrl = u)),
                ),
                _thumbRow(
                  'Vehicle RC (sample)',
                  _rcUrl,
                  () => _pick((u) => setState(() => _rcUrl = u)),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _notes,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Stand / share point details (optional)',
                    hintText: 'e.g. Near bus stand gate 2, morning 6–10',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _saving ? null : _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF6B00),
                      foregroundColor: Colors.white,
                    ),
                    child: _saving
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('Save'),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _thumbRow(String label, String? url, VoidCallback onPick) {
    final full = _fullUrl(url);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 88,
            height: 88,
            child: Material(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(8),
              child: InkWell(
                onTap: onPick,
                borderRadius: BorderRadius.circular(8),
                child: full.isEmpty
                    ? const Icon(Icons.add_a_photo, size: 36)
                    : ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          full,
                          fit: BoxFit.cover,
                          width: 88,
                          height: 88,
                          errorBuilder: (_, __, ___) => const Icon(Icons.broken_image),
                        ),
                      ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
                TextButton.icon(
                  onPressed: onPick,
                  icon: const Icon(Icons.upload, size: 18),
                  label: const Text('Upload / change'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
