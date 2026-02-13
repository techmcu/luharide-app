import 'package:flutter/material.dart';
import '../../services/driver_verification_service.dart';
import '../../models/vehicle_catalog.dart';
import '../../models/seat_layout.dart';

/// Form to submit driver verification documents
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
  final _vehicleTypeController = TextEditingController();
  final _vehicleModelController = TextEditingController();
  final _capacityController = TextEditingController(text: '7');
  bool _isLoading = false;
  VehicleBrandConfig? _selectedBrand;
  VehicleModelConfig? _selectedModel;

  @override
  void dispose() {
    _licenseController.dispose();
    _vehicleRegController.dispose();
    _vehicleTypeController.dispose();
    _vehicleModelController.dispose();
    _capacityController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final result = await _service.submitVerification(
      drivingLicenseNumber: _licenseController.text.trim(),
      vehicleRegistration: _vehicleRegController.text.trim(),
      vehicleType: _vehicleTypeController.text.trim(),
      vehicleModel: _vehicleModelController.text.trim(),
      vehicleCapacity: int.tryParse(_capacityController.text) ?? 7,
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
              const SizedBox(height: 16),
              // Brand dropdown
              DropdownButtonFormField<VehicleBrandConfig>(
                value: _selectedBrand,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: 'Vehicle Brand',
                  hintText: 'Select brand (e.g. Mahindra, Maruti)',
                  prefixIcon: const Icon(Icons.directions_car),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                items: VehicleCatalog.brands
                    .map(
                      (b) => DropdownMenuItem(
                        value: b,
                        child: Text(b.name),
                      ),
                    )
                    .toList(),
                onChanged: (brand) {
                  setState(() {
                    _selectedBrand = brand;
                    _selectedModel = null;
                    _vehicleTypeController.text = brand?.name ?? '';
                    _vehicleModelController.clear();
                    _capacityController.text = '';
                  });
                },
                validator: (v) => v == null ? 'Select brand' : null,
              ),
              const SizedBox(height: 16),
              // Model dropdown (depends on brand)
              DropdownButtonFormField<VehicleModelConfig>(
                value: _selectedModel,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: 'Vehicle Model',
                  hintText: 'Select exact model',
                  prefixIcon: const Icon(Icons.directions_car),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                items: (_selectedBrand?.models ?? [])
                    .map(
                      (m) => DropdownMenuItem(
                        value: m,
                        child: Text(
                          m.name,
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (model) {
                  setState(() {
                    _selectedModel = model;
                    if (model != null) {
                      _vehicleModelController.text = model.name;
                      _vehicleTypeController.text = model.bodyType;
                      _capacityController.text = model.capacity.toString();
                    }
                  });
                },
                validator: (v) => v == null ? 'Select model' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _capacityController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Seat Capacity',
                  hintText: 'Auto from model',
                  prefixIcon: const Icon(Icons.event_seat),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                readOnly: true,
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Required';
                  final n = int.tryParse(v);
                  if (n == null || n < 1 || n > 15) return 'Enter 1-15';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              if (_selectedModel != null) ...[
                Text(
                  'Seat layout (top view)',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[800],
                  ),
                ),
                const SizedBox(height: 8),
                Card(
                  elevation: 1,
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: SeatLayoutView(layout: _selectedModel!.layout),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'This is an approximate seating layout to help with bookings. '
                  'Actual vehicle configuration may vary slightly.',
                  style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                ),
                const SizedBox(height: 16),
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
