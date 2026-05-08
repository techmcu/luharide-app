import 'dart:typed_data';

import 'package:cross_file/cross_file.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../providers/auth_provider.dart';
import '../../../../providers/app_language_provider.dart';
import '../../../../services/union_service.dart';
import '../../../../services/upload_service.dart';
import '../../../../core/brand_config.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/role_exclusivity.dart';
import '../../../../core/utils/kyc_image_picker.dart';
import '../../../../core/constants/input_limits.dart';
import '../../../../core/feedback/app_feedback.dart';
import 'union_dashboard_screen.dart';

class UnionRegistrationScreen extends StatefulWidget {
  const UnionRegistrationScreen({super.key});

  @override
  State<UnionRegistrationScreen> createState() =>
      _UnionRegistrationScreenState();
}

class _UnionRegistrationScreenState extends State<UnionRegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _locationController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _ownerNameController = TextEditingController();
  bool _isSubmitting = false;
  bool _loadingStatus = true;
  bool _checkingStatus = false; // for manual check button
  String? _statusError;
  String _status = 'none';
  Map<String, dynamic>? _union;
  final _uploadService = UploadService();
  XFile? _ownerAadhaarFrontFile;
  XFile? _ownerAadhaarBackFile;
  XFile? _officePhotoFile;

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthProvider>().user;
    // Note: Phone number intentionally left empty - user must enter explicitly
    // to prevent accidental submission with wrong/old number
    _emailController.text = (user?.email ?? '').trim();
    _ownerNameController.text = (user?.name ?? '').trim();
    _loadStatus();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _locationController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _ownerNameController.dispose();
    super.dispose();
  }

  Future<void> _loadStatus({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _loadingStatus = true;
        _statusError = null;
      });
    }

    await context.read<AuthProvider>().refreshUser();
    if (!mounted) return;

    final service = UnionService();
    final result = await service.getMyUnion();

    if (!mounted) return;

    if (result['success'] == true) {
      final newStatus = (result['status'] ?? 'none').toString();
      setState(() {
        _status = newStatus;
        _union = result['union'] as Map<String, dynamic>?;
        _loadingStatus = false;
        _checkingStatus = false;
      });

      // If approved, refresh auth user so role updates everywhere (profile, home)
      if (newStatus == 'approved') {
        await context.read<AuthProvider>().refreshUser();
        if (!mounted) return;
        // Navigate directly to Union Dashboard (replace this screen)
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const UnionDashboardScreen()),
        );
      }
    } else {
      setState(() {
        _statusError = result['message']?.toString();
        _loadingStatus = false;
        _checkingStatus = false;
      });
    }
  }

  /// Manual check — single server call, no polling loop.
  Future<void> _checkStatus() async {
    if (_checkingStatus) return;
    setState(() => _checkingStatus = true);
    await _loadStatus(silent: true);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_ownerAadhaarFrontFile == null ||
        _ownerAadhaarBackFile == null ||
        _officePhotoFile == null) {
      AppFeedback.show(
        context,
        AppLocalizations.of(context).t('kyc.union.snack.missing_docs'),
        kind: AppFeedbackKind.warning,
      );
      return;
    }

    setState(() => _isSubmitting = true);

    String? ownerAadhaarFrontUrl;
    String? ownerAadhaarBackUrl;
    String? officePhotoUrl;

    try {
      ownerAadhaarFrontUrl =
          await _uploadService.uploadUnionDocument(_ownerAadhaarFrontFile!);
      ownerAadhaarBackUrl =
          await _uploadService.uploadUnionDocument(_ownerAadhaarBackFile!);
      officePhotoUrl = await _uploadService.uploadUnionDocument(_officePhotoFile!);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      AppFeedback.show(
        context,
        e.toString().replaceAll('Exception: ', ''),
        kind: AppFeedbackKind.error,
      );
      return;
    }

    final service = UnionService();
    final result = await service.registerUnion(
      name: _nameController.text.trim(),
      location: _locationController.text.trim(),
      contactPhone: _phoneController.text.trim(),
      contactEmail: _emailController.text.trim(),
      ownerName: _ownerNameController.text.trim(),
      ownerAadhaarFrontUrl: ownerAadhaarFrontUrl,
      ownerAadhaarBackUrl: ownerAadhaarBackUrl,
      officePhotoUrl: officePhotoUrl,
      unionPhotoUrl: officePhotoUrl,
    );

    if (!mounted) return;

    setState(() => _isSubmitting = false);

    final auth = context.read<AuthProvider>();

    if (result['success'] == true) {
      // Refresh user so role/flags are up to date if backend sets them.
      await auth.refreshUser();
      if (!mounted) return;
      AppFeedback.show(
        context,
        result['message']?.toString() ?? 'Union registered',
        kind: AppFeedbackKind.success,
      );
      Navigator.pop(context);
    } else {
      AppFeedback.show(
        context,
        result['message']?.toString() ?? 'Failed to register union',
        kind: AppFeedbackKind.error,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    context.watch<AppLanguageProvider>();
    final loc = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(loc.t('union.register.title')),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
      ),
      body: _loadingStatus
          ? const Center(child: CircularProgressIndicator())
          : _buildBody(),
    );
  }

  Widget _buildUnionWarningCard(BuildContext context) {
    final loc = AppLocalizations.of(context);
    return Card(
      color: Colors.orange[50],
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.orange.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.info_outline, color: Colors.orange[800], size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    loc.t('union.warning.title'),
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Colors.orange[900],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    loc.t('union.warning.body'),
                    style: TextStyle(fontSize: 13, color: Colors.orange[900], height: 1.4),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    // Pending — show status card + manual check button (no auto-polling)
    if (_status == 'pending' && _union != null) {
      final name = (_union!['name'] ?? '').toString();
      final location = (_union!['address'] ?? _union!['location'] ?? '').toString();
      final loc = AppLocalizations.of(context);
      return Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              color: Colors.orange[50],
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.hourglass_empty, color: Colors.orange[700], size: 22),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            loc.t('union.pending.title'),
                            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      name.isNotEmpty ? name : loc.t('union.pending.name_placeholder'),
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                    if (location.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(location, style: const TextStyle(fontSize: 14)),
                    ],
                    const SizedBox(height: 12),
                    Text(
                      loc.tReplace('union.pending.body', {'supportEmail': BrandConfig.supportEmail}),
                      style: TextStyle(fontSize: 13, color: Colors.grey[700], height: 1.4),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _checkingStatus ? null : _checkStatus,
              icon: _checkingStatus
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.refresh),
              label: Text(_checkingStatus ? loc.t('union.pending.checking') : loc.t('union.pending.check')),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      );
    }

    // Approved — auto-navigates to dashboard via _loadStatus; show loading state here
    if (_status == 'approved') {
      final loc = AppLocalizations.of(context);
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: Colors.green),
            const SizedBox(height: 16),
            Text(loc.t('kyc.union.approved_nav'), style: const TextStyle(fontSize: 15)),
          ],
        ),
      );
    }

    final user = context.watch<AuthProvider>().user;
    if (RoleExclusivity.blocksUnionRegistration(user)) {
      final loc = AppLocalizations.of(context);
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.block, size: 56, color: Colors.orange[700]),
              const SizedBox(height: 16),
              Text(
                loc.t('exclusivity.union_blocked.title'),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              Text(
                loc.t('exclusivity.union_blocked.body'),
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.grey[800], height: 1.4),
              ),
            ],
          ),
        ),
      );
    }

    // Default: show registration form
    final loc = AppLocalizations.of(context);
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildUnionWarningCard(context),
          const SizedBox(height: 16),
          if (_statusError != null) ...[
            Text(
              _statusError!,
              style: const TextStyle(color: Colors.red),
            ),
            const SizedBox(height: 12),
          ],
          Text(
            loc.t('kyc.union.details_section'),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _ownerNameController,
            maxLength: InputLimits.name,
            decoration: InputDecoration(
              counterText: '',
              labelText: loc.t('kyc.union.leader_name'),
              border: const OutlineInputBorder(),
            ),
            validator: (v) {
              final value = v?.trim() ?? '';
              if (value.isEmpty) return loc.t('kyc.union.name_required');
              if (value.length < 2) return loc.t('kyc.union.name_short');
              return null;
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _nameController,
            maxLength: InputLimits.unionName,
            decoration: InputDecoration(
              counterText: '',
              labelText: loc.t('kyc.union.union_name'),
              border: const OutlineInputBorder(),
            ),
            validator: (v) {
              final value = v?.trim() ?? '';
              if (value.isEmpty) return loc.t('kyc.union.union_name_required');
              if (value.length < 3) return loc.t('kyc.union.union_name_short');
              return null;
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _locationController,
            maxLength: InputLimits.unionLocation,
            decoration: InputDecoration(
              counterText: '',
              labelText: loc.t('kyc.union.location'),
              border: const OutlineInputBorder(),
            ),
            validator: (v) {
              final value = v?.trim() ?? '';
              if (value.isEmpty) return loc.t('kyc.union.location_required');
              return null;
            },
          ),
          const SizedBox(height: 16),
          Text(
            loc.t('kyc.union.upload_heading'),
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            loc.t('kyc.union.upload_note'),
            style: TextStyle(fontSize: 12, color: Colors.grey[700], height: 1.35),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _DocChip(
                label: loc.t('kyc.union.chip.aadhaar_front'),
                selected: _ownerAadhaarFrontFile != null,
                onTap: _isSubmitting
                    ? null
                    : () async {
                        final img = await pickKycGalleryPhoto();
                        if (img == null) return;
                        setState(() => _ownerAadhaarFrontFile = img);
                      },
              ),
              _DocChip(
                label: loc.t('kyc.union.chip.aadhaar_back'),
                selected: _ownerAadhaarBackFile != null,
                onTap: _isSubmitting
                    ? null
                    : () async {
                        final img = await pickKycGalleryPhoto();
                        if (img == null) return;
                        setState(() => _ownerAadhaarBackFile = img);
                      },
              ),
              _DocChip(
                label: loc.t('kyc.union.chip.photo'),
                selected: _officePhotoFile != null,
                onTap: _isSubmitting
                    ? null
                    : () async {
                        final img = await pickKycGalleryPhoto();
                        if (img == null) return;
                        setState(() => _officePhotoFile = img);
                      },
              ),
            ],
          ),
          if (_ownerAadhaarFrontFile != null ||
              _ownerAadhaarBackFile != null ||
              _officePhotoFile != null) ...[
            const SizedBox(height: 12),
            Text(
              loc.t('kyc.union.preview_label'),
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey[800]),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                if (_ownerAadhaarFrontFile != null)
                  _KycPickedThumb(label: loc.t('kyc.union.chip.aadhaar_front'), file: _ownerAadhaarFrontFile!),
                if (_ownerAadhaarBackFile != null)
                  _KycPickedThumb(label: loc.t('kyc.union.chip.aadhaar_back'), file: _ownerAadhaarBackFile!),
                if (_officePhotoFile != null)
                  _KycPickedThumb(label: loc.t('kyc.union.chip.photo'), file: _officePhotoFile!),
              ],
            ),
          ],
          const SizedBox(height: 24),
          TextFormField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            maxLength: InputLimits.phone,
            decoration: InputDecoration(
              counterText: '',
              labelText: loc.t('kyc.union.label.leader_phone'),
              hintText: 'Enter 10-digit mobile number',
              border: const OutlineInputBorder(),
            ),
            validator: (v) {
              final value = (v ?? '').replaceAll(' ', '').trim();
              if (value.isEmpty) return 'Mobile number is required';
              if (!RegExp(r'^\d{10}$').hasMatch(value)) {
                return 'Enter valid 10-digit mobile number';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            maxLength: InputLimits.email,
            decoration: InputDecoration(
              counterText: '',
              labelText: loc.t('kyc.union.label.leader_email'),
              border: const OutlineInputBorder(),
            ),
            validator: (v) {
              final value = (v ?? '').trim();
              if (value.isEmpty) return loc.t('kyc.union.val.email');
              final ok = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value);
              if (!ok) return loc.t('kyc.union.val.email_invalid');
              return null;
            },
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 50,
            child: ElevatedButton(
              onPressed: _isSubmitting ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isSubmitting
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor:
                            AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Text(
                      loc.t('kyc.union.submit'),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Works on web (no dart:io) and mobile via [XFile.readAsBytes].
class _KycPickedThumb extends StatelessWidget {
  const _KycPickedThumb({required this.label, required this.file});

  final String label;
  final XFile file;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[700])),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: FutureBuilder<Uint8List>(
            future: file.readAsBytes(),
            builder: (context, snap) {
              if (snap.connectionState != ConnectionState.done) {
                return const SizedBox(
                  width: 96,
                  height: 72,
                  child: Center(child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))),
                );
              }
              if (snap.hasError || !snap.hasData) {
                return Container(
                  width: 96,
                  height: 72,
                  color: Colors.grey[200],
                  child: Icon(Icons.broken_image_outlined, color: Colors.grey[600]),
                );
              }
              return Image.memory(
                snap.data!,
                width: 96,
                height: 72,
                fit: BoxFit.cover,
                gaplessPlayback: true,
                errorBuilder: (_, __, ___) => Container(
                  width: 96,
                  height: 72,
                  color: Colors.grey[200],
                  child: Icon(Icons.broken_image_outlined, color: Colors.grey[600]),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _DocChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback? onTap;

  const _DocChip({
    required this.label,
    required this.selected,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? Colors.green[50] : Colors.grey[100],
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? Colors.green : Colors.grey[300]!),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              selected ? Icons.check_circle : Icons.upload_file,
              size: 16,
              color: selected ? Colors.green[700] : Colors.grey[700],
            ),
            const SizedBox(width: 6),
            Text(label, style: const TextStyle(fontSize: 12)),
          ],
        ),
      ),
    );
  }
}


