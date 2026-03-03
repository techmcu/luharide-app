import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/trip_model.dart';
import '../../services/trip_service.dart';
import 'trip_details_screen.dart';

class SearchTripsScreen extends StatefulWidget {
  const SearchTripsScreen({super.key});

  @override
  State<SearchTripsScreen> createState() => _SearchTripsScreenState();
}

class _SearchTripsScreenState extends State<SearchTripsScreen> {
  final _tripService = TripService();
  
  final _fromController = TextEditingController();
  final _toController = TextEditingController();
  
  DateTime _selectedDate = DateTime.now();
  List<String> _fromSuggestions = [];
  List<String> _toSuggestions = [];
  
  List<TripModel> _searchResults = [];
  List<dynamic> _unionRides = [];
  bool _isSearching = false;
  bool _hasSearched = false;
  List<dynamic> _recentRoutes = [];

  @override
  void dispose() {
    _fromController.dispose();
    _toController.dispose();
    super.dispose();
  }
  
  @override
  void initState() {
    super.initState();
    _loadRecentRoutes();
  }

  Future<void> _loadRecentRoutes() async {
    final result = await _tripService.getRecentRoutes();
    if (mounted && result['success'] == true) {
      setState(() => _recentRoutes = List<dynamic>.from(result['routes'] ?? []));
    }
  }
  
  // Optional: Load today's trips automatically
  // Future<void> _loadTodayTrips() async {
  //   setState(() => _isSearching = true);
  //   final result = await _tripService.searchTrips(
  //     from: '',
  //     to: '',
  //     date: DateTime.now(),
  //   );
  //   setState(() {
  //     _isSearching = false;
  //     _hasSearched = true;
  //     _searchResults = result['trips'] ?? [];
  //   });
  // }

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

  Future<void> _searchTrips() async {
    if (_fromController.text.trim().isEmpty || _toController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter both locations'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isSearching = true;
      _hasSearched = true;
    });

    final result = await _tripService.searchTrips(
      from: _fromController.text.trim(),
      to: _toController.text.trim(),
      date: _selectedDate,
    );

    final raw = result['trips'] ?? [];
    final now = DateTime.now();
    final filtered = raw.where((t) {
      final d = t.departureTime;
      return d.year == _selectedDate.year && d.month == _selectedDate.month && d.day == _selectedDate.day && d.isAfter(now);
    }).toList();
    setState(() {
      _isSearching = false;
      _searchResults = filtered;
      _unionRides = List<dynamic>.from(result['unionRides'] ?? const []);
    });

