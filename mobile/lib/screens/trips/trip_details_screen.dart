import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/trip_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/trip_service.dart';
import '../auth/simple_login_screen.dart';
import 'seat_selection_screen.dart';

class TripDetailsScreen extends StatefulWidget {
  final String tripId;
  /// From search result - show immediately, no "Trip not found" while loading
  final TripModel? initialTrip;
  /// When true, prompt login before seat selection (e.g. from landing)
  final bool requireLogin;

  const TripDetailsScreen({super.key, required this.tripId, this.initialTrip, this.requireLogin = false});

  @override
  State<TripDetailsScreen> createState() => _TripDetailsScreenState();
}

class _TripDetailsScreenState extends State<TripDetailsScreen> {
  final _tripService = TripService();
  TripModel? _trip;
  List<int> _bookedSeats = [];
  List<int> _pendingSeats = [];
  bool _isLoading = true;

  TripModel? get _displayTrip => _trip ?? widget.initialTrip;

  @override
  void initState() {
    super.initState();
    if (widget.initialTrip != null) {
      _trip = widget.initialTrip;
      _isLoading = false;
    }
    _loadTripDetails();
  }

  Future<void> _loadTripDetails() async {
    if (widget.initialTrip == null) {
      setState(() => _isLoading = true);
    }

    try {
      final result = await _tripService.getTripDetails(widget.tripId);

      if (!mounted) return;
      setState(() {
        _isLoading = false;
        if (result['success'] == true && result['trip'] != null) {
          _trip = result['trip'];
          _bookedSeats = List<int>.from(result['booked_seats'] ?? []);
          _pendingSeats = List<int>.from(result['pending_seats'] ?? []);
        }
        // Never clear _trip when we have initialTrip - API fail = keep showing search result
        if (_trip == null && widget.initialTrip != null) {
          _trip = widget.initialTrip;
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        if (_trip == null && widget.initialTrip != null) {
          _trip = widget.initialTrip;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Trip Details'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _displayTrip == null
              ? const Center(child: Text('Trip not found'))
              : _buildTripDetails(),
      bottomNavigationBar: _displayTrip != null && _displayTrip!.availableSeats > 0
          ? _buildBookButton()
          : null,
    );
  }

  Widget _buildTripDetails() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Route Card
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _buildRouteRow(
                    icon: Icons.trip_origin,
                    color: Colors.green,
                    label: 'From',
                    value: _displayTrip!.fromLocation,
                  ),
                  const SizedBox(height: 16),
                  _buildRouteRow(
                    icon: Icons.location_on,
                    color: Colors.red,
                    label: 'To',
                    value: _displayTrip!.toLocation,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Time & Date Card
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Schedule',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Icon(Icons.calendar_today, size: 20, color: Colors.blue),
                      const SizedBox(width: 8),
                      Text(
                        _displayTrip!.formattedDate,
                        style: const TextStyle(fontSize: 16),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.access_time, size: 20, color: Colors.blue),
                      const SizedBox(width: 8),
                      Text(
                        _displayTrip!.formattedDepartureTime,
                        style: const TextStyle(fontSize: 16),
                      ),
                      if (_displayTrip!.formattedDuration != 'N/A') ...[
                        const SizedBox(width: 8),
                        Text(
                          '(${_displayTrip!.formattedDuration})',
                          style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Vehicle & Seats Card
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Vehicle Details',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  if (_displayTrip!.vehicleNumber != null)
                    Row(
                      children: [
                        const Icon(Icons.directions_car, size: 20, color: Colors.grey),
                        const SizedBox(width: 8),
                        Text(
                          _displayTrip!.vehicleNumber!,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.event_seat, size: 20, color: Colors.grey),
                      const SizedBox(width: 8),
                      Text(
                        '${_displayTrip!.availableSeats} / ${_displayTrip!.totalSeats} seats available',
                        style: TextStyle(
                          fontSize: 16,
                          color: _displayTrip!.availableSeats > 0 ? Colors.green : Colors.red,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Driver Card
          if (_displayTrip!.driver != null)
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Driver',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: Colors.green,
                          child: Text(
                            _displayTrip!.driver!.name[0].toUpperCase(),
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  _displayTrip!.driver!.name,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                if (_displayTrip!.driver!.isVerified) ...[
                                  const SizedBox(width: 6),
                                  Icon(Icons.verified, color: Colors.blue[700], size: 20),
                                ],
                              ],
                            ),
                            if (_displayTrip!.driver!.phone != null)
                              Text(
                                _displayTrip!.driver!.phone!,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[600],
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 16),

          // Fare Card
          Card(
            elevation: 2,
            color: Colors.blue[50],
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Fare per Seat',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  Row(
                    children: [
                      const Icon(Icons.currency_rupee, size: 24, color: Colors.blue),
                      Text(
                        _displayTrip!.farePerSeat.toStringAsFixed(0),
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRouteRow({
    required IconData icon,
    required Color color,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBookButton() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SizedBox(
        height: 56,
        child: ElevatedButton.icon(
          onPressed: () {
            final authProvider = context.read<AuthProvider>();
            if (widget.requireLogin && !authProvider.isAuthenticated) {
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Login Required'),
                  content: const Text('Please login to book a seat on this ride.'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                    TextButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const SimpleLoginScreen()),
                        );
                      },
                      child: const Text('Login'),
                    ),
                  ],
                ),
              );
              return;
            }
            _navigateToSeatSelection();
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          icon: const Icon(Icons.event_seat, size: 24),
          label: const Text(
            'Select Seats & Book',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }

  void _navigateToSeatSelection() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SeatSelectionScreen(
          trip: _displayTrip!,
          initialBookedSeats: _bookedSeats,
          initialPendingSeats: _pendingSeats,
        ),
      ),
    );
  }
}
