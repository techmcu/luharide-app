import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../models/vehicle_catalog.dart';
import '../../services/driver_verification_service.dart';
import '../../services/upload_service.dart';
import '../../services/union_service.dart';
import '../../providers/auth_provider.dart';
import '../../core/role_exclusivity.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/utils/kyc_image_picker.dart';
import '../../providers/app_language_provider.dart';

/// Form to submit driver verification documents.
/// Vehicle is selected from dropdown (fixed layout + seat count); no manual seat entry.
class DriverVerificationFormScreen extends StatefulWidget {
  const DriverVerificationFormScreen({super.key});

  @override
  State<DriverVerificationFormScreen> createState() =>
      _DriverVerificationFormScreenState();
}

class _DriverVerificationFormScreenState
    extends State<DriverVerificationFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _service = DriverVerificationService();
  final _uploadService = UploadService();
  final _licenseController = TextEditingController();
  final _vehicleRegController = TextEditingController();
  final _contactPhoneController = TextEditingController();
  final _contactEmailController = TextEditingController();
  bool _isLoading = false;
  VehicleDropdownOption? _selectedVehicle;
  XFile? _aadhaarFrontFile;
  XFile? _aadhaarBackFile;
  XFile? _licenseFrontFile;
  XFile? _licenseBackFile;
  bool _checkingUnionPath = true;
  bool _unionPathBlocksIndependent = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = context.read<AuthProvider>();
      _contactPhoneController.text = (auth.user?.phone ?? '').trim();
      _contactEmailController.text = (auth.user?.email ?? '').trim();
      _checkUnionExclusivity();
    });
  }

  Future<void> _checkUnionExclusivity() async {
    final auth = context.read<AuthProvider>();
    try {
      final r = await UnionService().getMyUnion();
      if (!mounted) return;
      final st = (r['status'] ?? 'none').toString();
      final blocked = RoleExclusivity.blocksIndependentDriver(
        user: auth.user,
        unionStatusFromApi: st,
      );
      setState(() {
        _unionPathBlocksIndependent = blocked;
        _checkingUnionPath = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _unionPathBlocksIndependent = RoleExclusivity.blocksIndependentDriver(
            user: auth.user,
            unionStatusFromApi: 'none',
          );
          _checkingUnionPath = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _licenseController.dispose();
    _vehicleRegController.dispose();
    _contactPhoneController.dispose();
    _contactEmailController.dispose();
    super.dispose();
  }

  Future<void> _pickDocument(void Function(XFile) setter) async {
    final img = await pickKycGalleryPhoto();
    if (img == null) return;
    setter(img);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedVehicle == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please select your vehicle'),
            backgroundColor: Colors.orange),
      );
      return;
    }

    if (_aadhaarFrontFile == null ||
        _aadhaarBackFile == null ||
        _licenseFrontFile == null ||
        _licenseBackFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                'Aadhaar front/back aur Driving License front/back ki photos zaroori hain.'),
            backgroundColor: Colors.orange),
      );
      return;
    }

    setState(() => _isLoading = true);

    String? aadhaarFrontUrl;
    String? aadhaarBackUrl;
    String? licenseFrontUrl;
    String? licenseBackUrl;

    try {
      aadhaarFrontUrl =
          await _uploadService.uploadDriverDocument(_aadhaarFrontFile!);
      aadhaarBackUrl =
          await _uploadService.uploadDriverDocument(_aadhaarBackFile!);
      licenseFrontUrl =
          await _uploadService.uploadDriverDocument(_licenseFrontFile!);
      licenseBackUrl =
          await _uploadService.uploadDriverDocument(_licenseBackFile!);
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    final v = _selectedVehicle!;
    final vehicleType = v.displayName.contains(' ')
        ? v.displayName.split(' ').first
        : v.displayName;
    final vehicleModel = v.displayName;

    final result = await _service.submitVerification(
      drivingLicenseNumber: _licenseController.text.trim(),
      drivingLicenseUrl: licenseFrontUrl,
      vehicleRegistration: _vehicleRegController.text.trim(),
      vehicleType: vehicleType,
      vehicleModel: vehicleModel,
      vehicleModelId: v.id,
      vehicleCapacity: v.capacity,
      contactPhone: _contactPhoneController.text.replaceAll(' ', '').trim(),
      contactEmail: _contactEmailController.text.trim(),
      permitDocumentUrl: null,
      insuranceDocumentUrl: null,
      aadhaarDocumentUrl: aadhaarFrontUrl,
      aadhaarFrontUrl: aadhaarFrontUrl,
      aadhaarBackUrl: aadhaarBackUrl,
      drivingLicenseFrontUrl: licenseFrontUrl,
      drivingLicenseBackUrl: licenseBackUrl,
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (result['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(result['message'] ?? 'Submitted! Admin will review.'),
            backgroundColor: Colors.green),
      );
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(result['message'] ?? 'Failed'),
            backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    context.watch<AppLanguageProvider>();
    final loc = AppLocalizations.of(context);
    if (_checkingUnionPath) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Become a Driver'),
          backgroundColor: Colors.green,
          foregroundColor: Colors.white,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (_unionPathBlocksIndependent) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Become a Driver'),
          backgroundColor: Colors.green,
          foregroundColor: Colors.white,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.info_outline, size: 56, color: Colors.green[800]),
                const SizedBox(height: 16),
                Text(
                  loc.t('exclusivity.driver_blocked.title'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                Text(
                  loc.t('exclusivity.driver_blocked.body'),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 14, color: Colors.grey[800], height: 1.4),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Become a Driver'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  controller: _contactPhoneController,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    labelText: 'Contact number (driver)',
                    prefixIcon: const Icon(Icons.phone_outlined),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  validator: (v) {
                    final s = (v ?? '').replaceAll(' ', '').trim();
                    if (s.length < 10) return 'Valid phone number zaroori hai';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _contactEmailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: 'Email ID (driver)',
                    prefixIcon: const Icon(Icons.email_outlined),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  validator: (v) {
                    final s = (v ?? '').trim();
                    if (s.isEmpty) return 'Email zaroori hai';
                    if (!s.contains('@') || !s.contains('.')) {
                      return 'Sahi email likhein';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                Card(
                  color: Colors.blue[50],
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.blue[700]),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Yeh form sirf asli taxi drivers ke liye hai. Galat / jhoothi details bharne par aapka account block ho sakta hai.\n\n'
                            'Submit your documents for verification. Admin will review within 24-48 hours.',
                            style: TextStyle(
                                fontSize: 14, color: Colors.blue[900]),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _licenseController,
                  decoration: InputDecoration(
                    labelText: 'Driving License Number',
                    hintText: 'DL-XX-XXXX-XXXX',
                    prefixIcon: const Icon(Icons.badge),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Upload documents',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Text(
                  'Har file ka size kam se kam 50 KB aur zyada se zyada 10 MB ho (photo ya PDF). Is se chhoti ya bahut badi file upload na karein.\n'
                  'Images par server "Verified by LuhaRide" ka watermark laga sakta hai — sirf verification ke liye.',
                  style: TextStyle(fontSize: 12, color: Colors.grey[800], height: 1.35),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _DocChip(
                      label: 'Aadhaar front *',
                      selected: _aadhaarFrontFile != null,
                      onTap: _isLoading
                          ? null
                          : () => _pickDocument(
                              (f) => setState(() => _aadhaarFrontFile = f)),
                    ),
                    _DocChip(
                      label: 'Aadhaar back *',
                      selected: _aadhaarBackFile != null,
                      onTap: _isLoading
                          ? null
                          : () => _pickDocument(
                              (f) => setState(() => _aadhaarBackFile = f)),
                    ),
                    _DocChip(
                      label: 'Driving licence front *',
                      selected: _licenseFrontFile != null,
                      onTap: _isLoading
                          ? null
                          : () => _pickDocument(
                              (f) => setState(() => _licenseFrontFile = f)),
                    ),
                    _DocChip(
                      label: 'Driving licence back *',
                      selected: _licenseBackFile != null,
                      onTap: _isLoading
                          ? null
                          : () => _pickDocument(
                              (f) => setState(() => _licenseBackFile = f)),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _vehicleRegController,
                  decoration: InputDecoration(
                    labelText: 'Vehicle Registration (RC)',
                    hintText: 'e.g. UK07AB1234',
                    prefixIcon: const Icon(Icons.directions_car),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 20),
                // Kaunsi gadi hai aapko? — dropdown fixes seat count & layout (RTO-style)
                const Text(
                  'Kaunsi gadi hai aapko?',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<VehicleDropdownOption>(
                  value: _selectedVehicle,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.event_seat),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  hint: const Text('Select vehicle (seats as per RTO)'),
                  isExpanded: true,
                  itemHeight: 72,
                  // Web / some themes give selected row only ~24px height — single line avoids overflow.
                  selectedItemBuilder: (context) {
                    return VehicleCatalog.allVehicleOptionsForDropdown
                        .map((opt) {
                      return Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          '${opt.displayName} · ${opt.capacitySubtitle}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 13),
                        ),
                      );
                    }).toList();
                  },
                  items: VehicleCatalog.allVehicleOptionsForDropdown.map((opt) {
                    return DropdownMenuItem<VehicleDropdownOption>(
                      value: opt,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            opt.displayName,
                            maxLines: 2,
                            overflow: TextOverflow.visible,
                            style: const TextStyle(fontSize: 14),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            opt.capacitySubtitle,
                            style: TextStyle(
                                fontSize: 11, color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (opt) => setState(() => _selectedVehicle = opt),
                  validator: (v) => v == null ? 'Select your vehicle' : null,
                ),
                if (_selectedVehicle != null) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(Icons.info_outline,
                          size: 18, color: Colors.green[700]),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${_selectedVehicle!.capacity} seats — same layout will show for passengers when they book.',
                          style:
                              TextStyle(fontSize: 13, color: Colors.grey[700]),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2),
                          )
                        : const Text('Submit for Verification',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ),
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
          border:
              Border.all(color: selected ? Colors.green : Colors.grey[300]!),
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