    if (result['success'] == true) {
      _tripService.saveRecentRoute(
        from: _fromController.text.trim(),
        to: _toController.text.trim(),
      );
      _loadRecentRoutes();
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message'] ?? 'Search failed'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Search Trips'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Search Form
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                // Recent routes (quick fill)
                if (_recentRoutes.isNotEmpty) ...[
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Recent routes',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey[600]),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: _recentRoutes.map<Widget>((r) {
                      final from = r['from_location']?.toString() ?? '';
                      final to = r['to_location']?.toString() ?? '';
                      return ActionChip(
                        label: Text('$from → $to', style: const TextStyle(fontSize: 12)),
                        onPressed: () {
                          _fromController.text = from;
                          _toController.text = to;
                          setState(() {});
                        },
                        backgroundColor: Colors.blue[50],
                        side: BorderSide(color: Colors.blue[200]!),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                ],
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
                    return TextField(
                      controller: controller,
                      focusNode: focusNode,
                      decoration: InputDecoration(
                        labelText: 'From',
                        prefixIcon: const Icon(Icons.trip_origin, color: Colors.green),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: Colors.grey[50],
                      ),
                    );
                  },
                ),
                const SizedBox(height: 12),

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
                    return TextField(
                      controller: controller,
                      focusNode: focusNode,
                      decoration: InputDecoration(
                        labelText: 'To',
                        prefixIcon: const Icon(Icons.location_on, color: Colors.red),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: Colors.grey[50],
                      ),
                    );
                  },
                ),
                const SizedBox(height: 12),

                // Date
                InkWell(
                  onTap: _selectDate,
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: 'Travel Date',
                      prefixIcon: const Icon(Icons.calendar_today, color: Colors.blue),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: Colors.grey[50],
                    ),
                    child: Text(
                      DateFormat('dd MMM yyyy').format(_selectedDate),
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Search Button
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: _isSearching ? null : _searchTrips,
                    icon: _isSearching
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Icon(Icons.search),
                    label: Text(
                      _isSearching ? 'Searching...' : 'Search Trips',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Results
          Expanded(
            child: _buildResults(),
          ),
        ],
      ),
    );
  }

  Widget _buildResults() {
    if (!_hasSearched) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search, size: 80, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              'Search for trips',
              style: TextStyle(fontSize: 18, color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    if (_isSearching) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_searchResults.isEmpty && _unionRides.isEmpty) {
      return Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.directions_bus_outlined, size: 80, color: Colors.grey[300]),
              const SizedBox(height: 16),
              Text(
                'No rides found',
                style: TextStyle(fontSize: 18, color: Colors.grey[600]),
              ),
              const SizedBox(height: 8),
              Text(
                'Try different locations or dates',
                style: TextStyle(fontSize: 14, color: Colors.grey[500]),
              ),
            ],
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (_searchResults.isNotEmpty) ...[
          Text(
            'Individual driver rides',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 8),
          ..._searchResults.map(_buildTripCard),
          const SizedBox(height: 16),
        ],
        if (_unionRides.isNotEmpty) ...[
          Text(
            'Taxi union rides',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 8),
          ..._unionRides.map((ride) => _buildUnionRideCard(ride as Map<String, dynamic>)),
        ],
      ],
    );
  }

  Widget _buildTripCard(TripModel trip) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
              // Route
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.trip_origin, color: Colors.green, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                trip.fromLocation,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(Icons.location_on, color: Colors.red, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                trip.toLocation,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const Divider(height: 24),

              // Time and Seats
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.access_time, size: 18, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text(
                        trip.formattedDepartureTime,
                        style: const TextStyle(fontSize: 14),
                      ),
                      if (trip.formattedDuration != 'N/A') ...[
                        const SizedBox(width: 8),
                        Text(
                          '(${trip.formattedDuration})',
                          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                        ),
                      ],
                    ],
                  ),
                  Row(
                    children: [
                      const Icon(Icons.event_seat, size: 18, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text(
                        '${trip.availableSeats} seats',
                        style: TextStyle(
                          fontSize: 14,
                          color: trip.availableSeats > 0 ? Colors.green : Colors.red,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Fare and Driver
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.currency_rupee, size: 20, color: Colors.blue),
                      Text(
                        '${trip.farePerSeat.toStringAsFixed(0)}',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                      ),
                      const Text(' /seat'),
                    ],
                  ),
                  if (trip.driver != null)
                    Row(
                      children: [
                        const Icon(Icons.person, size: 18, color: Colors.grey),
                        const SizedBox(width: 4),
                        Text(
                          trip.driver!.name,
                          style: const TextStyle(fontSize: 14),
                        ),
                      ],
                    ),
                ],
              ),
              
              const SizedBox(height: 16),
              
              // Book Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    // Navigate to trip details for booking
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => TripDetailsScreen(tripId: trip.id, initialTrip: trip),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'View Details & Book',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
        ),
      ),
    );
  }

  Widget _buildUnionRideCard(Map<String, dynamic> ride) {
    final from = (ride['from_location'] ?? '').toString();
    final to = (ride['to_location'] ?? '').toString();
    final unionName = (ride['union_name'] ?? '').toString();
    final driverName = (ride['driver_name'] ?? '').toString();
    final vehicleNumber = (ride['vehicle_number'] ?? '').toString();
    final phone = (ride['phone'] ?? '').toString();
    final whatsapp = (ride['whatsapp_number'] ?? '').toString();

    DateTime? departure;
    final rawDt = ride['departure_time'];
    if (rawDt is String) {
      try {
        departure = DateTime.tryParse(rawDt)?.toLocal();
      } catch (_) {}
    } else if (rawDt is DateTime) {
      departure = rawDt.toLocal();
    }

    final departureText = departure != null
        ? DateFormat('dd MMM yyyy • hh:mm a').format(departure)
        : 'Time not available';

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (unionName.isNotEmpty) ...[
              Text(
                unionName,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.blue,
                ),
              ),
              const SizedBox(height: 4),
            ],
            Row(
              children: [
                const Icon(Icons.trip_origin, color: Colors.green, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    from,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.location_on, color: Colors.red, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    to,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.access_time, size: 18, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text(
                      departureText,
                      style: const TextStyle(fontSize: 14),
                    ),
                  ],
                ),
                if (vehicleNumber.isNotEmpty)
                  Row(
                    children: [
                      const Icon(Icons.directions_car, size: 18, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text(
                        vehicleNumber,
                        style: const TextStyle(fontSize: 14),
                      ),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 8),
            if (driverName.isNotEmpty)
              Row(
                children: [
                  const Icon(Icons.person, size: 18, color: Colors.grey),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      driverName,
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: phone.isEmpty ? null : () => _launchPhone(phone),
                    icon: const Icon(Icons.call),
                    label: const Text('Call'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: whatsapp.isEmpty ? null : () => _launchWhatsApp(whatsapp),
                    icon: const Icon(Icons.chat),
                    label: const Text('WhatsApp'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _launchPhone(String phone) async {
    final uri = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _launchWhatsApp(String phone) async {
    if (phone.isEmpty) return;
    final normalized = phone.replaceAll(' ', '');
    final uri = Uri.parse('https://wa.me/$normalized');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
