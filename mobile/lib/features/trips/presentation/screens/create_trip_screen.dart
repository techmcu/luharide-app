import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/feedback/app_feedback.dart';
import '../../../../providers/app_language_provider.dart';
import '../../../../services/driver_verification_service.dart';
import '../../../../core/constants/input_limits.dart';
import '../../../../services/trip_service.dart';
import '../../../../models/picked_location.dart';
import '../../../../widgets/location_picker_screen.dart';

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
  double? _estimatedDurationHours; // auto-calculated from route distance
  double? _estimatedDistanceKm;
  bool _estimating = false;

  // Coordinates of the selected place (null until picked from the picker).
  double? _fromLat, _fromLng, _toLat, _toLng;
  bool _isLoading = false;
  bool _requireApproval = false;
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

  /// Open the full-page location picker and capture name + coordinates.
  Future<void> _pickLocation({
    required TextEditingController controller,
    required bool isFrom,
    required String label,
  }) async {
    // Destination suggestions bias to the chosen origin (not the user's GPS).
    final result = await Navigator.push<PickedLocation>(
      context,
      MaterialPageRoute(
        builder: (_) => LocationPickerScreen(
          title: label,
          initialValue: controller.text,
          tripService: _tripService,
          biasLat: isFrom ? null : _fromLat,
          biasLng: isFrom ? null : _fromLng,
        ),
      ),
    );
    if (result == null) return;
    controller.text = result.name;

    // Ensure we have coordinates. If the user picked a name-only entry (recent/
    // popular), resolve them by looking the name up so distance/time still works.
    double? lat = result.lat, lng = result.lng;
    if (lat == null || lng == null) {
      final matches = await _tripService.getLocationPlaces(result.name);
      final withCoords = matches.where((p) => p.hasCoords).toList();
      if (withCoords.isNotEmpty) {
        lat = withCoords.first.lat;
        lng = withCoords.first.lng;
      }
    }
    if (isFrom) {
      _fromLat = lat;
      _fromLng = lng;
    } else {
      _toLat = lat;
      _toLng = lng;
    }
    setState(() {});
    _recalcEstimate();
  }

  Widget _buildPickerField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required Color iconColor,
    required bool isFrom,
  }) {
    return GestureDetector(
      onTap: () => _pickLocation(controller: controller, isFrom: isFrom, label: label),
      child: AbsorbPointer(
        child: TextFormField(
          controller: controller,
          readOnly: true,
          decoration: InputDecoration(
            labelText: label,
            hintText: 'Tap to search',
            prefixIcon: Icon(icon, color: iconColor),
            suffixIcon: const Icon(Icons.arrow_drop_down_rounded),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
          validator: (value) {
            final v = value?.trim() ?? '';
            if (v.isEmpty) return 'Please select $label';
            if (v.length < 2) return 'Enter at least 2 characters';
            return null;
          },
        ),
      ),
    );
  }

  /// Auto-calculate distance + travel time once both endpoints have coordinates.
  /// No manual time entry — the driver just picks From & To.
  Future<void> _recalcEstimate() async {
    if (_fromLat == null || _fromLng == null || _toLat == null || _toLng == null) {
      return;
    }
    setState(() => _estimating = true);
    final est = await _tripService.estimateRoute(
      fromLat: _fromLat!, fromLng: _fromLng!, toLat: _toLat!, toLng: _toLng!,
    );
    if (!mounted) return;
    setState(() {
      _estimating = false;
      if (est != null && est['durationMin'] != null) {
        _estimatedDistanceKm = (est['distanceKm'] as num?)?.toDouble();
        final hrs = (est['durationMin'] as int) / 60.0;
        // Backend accepts 1–12 h; round to 1 decimal.
        _estimatedDurationHours = double.parse(hrs.clamp(1.0, 12.0).toStringAsFixed(1));
      }
    });
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

    // Last-chance auto-calc (e.g. estimate hadn't returned yet), then proceed
    // with a safe default so ride creation is never blocked on the estimate.
    if (_estimatedDurationHours == null) {
      await _recalcEstimate();
    }
    final double durationHours = _estimatedDurationHours ?? 2.0;

    final departureTime = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _selectedTime.hour,
      _selectedTime.minute,
    );

    // NOTE: total seats are NOT set here — the backend uses the driver's VERIFIED
    // vehicle capacity (so seat count always matches the real vehicle). We don't
    // send a misleading hardcoded value.
    final result = await _tripService.createTrip(
      fromLocation: fromLocation,
      toLocation: toLocation,
      departureTime: departureTime,
      farePerSeat: double.parse(_fareController.text),
      vehicleNumber: _vehicleNumberController.text.trim(),
      estimatedDurationHours: durationHours,
      requireApproval: _requireApproval,
      luggageAllowancePerPassenger: _luggageController.text.trim().isEmpty
          ? null
          : _luggageController.text.trim(),
      fromLat: _fromLat, fromLng: _fromLng,
      toLat: _toLat, toLng: _toLng,
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (result['success']) {
      final loc = AppLocalizations.of(context);
      AppFeedback.show(
        context,
        loc.t('driver.create_trip.success'),
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
      body: SafeArea(
        child: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // From Location — opens a full-page picker (search, current location,
            // names with district/state context, coordinates for accurate matching).
            _buildPickerField(
              controller: _fromController,
              label: 'From Location',
              icon: Icons.trip_origin,
              iconColor: Colors.green,
              isFrom: true,
            ),
            const SizedBox(height: 16),

            // To Location
            _buildPickerField(
              controller: _toController,
              label: 'To Location',
              icon: Icons.location_on,
              iconColor: Colors.red,
              isFrom: false,
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

            // Estimated distance & travel time — AUTO-calculated from the route.
            // No manual entry: the driver just picks From & To from suggestions.
            _EstimateCard(
              estimating: _estimating,
              distanceKm: _estimatedDistanceKm,
              durationHours: _estimatedDurationHours,
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
              maxLength: InputLimits.vehicleNumber,
              decoration: InputDecoration(
                counterText: '',
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

            // Fare per seat
            TextFormField(
              controller: _fareController,
              maxLength: InputLimits.fare,
              decoration: InputDecoration(
                counterText: '',
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
              maxLength: InputLimits.luggage,
              decoration: InputDecoration(
                counterText: '',
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
      ),
    );
  }
}

/// Auto-calculated route estimate card (distance + travel time). Read-only —
/// the driver never types travel time; it comes from the route distance.
class _EstimateCard extends StatelessWidget {
  const _EstimateCard({
    required this.estimating,
    required this.distanceKm,
    required this.durationHours,
  });
  final bool estimating;
  final double? distanceKm;
  final double? durationHours;

  String get _durationLabel {
    final h = durationHours;
    if (h == null) return '—';
    final hours = h.floor();
    final mins = ((h - hours) * 60).round();
    if (hours <= 0) return '${mins}m';
    return mins == 0 ? '${hours}h' : '${hours}h ${mins}m';
  }

  @override
  Widget build(BuildContext context) {
    final hasData = distanceKm != null && durationHours != null;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFBBF7D0)),
      ),
      child: Row(
        children: [
          const Icon(Icons.route_rounded, color: Colors.green, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: estimating
                ? const Text('Calculating distance & time…',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600))
                : hasData
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Estimated travel',
                              style: TextStyle(fontSize: 12, color: Colors.black54)),
                          const SizedBox(height: 2),
                          Text(
                            '≈ ${distanceKm!.toStringAsFixed(distanceKm! < 10 ? 1 : 0)} km  ·  $_durationLabel',
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF166534)),
                          ),
                        ],
                      )
                    : const Text(
                        'Pick From & To to auto-calculate distance and time',
                        style: TextStyle(fontSize: 13.5, color: Colors.black54),
                      ),
          ),
          if (estimating)
            const SizedBox(
                width: 18, height: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.green)),
        ],
      ),
    );
  }
}
