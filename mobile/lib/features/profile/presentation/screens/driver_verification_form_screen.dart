import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../../models/vehicle_catalog.dart';
import '../../../../services/driver_verification_service.dart';
import '../../../../services/upload_service.dart';
import '../../../../services/union_service.dart';
import '../../../../providers/auth_provider.dart';
import '../../../../core/role_exclusivity.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/utils/kyc_image_picker.dart';
import '../../../../core/feedback/app_feedback.dart';
import '../../../../providers/app_language_provider.dart';

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
  final _vehicleRegController = TextEditingController();
  final _contactPhoneController = TextEditingController();
  final _contactEmailController = TextEditingController();
  bool _isLoading = false;
  VehicleDropdownOption? _selectedVehicle;
  bool _isOtherVehicle = false;
  OtherVehicleBodyType? _otherBodyType;
  final _otherSeatCountController = TextEditingController(text: '5');
  XFile? _aadhaarFrontFile;
  XFile? _aadhaarBackFile;
  XFile? _licenseFrontFile;
  XFile? _licenseBackFile;
  bool _checkingUnionPath = true;
  bool _unionPathBlocksIndependent = false;
  bool _verificationAlreadyPending = false;
  bool _recheckingPending = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final auth = context.read<AuthProvider>();
      // Note: Phone number intentionally left empty - user must enter explicitly
      // to prevent accidental submission with wrong/old number
      _contactEmailController.text = (auth.user?.email ?? '').trim();
      // Sync with server so admin reject → user sees form again (not stale "pending").
      await auth.refreshUser();
      if (!mounted) return;
      final dv = auth.user?.driverVerificationStatus ?? 'none';
      if (dv == 'pending') {
        setState(() {
          _verificationAlreadyPending = true;
          _checkingUnionPath = false;
        });
        return;
      }
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

  /// One server round-trip after admin reject — no polling.
  Future<void> _recheckVerificationStatus() async {
    if (_recheckingPending) return;
    setState(() => _recheckingPending = true);
    final auth = context.read<AuthProvider>();
    await auth.refreshUser();
    if (!mounted) return;
    final dv = auth.user?.driverVerificationStatus ?? 'none';
    if (dv == 'pending') {
      setState(() {
        _recheckingPending = false;
        _verificationAlreadyPending = true;
      });
      return;
    }
    setState(() {
      _verificationAlreadyPending = false;
      _checkingUnionPath = true;
      _recheckingPending = false;
    });
    await _checkUnionExclusivity();
  }

  @override
  void dispose() {
    _vehicleRegController.dispose();
    _contactPhoneController.dispose();
    _contactEmailController.dispose();
    _otherSeatCountController.dispose();
    super.dispose();
  }

  Future<void> _pickDocument(void Function(XFile) setter) async {
    final img = await pickKycGalleryPhoto();
    if (img == null) return;
    setter(img);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final loc = AppLocalizations.of(context);
    if (_isOtherVehicle) {
      if (_otherBodyType == null) {
        AppFeedback.show(
          context,
          'Please select vehicle body type',
          kind: AppFeedbackKind.warning,
        );
        return;
      }
    } else if (_selectedVehicle == null) {
      AppFeedback.show(
        context,
        loc.t('kyc.driver.snack.select_vehicle'),
        kind: AppFeedbackKind.warning,
      );
      return;
    }

    if (_aadhaarFrontFile == null ||
        _aadhaarBackFile == null ||
        _licenseFrontFile == null ||
        _licenseBackFile == null) {
      AppFeedback.show(
        context,
        loc.t('kyc.driver.snack.missing_docs'),
        kind: AppFeedbackKind.warning,
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
        AppFeedback.show(
          context,
          e.toString().replaceAll('Exception: ', ''),
          kind: AppFeedbackKind.error,
        );
      }
      return;
    }

    final String vehicleType;
    final String vehicleModel;
    final String vehicleModelId;
    final int vehicleCapacity;

    if (_isOtherVehicle) {
      final bt = _otherBodyType!;
      final seatCount = int.tryParse(_otherSeatCountController.text.trim()) ?? 5;
      final clamped = seatCount.clamp(2, 32);
      vehicleType = bt.label;
      vehicleModel = 'Other ${bt.label} ($clamped seater)';
      vehicleModelId = VehicleCatalog.otherVehicleId(bt, clamped);
      vehicleCapacity = clamped;
    } else {
      final v = _selectedVehicle!;
      vehicleType = v.displayName.contains(' ')
          ? v.displayName.split(' ').first
          : v.displayName;
      vehicleModel = v.displayName;
      vehicleModelId = v.id;
      vehicleCapacity = v.capacity;
    }

    final result = await _service.submitVerification(
      drivingLicenseUrl: licenseFrontUrl,
      vehicleRegistration: _vehicleRegController.text.trim(),
      vehicleType: vehicleType,
      vehicleModel: vehicleModel,
      vehicleModelId: vehicleModelId,
      vehicleCapacity: vehicleCapacity,
      contactPhone: _contactPhoneController.text.replaceAll(' ', '').trim(),
      contactEmail: _contactEmailController.text.trim(),
      permitDocumentUrl: null,
      insuranceDocumentUrl: null,
      aadhaarFrontUrl: aadhaarFrontUrl,
      aadhaarBackUrl: aadhaarBackUrl,
      drivingLicenseFrontUrl: licenseFrontUrl,
      drivingLicenseBackUrl: licenseBackUrl,
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (result['success'] == true) {
      AppFeedback.show(
        context,
        result['message']?.toString() ??
            AppLocalizations.of(context).t('kyc.driver.snack.submitted'),
        kind: AppFeedbackKind.success,
      );
      Navigator.pop(context, true);
    } else {
      AppFeedback.show(
        context,
        result['message'] ?? 'Failed',
        kind: AppFeedbackKind.error,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    context.watch<AppLanguageProvider>();
    final loc = AppLocalizations.of(context);
    final auth = context.watch<AuthProvider>();
    final dv = auth.user?.driverVerificationStatus ?? 'none';
    final reuploadAllowed = auth.user?.driverKycReuploadAllowed == true;
    if (_checkingUnionPath) {
      return Scaffold(
        appBar: AppBar(
          title: Text(loc.t('kyc.driver.title')),
          backgroundColor: Colors.green,
          foregroundColor: Colors.white,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (_verificationAlreadyPending) {
      return Scaffold(
        appBar: AppBar(
          title: Text(loc.t('kyc.driver.title')),
          backgroundColor: Colors.green,
          foregroundColor: Colors.white,
        ),
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(Icons.hourglass_empty, size: 56, color: Colors.green[700]),
              const SizedBox(height: 16),
              Text(
                loc.t('kyc.driver.already_pending_title'),
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              Text(
                loc.t('kyc.driver.already_pending_body'),
                style: TextStyle(fontSize: 14, color: Colors.grey[800], height: 1.4),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: _recheckingPending ? null : _recheckVerificationStatus,
                icon: _recheckingPending
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh),
                label: Text(loc.t('kyc.driver.check_status')),
              ),
              const Spacer(),
              OutlinedButton(
                onPressed: () => Navigator.pop(context),
                child: Text(loc.t('kyc.driver.back')),
              ),
            ],
          ),
        ),
      );
    }
    if (_unionPathBlocksIndependent) {
      return Scaffold(
        appBar: AppBar(
          title: Text(loc.t('kyc.driver.title')),
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

    // Blue tick (approved) drivers must not see re-upload unless admin explicitly opens it.
    if (dv == 'approved' && !reuploadAllowed) {
      return Scaffold(
        appBar: AppBar(
          title: Text(loc.t('kyc.driver.title')),
          backgroundColor: Colors.green,
          foregroundColor: Colors.white,
        ),
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(Icons.verified_rounded, size: 56, color: Colors.green[700]),
              const SizedBox(height: 16),
              Text(
                loc.t('kyc.driver.verified_title'),
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              Text(
                loc.t('kyc.driver.verified_body'),
                style: TextStyle(fontSize: 14, color: Colors.grey[800], height: 1.4),
              ),
              const Spacer(),
              OutlinedButton(
                onPressed: () => Navigator.pop(context),
                child: Text(loc.t('app.close')),
              ),
            ],
          ),
        ),
      );
    }

    // If admin marked re-verification required but hasn't opened the upload window.
    if (dv == 'needs_reverify' && !reuploadAllowed) {
      return Scaffold(
        appBar: AppBar(
          title: Text(loc.t('kyc.driver.title')),
          backgroundColor: Colors.green,
          foregroundColor: Colors.white,
        ),
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(Icons.error_outline, size: 56, color: Colors.orange[800]),
              const SizedBox(height: 16),
              Text(
                loc.t('kyc.driver.reverify_required_title'),
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              Text(
                loc.t('kyc.driver.reverify_required_body'),
                style: TextStyle(fontSize: 14, color: Colors.grey[800], height: 1.4),
              ),
              const Spacer(),
              OutlinedButton(
                onPressed: () => Navigator.pop(context),
                child: Text(loc.t('app.close')),
              ),
            ],
          ),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(loc.t('kyc.driver.title')),
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
                    labelText: loc.t('kyc.driver.contact_phone'),
                    hintText: 'Enter 10-digit mobile number',
                    prefixIcon: const Icon(Icons.phone_outlined),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  validator: (v) {
                    final s = (v ?? '').replaceAll(' ', '').trim();
                    if (s.isEmpty) return 'Mobile number is required';
                    if (!RegExp(r'^\d{10}$').hasMatch(s)) {
                      return 'Enter valid 10-digit mobile number';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _contactEmailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: loc.t('kyc.driver.contact_email'),
                    prefixIcon: const Icon(Icons.email_outlined),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  validator: (v) {
                    final s = (v ?? '').trim();
                    if (s.isEmpty) return loc.t('kyc.driver.val.email_required');
                    if (!s.contains('@') || !s.contains('.')) {
                      return loc.t('kyc.driver.val.email_invalid');
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
                            loc.t('kyc.driver.info_card'),
                            style: TextStyle(
                                fontSize: 14, color: Colors.blue[900]),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  loc.t('kyc.driver.upload_heading'),
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Text(
                  loc.t('kyc.driver.upload_note'),
                  style: TextStyle(fontSize: 12, color: Colors.grey[800], height: 1.35),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _DocChip(
                      label: loc.t('kyc.driver.chip.aadhaar_front'),
                      selected: _aadhaarFrontFile != null,
                      onTap: _isLoading
                          ? null
                          : () => _pickDocument(
                              (f) => setState(() => _aadhaarFrontFile = f)),
                    ),
                    _DocChip(
                      label: loc.t('kyc.driver.chip.aadhaar_back'),
                      selected: _aadhaarBackFile != null,
                      onTap: _isLoading
                          ? null
                          : () => _pickDocument(
                              (f) => setState(() => _aadhaarBackFile = f)),
                    ),
                    _DocChip(
                      label: loc.t('kyc.driver.chip.dl_front'),
                      selected: _licenseFrontFile != null,
                      onTap: _isLoading
                          ? null
                          : () => _pickDocument(
                              (f) => setState(() => _licenseFrontFile = f)),
                    ),
                    _DocChip(
                      label: loc.t('kyc.driver.chip.dl_back'),
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
                    labelText: loc.t('kyc.driver.vehicle_reg'),
                    hintText: loc.t('kyc.driver.vehicle_reg.hint'),
                    prefixIcon: const Icon(Icons.directions_car),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  textCapitalization: TextCapitalization.characters,
                  validator: (v) =>
                      (v == null || v.trim().isEmpty)
                          ? loc.t('kyc.driver.vehicle_reg.required')
                          : null,
                ),
                const SizedBox(height: 20),
                Text(
                  loc.t('kyc.driver.vehicle_type.title'),
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<VehicleDropdownOption>(
                  value: _isOtherVehicle ? VehicleCatalog.otherVehicleSentinel : _selectedVehicle,
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
                  selectedItemBuilder: (context) {
                    return VehicleCatalog.allVehicleOptionsWithOther
                        .map((opt) {
                      final label = opt.id == VehicleCatalog.otherVehicleSentinelId
                          ? 'Other Vehicle (not in list)'
                          : '${opt.displayName} · ${opt.capacitySubtitle}';
                      return Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 13),
                        ),
                      );
                    }).toList();
                  },
                  items: VehicleCatalog.allVehicleOptionsWithOther.map((opt) {
                    final isOther = opt.id == VehicleCatalog.otherVehicleSentinelId;
                    return DropdownMenuItem<VehicleDropdownOption>(
                      value: opt,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            isOther ? 'Other Vehicle (not in list)' : opt.displayName,
                            maxLines: 2,
                            overflow: TextOverflow.visible,
                            style: TextStyle(
                              fontSize: 14,
                              fontStyle: isOther ? FontStyle.italic : FontStyle.normal,
                              color: isOther ? Colors.grey[700] : null,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            isOther ? 'Select body type & seats manually' : opt.capacitySubtitle,
                            style: TextStyle(
                                fontSize: 11, color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (opt) {
                    if (opt == null) return;
                    setState(() {
                      if (opt.id == VehicleCatalog.otherVehicleSentinelId) {
                        _isOtherVehicle = true;
                        _selectedVehicle = null;
                      } else {
                        _isOtherVehicle = false;
                        _selectedVehicle = opt;
                        _otherBodyType = null;
                      }
                    });
                  },
                  validator: (v) {
                    if (_isOtherVehicle) return null;
                    return v == null ? loc.t('kyc.driver.vehicle_type.required') : null;
                  },
                ),
                if (_isOtherVehicle) ...[
                  const SizedBox(height: 16),
                  DropdownButtonFormField<OtherVehicleBodyType>(
                    value: _otherBodyType,
                    decoration: InputDecoration(
                      labelText: 'Vehicle body type',
                      prefixIcon: const Icon(Icons.directions_car_outlined),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    isExpanded: true,
                    items: OtherVehicleBodyType.values.map((bt) {
                      return DropdownMenuItem<OtherVehicleBodyType>(
                        value: bt,
                        child: Text(bt.label),
                      );
                    }).toList(),
                    onChanged: (bt) => setState(() => _otherBodyType = bt),
                    validator: (v) => v == null ? 'Select body type' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _otherSeatCountController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Total seats (including driver)',
                      hintText: '2 - 32',
                      prefixIcon: const Icon(Icons.airline_seat_recline_normal),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    validator: (v) {
                      final n = int.tryParse(v?.trim() ?? '');
                      if (n == null || n < 2 || n > 32) {
                        return 'Enter seat count between 2 and 32';
                      }
                      return null;
                    },
                  ),
                ],
                if (!_isOtherVehicle && _selectedVehicle != null) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(Icons.info_outline,
                          size: 18, color: Colors.green[700]),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          loc.tReplace('kyc.driver.seats_note',
                              {'n': '${_selectedVehicle!.capacity}'}),
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
                        : Text(loc.t('kyc.driver.submit'),
                            style: const TextStyle(
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
