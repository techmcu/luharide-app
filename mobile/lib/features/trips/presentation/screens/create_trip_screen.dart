import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/feedback/app_feedback.dart';
import '../../../../providers/app_language_provider.dart';
import '../../../../services/driver_verification_service.dart';
import '../../../../services/trip_service.dart';

class CreateTripScreen extends StatefulWidget {
  const CreateTripScreen({super.key});

  @override
  State<CreateTripScreen> createState() => _CreateTripScreenState();
}

class _CreateTripScreenState extends State<CreateTripScreen> {
  final _formKey = GlobalKey<FormState>();
  final _tripService = TripService();
  final _verificationService = DriverVerificationService();

  final _fromController = TextEditingController();
  final _toController = TextEditingController();
  final _vehicleNumberController = TextEditingController();
  final _fareController = TextEditingController();
  final _luggageController = TextEditingController();

  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = TimeOfDay.now();

  List<String> _fromSuggestions = [];
  List<String> _toSuggestions = [];
  bool _isLoading = false;
  bool _requireApproval = true;
  /// When driver is approved, vehicle number comes from KYC (same as verification).
  bool _vehicleLockedFromVerification = false;
  bool _loadingVerifiedVehicle = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadVerifiedVehicleNumber());
  }

  Future<void> _loadVerifiedVehicleNumber() async {
    final r = await _verificationService.getMyStatus();
    if (!mounted) return;
    final ok = r['success'] == true;
    final status = (r['status'] ?? '').toString();
    final req = r['request'];
    String reg = '';
    if (ok && status == 'approved' && req is Map) {
      final v = req['vehicle_registration'];
      reg = v != null ? v.toString().trim() : '';
    }
    setState(() {
      _loadingVerifiedVehicle = false;
      if (reg.isNotEmpty) {
        _vehicleNumberController.text = reg;
        _vehicleLockedFromVerification = true;
      }
    });
  }

  @override
  void dispose() {
    _fromController.dispose();
    _toController.dispose();
    _vehicleNumberController.dispose();
    _fareController.dispose();
    _luggageController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 90)),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _selectTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );
    if (picked != null && picked != _selectedTime) {
      setState(() {
        _selectedTime = picked;
      });
    }
  }

  Future<void> _loadFromSuggestions(String query) async {
    if (query.length < 2) {
      setState(() => _fromSuggestions = []);
      return;
    }
    final suggestions = await _tripService.getLocationSuggestions(query);
    setState(() => _fromSuggestions = suggestions);
  }

  Future<void> _loadToSuggestions(String query) async {
    if (query.length < 2) {
      setState(() => _toSuggestions = []);
      return;
    }
    final suggestions = await _tripService.getLocationSuggestions(query);
    setState(() => _toSuggestions = suggestions);
  }

  Future<void> _createTrip() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isLoading = true);

    final fromLocation = _fromController.text.trim();
    final toLocation = _toController.text.trim();
    if (fromLocation.length < 2 || toLocation.length < 2) {
      setState(() => _isLoading = false);
      if (mounted) {
        AppFeedback.show(
          context,
          'From and To locations must be at least 2 characters',
          kind: AppFeedbackKind.warning,
        );
      }
      return;
    }

    final departureTime = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _selectedTime.hour,
      _selectedTime.minute,
    );

    // For now we treat trips as token-based, not exact seat layout.
    // Keep a fixed small capacity to prevent over-booking.
    const int totalSeats = 10;
    final result = await _tripService.createTrip(
      fromLocation: fromLocation,
      toLocation: toLocation,
      departureTime: departureTime,
      farePerSeat: double.parse(_fareController.text),
      vehicleNumber: _vehicleNumberController.text.trim(),
      totalSeats: totalSeats,
      requireApproval: _requireApproval,
      luggageAllowancePerPassenger: _luggageController.text.trim().isEmpty
          ? null
          : _luggageController.text.trim(),
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (result['success']) {
      AppFeedback.show(
        context,
        result['message'].toString(),
        kind: AppFeedbackKind.success,
      );
      Navigator.pop(context, true); // Return true to indicate success
    } else {
      final msg = result['message'] ?? 'Failed to create trip';
      AppFeedback.show(
        context,
        msg.toString(),
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
        title: const Text('Create New Trip'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // From Location
            Autocomplete<String>(
              optionsBuilder: (TextEditingValue textEditingValue) {
                if (textEditingValue.text.isEmpty) {
                  return const Iterable<String>.empty();
                }
                _loadFromSuggestions(textEditingValue.text);
                return _fromSuggestions;
              },
              onSelected: (String selection) {
                _fromController.text = selection;
              },
              fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                _fromController.text = controller.text;
                return TextFormField(
                  controller: controller,
                  focusNode: focusNode,
                  decoration: InputDecoration(
                    labelText: 'From Location',
                    prefixIcon: const Icon(Icons.location_on, color: Colors.green),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  validator: (value) {
                    final v = value?.trim() ?? '';
                    if (v.isEmpty) return 'Please enter starting location';
                    if (v.length < 2) return 'Enter at least 2 characters';
                    return null;
                  },
                );
              },
            ),
            const SizedBox(height: 16),

            // To Location
            Autocomplete<String>(
              optionsBuilder: (TextEditingValue textEditingValue) {
                if (textEditingValue.text.isEmpty) {
                  return const Iterable<String>.empty();
                }
                _loadToSuggestions(textEditingValue.text);
                return _toSuggestions;
              },
              onSelected: (String selection) {
                _toController.text = selection;
              },
              fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                _toController.text = controller.text;
                return TextFormField(
                  controller: controller,
                  focusNode: focusNode,
                  decoration: InputDecoration(
                    labelText: 'To Location',
                    prefixIcon: const Icon(Icons.location_on, color: Colors.red),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  validator: (value) {
                    final v = value?.trim() ?? '';
                    if (v.isEmpty) return 'Please enter destination';
                    if (v.length < 2) return 'Enter at least 2 characters';
                    return null;
                  },
                );
              },
            ),
            const SizedBox(height: 16),

            // Date & Time
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: _selectDate,
                    child: InputDecorator(
                      decoration: InputDecoration(
                        labelText: 'Date',
                        prefixIcon: const Icon(Icons.calendar_today),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        DateFormat('dd MMM yyyy').format(_selectedDate),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: InkWell(
                    onTap: _selectTime,
                    child: InputDecorator(
                      decoration: InputDecoration(
                        labelText: 'Time',
                        prefixIcon: const Icon(Icons.access_time),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        _selectedTime.format(context),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Vehicle Number (prefilled from KYC when approved — backend also uses verified RC)
            if (_loadingVerifiedVehicle)
              const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: LinearProgressIndicator(minHeight: 3),
              ),
            TextFormField(
              controller: _vehicleNumberController,
              readOnly: _vehicleLockedFromVerification,
              decoration: InputDecoration(
                labelText: 'Vehicle Number',
                prefixIcon: const Icon(Icons.directions_car),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                hintText: 'e.g., UK 07 AB 1234',
                helperText: _vehicleLockedFromVerification ? loc.t('kyc.trip.vehicle_locked_hint') : null,
                filled: _vehicleLockedFromVerification,
                fillColor: _vehicleLockedFromVerification
                    ? Colors.grey.shade100
                    : null,
              ),
              textCapitalization: TextCapitalization.characters,
              validator: (value) {
                if (_vehicleLockedFromVerification) return null;
                if (value == null || value.isEmpty) {
                  return loc.t('kyc.trip.vehicle_required');
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            const SizedBox(height: 16),

            // Fare per seat
            TextFormField(
              controller: _fareController,
              decoration: InputDecoration(
                labelText: 'Fare per Seat',
                prefixIcon: const Icon(Icons.currency_rupee),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              keyboardType: TextInputType.number,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Enter fare';
                }
                if (double.tryParse(value) == null) {
                  return 'Invalid fare';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _luggageController,
              decoration: InputDecoration(
                labelText: 'Luggage per passenger (optional)',
                hintText: 'e.g. 1 small bag — shown to passengers for this ride only',
                prefixIcon: const Icon(Icons.luggage_outlined),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              maxLines: 2,
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: 20),

            // Require Approval Toggle - Chat only after approval
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green[200]!),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Require approval',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _requireApproval
                              ? 'You approve each booking. Chat only after approval.'
                              : 'Auto-approve: seats book instantly.',
                          style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: _requireApproval,
                    onChanged: (v) => setState(() => _requireApproval = v),
                    activeColor: Colors.green,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Create Button
            SizedBox(
              height: 56,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _createTrip,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        'Create Trip',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
