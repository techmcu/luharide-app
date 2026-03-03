import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/trip_service.dart';

class CreateTripScreen extends StatefulWidget {
  const CreateTripScreen({super.key});

  @override
  State<CreateTripScreen> createState() => _CreateTripScreenState();
}

class _CreateTripScreenState extends State<CreateTripScreen> {
  final _formKey = GlobalKey<FormState>();
  final _tripService = TripService();

  final _fromController = TextEditingController();
  final _toController = TextEditingController();
  final _vehicleNumberController = TextEditingController();
  final _fareController = TextEditingController();

  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = TimeOfDay.now();

  List<String> _fromSuggestions = [];
  List<String> _toSuggestions = [];
  bool _isLoading = false;
  bool _requireApproval = true;

  @override
  void dispose() {
    _fromController.dispose();
    _toController.dispose();
    _vehicleNumberController.dispose();
    _fareController.dispose();
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('From and To locations must be at least 2 characters')),
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
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (result['success']) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message']),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context, true); // Return true to indicate success
    } else {
      final msg = result['message'] ?? 'Failed to create trip';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
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

            // Vehicle Number
            TextFormField(
              controller: _vehicleNumberController,
              decoration: InputDecoration(
                labelText: 'Vehicle Number',
                prefixIcon: const Icon(Icons.directions_car),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                hintText: 'e.g., UK 07 AB 1234',
              ),
              textCapitalization: TextCapitalization.characters,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter vehicle number';
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
