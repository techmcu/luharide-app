import 'package:flutter/material.dart';
import '../../models/vehicle_catalog.dart';
import '../../services/driver_verification_service.dart';

/// Form to submit driver verification documents.
/// Vehicle is selected from dropdown (fixed layout + seat count); no manual seat entry.
class DriverVerificationFormScreen extends StatefulWidget {
  const DriverVerificationFormScreen({super.key});

  @override
  State<DriverVerificationFormScreen> createState() => _DriverVerificationFormScreenState();
}

class _DriverVerificationFormScreenState extends State<DriverVerificationFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _service = DriverVerificationService();
  final _licenseController = TextEditingController();
  final _vehicleRegController = TextEditingController();
  bool _isLoading = false;
  VehicleDropdownOption? _selectedVehicle;

  @override
  void dispose() {
    _licenseController.dispose();
    _vehicleRegController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedVehicle == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select your vehicle'), backgroundColor: Colors.orange),
      );
      return;
    }

    setState(() => _isLoading = true);

    final v = _selectedVehicle!;
    final vehicleType = v.displayName.contains(' ')
        ? v.displayName.split(' ').first
        : v.displayName;
    final vehicleModel = v.displayName;

    final result = await _service.submitVerification(
      drivingLicenseNumber: _licenseController.text.trim(),
      vehicleRegistration: _vehicleRegController.text.trim(),
      vehicleType: vehicleType,
      vehicleModel: vehicleModel,
      vehicleModelId: v.id,
      vehicleCapacity: v.capacity,
    );

    setState(() => _isLoading = false);

    if (mounted) {
      if (result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['message'] ?? 'Submitted! Admin will review.'), backgroundColor: Colors.green),
        );
        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['message'] ?? 'Failed'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Become a Driver'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
                          'Submit your documents for verification. Admin will review within 24-48 hours.',
                          style: TextStyle(fontSize: 14, color: Colors.blue[900]),
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
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _vehicleRegController,
                decoration: InputDecoration(
                  labelText: 'Vehicle Registration (RC)',
                  hintText: 'e.g. UK07AB1234',
                  prefixIcon: const Icon(Icons.directions_car),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
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
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                ),
                hint: const Text('Select vehicle (seats as per RTO)'),
                isExpanded: true,
                items: VehicleCatalog.allVehicleOptionsForDropdown.map((opt) {
                  return DropdownMenuItem<VehicleDropdownOption>(
                    value: opt,
                    child: Text(opt.displayName, overflow: TextOverflow.ellipsis),
                  );
                }).toList(),
                onChanged: (opt) => setState(() => _selectedVehicle = opt),
                validator: (v) => v == null ? 'Select your vehicle' : null,
              ),
              if (_selectedVehicle != null) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(Icons.info_outline, size: 18, color: Colors.green[700]),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${_selectedVehicle!.capacity} seats — same layout will show for passengers when they book.',
                        style: TextStyle(fontSize: 13, color: Colors.grey[700]),
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
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Text('Submit for Verification', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
