import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../services/union_service.dart';
import '../../services/upload_service.dart';
import 'edit_profile_screen.dart';
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
  File? _ownerAadhaarFile;
  File? _officePhotoFile;
  File? _ownerRcFile;

  @override
  void initState() {
    super.initState();
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

    if (_ownerAadhaarFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Union leader ka Aadhaar photo upload karna zaroori hai.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    String? ownerAadhaarUrl;
    String? officePhotoUrl;
    String? ownerRcUrl;

    try {
      if (_ownerAadhaarFile != null) {
        ownerAadhaarUrl = await _uploadService.uploadUnionDocument(_ownerAadhaarFile!);
      }
      if (_officePhotoFile != null) {
        officePhotoUrl = await _uploadService.uploadUnionDocument(_officePhotoFile!);
      }
      if (_ownerRcFile != null) {
        ownerRcUrl = await _uploadService.uploadUnionDocument(_ownerRcFile!);
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
      ownerAadhaarUrl: ownerAadhaarUrl,
      officePhotoUrl: officePhotoUrl,
      ownerVehicleRcUrl: ownerRcUrl,
      unionShareNotes: _shareNotesController.text.trim(),
    );

    if (!mounted) return;

    setState(() => _isSubmitting = false);

    final auth = context.read<AuthProvider>();

    if (result['success'] == true) {
      // Refresh user so role/flags are up to date if backend sets them.
      await auth.refreshUser();
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add your union'),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
      ),
      body: _loadingStatus
          ? const Center(child: CircularProgressIndicator())
          : _buildBody(),
    );
  }

  /// Optional hint — profile incomplete does not block the form anymore.
  Widget _buildProfileHintBanner(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    final hasPhone = (user?.phone ?? '').trim().isNotEmpty;
    final hasEmail = (user?.email ?? '').trim().isNotEmpty;
    final hasPic = (user?.profileImage ?? '').trim().isNotEmpty;
    if (hasPhone && hasEmail && hasPic) return const SizedBox.shrink();

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      color: Colors.amber.shade50,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.amber.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.person_pin_circle_outlined, color: Colors.amber.shade900, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Behtar hai: profile mein phone, email aur photo bharein taaki admin aap se contact kar sake. '
                    'Form phir bhi yahin se bhar sakte hain.',
                    style: TextStyle(fontSize: 13, color: Colors.amber.shade900, height: 1.35),
                  ),
                ),
              ],
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const EditProfileScreen()),
                  ).then((_) {
                    if (mounted) context.read<AuthProvider>().refreshUser();
                  });
                },
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: const Text('Profile edit'),
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
                        const Text(
                          'Waiting for approval',
                          style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      name.isNotEmpty ? name : 'Your taxi union',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                    if (location.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(location, style: const TextStyle(fontSize: 14)),
                    ],
                    const SizedBox(height: 12),
                    Text(
                      'Your union request has been submitted. App admin usually reviews within 24–48 hours.\n'
                      'Tap \"Check status\" after some time to see if it was approved.\n\n'
                      'Agar isse zyada delay ho jaye, to aap supportluharide@gmail.com par politely email karke '
                      'apni union request ka status pooch sakte hain (subject mein union ka naam aur apna phone number likh kar).',
                      style: TextStyle(fontSize: 13, color: Colors.grey[700]),
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
              label: Text(_checkingStatus ? 'Checking...' : 'Check status'),
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

    // Default: show registration form
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildProfileHintBanner(context),
          Card(
            color: Colors.orange[50],
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.warning_amber_rounded, color: Colors.orange[700]),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Yeh form sirf adhikarik taxi union ke representative ke liye hai.\n\n'
                      'Agar aap union manage nahi karte aur galat jankari ke saath form submit karte hain, '
                      'to aapka account block ya limit kiya ja sakta hai.\n\n'
                      'Kripya form sirf tabhi bharein jab aap iske liye yogya hon.',
                      style: TextStyle(fontSize: 13, color: Colors.orange[900]),
                    ),
                  ),
                ],
              ),
            ),
          ),
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
            'Union leader Aadhaar — zaroori; office photo aur RC bhi upload karein.',
            style: TextStyle(fontSize: 12, color: Colors.grey[700]),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _DocChip(
                label: 'Leader Aadhaar *',
                selected: _ownerAadhaarFile != null,
                onTap: _isSubmitting
                    ? null
                    : () async {
                        final picker = ImagePicker();
                        final img = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
                        if (img == null) return;
                        setState(() => _ownerAadhaarFile = File(img.path));
                      },
              ),
              _DocChip(
                label: 'Office photo',
                selected: _officePhotoFile != null,
                onTap: _isSubmitting
                    ? null
                    : () async {
                        final picker = ImagePicker();
                        final img = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
                        if (img == null) return;
                        setState(() => _officePhotoFile = File(img.path));
                      },
              ),
              _DocChip(
                label: 'Any cab RC',
                selected: _ownerRcFile != null,
                onTap: _isSubmitting
                    ? null
                    : () async {
                        final picker = ImagePicker();
                        final img = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
                        if (img == null) return;
                        setState(() => _ownerRcFile = File(img.path));
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
              labelText: 'Contact phone (optional)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'Contact email (optional)',
              border: OutlineInputBorder(),
            ),
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


