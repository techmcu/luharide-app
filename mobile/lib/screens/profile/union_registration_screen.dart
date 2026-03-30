import 'package:cross_file/cross_file.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../services/union_service.dart';
import '../../services/upload_service.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/role_exclusivity.dart';
import '../../core/utils/kyc_image_picker.dart';
import '../../providers/app_language_provider.dart';
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
  final _shareNotesController = TextEditingController();
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
  XFile? _driverListPhotoFile;
  XFile? _leaderDlFrontFile;
  XFile? _leaderDlBackFile;
  XFile? _ownerRcFrontFile;
  XFile? _ownerRcBackFile;

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthProvider>().user;
    _phoneController.text = (user?.phone ?? '').trim();
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
    _shareNotesController.dispose();
    super.dispose();
  }

  Future<void> _loadStatus({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _loadingStatus = true;
        _statusError = null;
      });
    }

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

    if (_ownerAadhaarFrontFile == null || _ownerAadhaarBackFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Union leader ka Aadhaar front/back upload karna zaroori hai.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    String? ownerAadhaarFrontUrl;
    String? ownerAadhaarBackUrl;
    String? officePhotoUrl;
    String? driverListPhotoUrl;
    String? leaderDlFrontUrl;
    String? leaderDlBackUrl;
    String? ownerRcFrontUrl;
    String? ownerRcBackUrl;

    try {
      ownerAadhaarFrontUrl = await _uploadService.uploadUnionDocument(_ownerAadhaarFrontFile!);
      ownerAadhaarBackUrl = await _uploadService.uploadUnionDocument(_ownerAadhaarBackFile!);
      if (_officePhotoFile != null) {
        officePhotoUrl = await _uploadService.uploadUnionDocument(_officePhotoFile!);
      }
      if (_driverListPhotoFile != null) {
        driverListPhotoUrl = await _uploadService.uploadUnionDocument(_driverListPhotoFile!);
      }
      if (_leaderDlFrontFile != null) {
        leaderDlFrontUrl = await _uploadService.uploadUnionDocument(_leaderDlFrontFile!);
      }
      if (_leaderDlBackFile != null) {
        leaderDlBackUrl = await _uploadService.uploadUnionDocument(_leaderDlBackFile!);
      }
      if (_ownerRcFrontFile != null) {
        ownerRcFrontUrl = await _uploadService.uploadUnionDocument(_ownerRcFrontFile!);
      }
      if (_ownerRcBackFile != null) {
        ownerRcBackUrl = await _uploadService.uploadUnionDocument(_ownerRcBackFile!);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', '')),
          backgroundColor: Colors.red,
        ),
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
      ownerAadhaarUrl: ownerAadhaarFrontUrl,
      ownerAadhaarFrontUrl: ownerAadhaarFrontUrl,
      ownerAadhaarBackUrl: ownerAadhaarBackUrl,
      officePhotoUrl: officePhotoUrl,
      unionPhotoUrl: officePhotoUrl,
      unionDriverListPhotoUrl: driverListPhotoUrl,
      leaderDrivingLicenseFrontUrl: leaderDlFrontUrl,
      leaderDrivingLicenseBackUrl: leaderDlBackUrl,
      ownerVehicleRcUrl: ownerRcFrontUrl,
      ownerVehicleRcFrontUrl: ownerRcFrontUrl,
      ownerVehicleRcBackUrl: ownerRcBackUrl,
      unionShareNotes: _shareNotesController.text.trim(),
    );

    if (!mounted) return;

    setState(() => _isSubmitting = false);

    final auth = context.read<AuthProvider>();

    if (result['success'] == true) {
      // Refresh user so role/flags are up to date if backend sets them.
      await auth.refreshUser();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result['message']?.toString() ?? 'Union registered',
          ),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result['message']?.toString() ?? 'Failed to register union',
          ),
          backgroundColor: Colors.red,
        ),
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
                      loc.t('union.pending.body'),
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
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Colors.green),
            SizedBox(height: 16),
            Text('Union approved! Opening dashboard...', style: TextStyle(fontSize: 15)),
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
          const Text(
            'Union Details',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _ownerNameController,
            decoration: const InputDecoration(
              labelText: 'Union head name',
              border: OutlineInputBorder(),
            ),
            validator: (v) {
              final value = v?.trim() ?? '';
              if (value.isEmpty) return 'Please enter union head name';
              if (value.length < 2) return 'Name must be at least 2 characters';
              return null;
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Union name',
              border: OutlineInputBorder(),
            ),
            validator: (v) {
              final value = v?.trim() ?? '';
              if (value.isEmpty) return 'Please enter union name';
              if (value.length < 3) return 'Name must be at least 3 characters';
              return null;
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _locationController,
            decoration: const InputDecoration(
              labelText: 'Location (town / stand)',
              border: OutlineInputBorder(),
            ),
            validator: (v) {
              final value = v?.trim() ?? '';
              if (value.isEmpty) return 'Please enter location';
              return null;
            },
          ),
          const SizedBox(height: 16),
          const Text(
            'Upload documents (photos)',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            'Required: Leader Aadhaar front/back. Optional: union photo, driver list photo, leader DL front/back, RC front/back.',
            style: TextStyle(fontSize: 12, color: Colors.grey[700]),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _DocChip(
                label: 'Leader Aadhaar front *',
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
                label: 'Leader Aadhaar back *',
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
                label: 'Union photo',
                selected: _officePhotoFile != null,
                onTap: _isSubmitting
                    ? null
                    : () async {
                        final img = await pickKycGalleryPhoto();
                        if (img == null) return;
                        setState(() => _officePhotoFile = img);
                      },
              ),
              _DocChip(
                label: 'Driver list photo',
                selected: _driverListPhotoFile != null,
                onTap: _isSubmitting
                    ? null
                    : () async {
                        final img = await pickKycGalleryPhoto();
                        if (img == null) return;
                        setState(() => _driverListPhotoFile = img);
                      },
              ),
              _DocChip(
                label: 'Leader DL front',
                selected: _leaderDlFrontFile != null,
                onTap: _isSubmitting
                    ? null
                    : () async {
                        final img = await pickKycGalleryPhoto();
                        if (img == null) return;
                        setState(() => _leaderDlFrontFile = img);
                      },
              ),
              _DocChip(
                label: 'Leader DL back',
                selected: _leaderDlBackFile != null,
                onTap: _isSubmitting
                    ? null
                    : () async {
                        final img = await pickKycGalleryPhoto();
                        if (img == null) return;
                        setState(() => _leaderDlBackFile = img);
                      },
              ),
              _DocChip(
                label: 'Any cab RC front',
                selected: _ownerRcFrontFile != null,
                onTap: _isSubmitting
                    ? null
                    : () async {
                        final img = await pickKycGalleryPhoto();
                        if (img == null) return;
                        setState(() => _ownerRcFrontFile = img);
                      },
              ),
              _DocChip(
                label: 'Any cab RC back',
                selected: _ownerRcBackFile != null,
                onTap: _isSubmitting
                    ? null
                    : () async {
                        final img = await pickKycGalleryPhoto();
                        if (img == null) return;
                        setState(() => _ownerRcBackFile = img);
                      },
              ),
            ],
          ),
          const SizedBox(height: 24),
          TextFormField(
            controller: _shareNotesController,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Stand / share point details (optional)',
              hintText: 'e.g. Near bus stand, morning timings, landmark',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'Contact phone',
              border: OutlineInputBorder(),
            ),
            validator: (v) {
              final value = (v ?? '').trim();
              if (value.isEmpty) return 'Please enter contact phone';
              if (value.length < 8) return 'Phone must be at least 8 digits';
              return null;
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'Contact email',
              border: OutlineInputBorder(),
            ),
            validator: (v) {
              final value = (v ?? '').trim();
              if (value.isEmpty) return 'Please enter contact email';
              final ok = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value);
              if (!ok) return 'Please enter a valid email';
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
                  : const Text(
                      'Submit for Approval',
                      style: TextStyle(
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


