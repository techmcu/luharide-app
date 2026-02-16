import 'package:flutter/material.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:intl/intl.dart';
import '../../models/trip_model.dart';
import '../../services/trip_service.dart';
import '../auth/simple_login_screen.dart';
import '../auth/simple_signup_screen.dart';
import '../trips/trip_details_screen.dart';

/// BlaBlaCar-style landing screen - search first, no login required to browse
class LandingScreen extends StatefulWidget {
  const LandingScreen({super.key});

  @override
  State<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends State<LandingScreen> {
  final _tripService = TripService();
  final _fromController = TextEditingController();
  final _toController = TextEditingController();
  final _scrollController = ScrollController();
  DateTime _selectedDate = DateTime.now();
  int _passengerCount = 1;

  List<TripModel> _searchResults = [];
  bool _isSearching = false;
  bool _hasSearched = false;

  @override
  void dispose() {
    _fromController.dispose();
    _toController.dispose();
    _scrollController.dispose();
    super.dispose();
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

    setState(() {
      _isSearching = false;
      _searchResults = result['trips'] ?? [];
    });

    if (_searchResults.isNotEmpty && mounted) {
      await Future.delayed(const Duration(milliseconds: 400));
      if (mounted) {
        final targetOffset = 440.0;
        _scrollController.animateTo(
          targetOffset,
          duration: const Duration(milliseconds: 1100),
          curve: Curves.easeInOutCubic,
        );
      }
    } else if (_hasSearched && _searchResults.isEmpty && mounted) {
      await Future.delayed(const Duration(milliseconds: 250));
      if (mounted) {
        _scrollController.animateTo(
          420,
          duration: const Duration(milliseconds: 900),
          curve: Curves.easeInOutCubic,
        );
      }
    }

    if (!result['success'] && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result['message'] ?? 'Search failed'), backgroundColor: Colors.red),
      );
    }
  }

  void _onTripTap(TripModel trip) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TripDetailsScreen(
          tripId: trip.id,
          initialTrip: trip,
          requireLogin: true,
        ),
      ),
    );

    // If booking was successful, refresh search results
    if (result == true && mounted) {
      _searchTrips();
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.blue[50]!,
              Colors.white,
              const Color(0xFFF8FAFC),
            ],
            stops: const [0.0, 0.35, 1.0],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            controller: _scrollController,
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: screenHeight - MediaQuery.of(context).padding.top - MediaQuery.of(context).padding.bottom),
              child: Column(
                children: [
                  // Header - clean & attractive
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'LuhaRide',
                              style: TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.w600,
                                color: Colors.blue[800],
                                letterSpacing: 0.2,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.blue.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: Colors.blue.withOpacity(0.2), width: 1),
                              ),
                              child: Text(
                                'Left Up, Help All',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w400,
                                  color: Colors.blue[700],
                                  letterSpacing: 0.8,
                                ),
                              ),
                            ),
                          ],
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            TextButton(
                              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SimpleLoginScreen())),
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.grey[700],
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              ),
                              child: const Text('Login', style: TextStyle(fontWeight: FontWeight.w400, fontSize: 14)),
                            ),
                            const SizedBox(width: 4),
                            Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [Colors.blue[600]!, Colors.blue[500]!],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(color: Colors.blue.withOpacity(0.35), blurRadius: 10, offset: const Offset(0, 3)),
                                ],
                              ),
                              child: TextButton(
                                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SimpleSignupScreen())),
                                style: TextButton.styleFrom(
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                ),
                                child: const Text('Sign up', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),
                  // Search box - full width, beautiful, light
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 20,
                            offset: const Offset(0, 6),
                          ),
                          BoxShadow(
                            color: Colors.blue.withOpacity(0.04),
                            blurRadius: 30,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                        child: Column(
                          children: [
                            _LocationField(
                              controller: _fromController,
                              label: 'From',
                              icon: Icons.trip_origin_rounded,
                              iconColor: Colors.green[400]!,
                              tripService: _tripService,
                            ),
                            const SizedBox(height: 14),
                            _LocationField(
                              controller: _toController,
                              label: 'To',
                              icon: Icons.location_on_rounded,
                              iconColor: Colors.red[300]!,
                              tripService: _tripService,
                            ),
                            Divider(height: 1, color: Colors.grey[100], thickness: 1),
                            InkWell(
                              onTap: () async {
                                final date = await showDatePicker(
                                  context: context,
                                  initialDate: _selectedDate,
                                  firstDate: DateTime.now(),
                                  lastDate: DateTime.now().add(const Duration(days: 30)),
                                );
                                if (date != null) setState(() => _selectedDate = date);
                              },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                child: Row(
                                  children: [
                                    Icon(Icons.calendar_today_rounded, color: Colors.grey[400], size: 20),
                                    const SizedBox(width: 12),
                                    Text(
                                      _selectedDate.day == DateTime.now().day ? 'Today' : DateFormat('EEE, d MMM').format(_selectedDate),
                                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w400, color: Colors.grey[800]),
                                    ),
                                    const Spacer(),
                                    Icon(Icons.keyboard_arrow_down_rounded, color: Colors.grey[400], size: 22),
                                  ],
                                ),
                              ),
                            ),
                            Divider(height: 1, color: Colors.grey[100], thickness: 1),
                            InkWell(
                              onTap: () {
                              showModalBottomSheet(
                                context: context,
                                backgroundColor: Colors.transparent,
                                builder: (ctx) => Container(
                                  height: MediaQuery.of(context).size.height * 0.5,
                                  decoration: const BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                                  ),
                                  child: SafeArea(
                                    child: Column(
                                      children: [
                                        Padding(
                                          padding: const EdgeInsets.all(16),
                                          child: Text('Passengers', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.grey[800])),
                                        ),
                                        Expanded(
                                          child: ListView.builder(
                                            itemCount: 10,
                                            itemBuilder: (_, i) {
                                              final n = i + 1;
                                              return ListTile(
                                                title: Text(
                                                  '$n passenger${n > 1 ? 's' : ''}',
                                                  style: TextStyle(fontSize: 16, fontWeight: n == _passengerCount ? FontWeight.w600 : FontWeight.w400),
                                                ),
                                                onTap: () {
                                                  setState(() => _passengerCount = n);
                                                  Navigator.pop(ctx);
                                                },
                                              );
                                            },
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              child: Row(
                                children: [
                                  Icon(Icons.person_outline_rounded, color: Colors.grey[400], size: 20),
                                  const SizedBox(width: 12),
                                  Text(
                                    '$_passengerCount passenger${_passengerCount > 1 ? 's' : ''}',
                                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w400, color: Colors.grey[800]),
                                  ),
                                  const Spacer(),
                                  Icon(Icons.keyboard_arrow_down_rounded, color: Colors.grey[400], size: 22),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [Colors.blue[600]!, Colors.blue[500]!],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(14),
                                boxShadow: [
                                  BoxShadow(color: Colors.blue.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 3)),
                                ],
                              ),
                              child: ElevatedButton(
                                onPressed: _isSearching ? null : _searchTrips,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.transparent,
                                  shadowColor: Colors.transparent,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                ),
                                child: _isSearching
                                    ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                    : Text('Find Rides', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, letterSpacing: 0.3)),
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                        ],
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 24),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    'Find rides at low prices',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w300,
                      color: Colors.grey[500],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 32),

                // Search results
              if (_hasSearched)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Rides Found', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.grey[800])),
                          if (_searchResults.isNotEmpty) Text('${_searchResults.length} trips', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w400, color: Colors.grey[600])),
                        ],
                      ),
                      const SizedBox(height: 16),
                      ...(_searchResults.isEmpty
                          ? [
                              Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(32),
                                  child: Column(
                                    children: [
                                      Icon(Icons.search_off, size: 56, color: Colors.grey[300]),
                                      const SizedBox(height: 16),
                                      Text('No trips found', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w400, color: Colors.grey[500])),
                                    ],
                                  ),
                                ),
                              ),
                            ]
                          : _searchResults.map((trip) => _buildTripCard(trip)).toList()),
                    ],
                  ),
                ),

              const SizedBox(height: 48),

                // Footer - powered by (Professional paragraph style)
                Padding(
                  padding: const EdgeInsets.only(bottom: 24),
                  child: Column(
                    children: [
                      // Decorative line
                      Container(
                        width: 60,
                        height: 1.5,
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.grey[300]!,
                              Colors.grey[200]!,
                              Colors.grey[300]!,
                            ],
                          ),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      // Powered by text with elegant styling
                      RichText(
                        textAlign: TextAlign.center,
                        text: TextSpan(
                          children: [
                            TextSpan(
                              text: 'Powered by ',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w300,
                                color: Colors.grey[400],
                                letterSpacing: 0.8,
                              ),
                            ),
                            TextSpan(
                              text: 'techmcu',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: Colors.grey[400],
                                letterSpacing: 1.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Tagline with better design
                      Text(
                        'Safe • Legal • Reliable',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w300,
                          color: Colors.grey[400],
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    ),
    ),
    );
  }

  Widget _buildTripCard(TripModel trip) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => _onTripTap(trip),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.trip_origin, color: Colors.green, size: 20),
                  const SizedBox(width: 8),
                  Expanded(child: Text(trip.fromLocation, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.location_on, color: Colors.red, size: 20),
                  const SizedBox(width: 8),
                  Expanded(child: Text(trip.toLocation, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
                ],
              ),
              const Divider(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(children: [const Icon(Icons.access_time, size: 18, color: Colors.grey), const SizedBox(width: 4), Text(trip.formattedDepartureTime, style: const TextStyle(fontSize: 14))]),
                  Row(children: [const Icon(Icons.event_seat, size: 18, color: Colors.grey), const SizedBox(width: 4), Text('${trip.availableSeats} seats', style: TextStyle(fontSize: 14, color: trip.availableSeats > 0 ? Colors.green : Colors.red, fontWeight: FontWeight.bold))]),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(children: [const Icon(Icons.currency_rupee, size: 20, color: Colors.blue), Text('${trip.farePerSeat.toStringAsFixed(0)}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.blue)), const Text(' /seat')]),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => _onTripTap(trip),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                  child: const Text('View Details & Book'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Location field with autocomplete from DB (trips) - suggests places from existing rides
class _LocationField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final Color iconColor;
  final TripService tripService;

  const _LocationField({
    required this.controller,
    required this.label,
    required this.icon,
    required this.iconColor,
    required this.tripService,
  });

  @override
  Widget build(BuildContext context) {
    return TypeAheadField<String>(
      controller: controller,
      suggestionsCallback: (query) async {
        if (query.length < 2) return [];
        return tripService.getLocationSuggestions(query);
      },
      debounceDuration: const Duration(milliseconds: 300),
      hideOnLoading: true,
      hideOnEmpty: true,
      hideOnUnfocus: true,
      builder: (context, ctrl, focusNode) => TextField(
        controller: ctrl,
        focusNode: focusNode,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: iconColor, size: 22),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
          labelStyle: TextStyle(fontSize: 15, fontWeight: FontWeight.w400, color: Colors.grey[600]),
          hintStyle: TextStyle(color: Colors.grey[400]),
        ),
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w400, color: Colors.grey[800]),
      ),
      itemBuilder: (context, suggestion) => ListTile(
        dense: true,
        leading: Icon(icon, color: iconColor, size: 20),
        title: Text(
          suggestion,
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w400, color: Colors.grey[800]),
        ),
      ),
      onSelected: (suggestion) {
        controller.text = suggestion;
      },
    );
  }
}
