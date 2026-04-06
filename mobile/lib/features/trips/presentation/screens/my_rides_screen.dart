import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../providers/app_language_provider.dart';
import '../../../../models/trip_model.dart';
import '../../../../services/trip_service.dart';
import 'driver_trip_details_screen.dart';
import 'package:intl/intl.dart';

class MyRidesScreen extends StatefulWidget {
  const MyRidesScreen({super.key});

  @override
  State<MyRidesScreen> createState() => _MyRidesScreenState();
}

class _MyRidesScreenState extends State<MyRidesScreen> {
  final _tripService = TripService();
  List<TripModel> _rides = [];
  bool _isLoading = true;
  String _filter = 'all'; // all, ongoing, completed, pending

  @override
  void initState() {
    super.initState();
    _loadMyRides();
  }

  Future<void> _loadMyRides() async {
    setState(() => _isLoading = true);

    final result = await _tripService.getMyTrips();

    if (!mounted) return;
    setState(() {
      _isLoading = false;
      if (result['success']) {
        _rides = result['trips'] ?? [];
      }
    });
  }

  List<TripModel> get _filteredRides {
    final now = DateTime.now();
    switch (_filter) {
      case 'ongoing':
        // Rides where departure time hasn't passed (vehicle hasn't left yet)
        return _rides.where((t) => !t.departureTime.isBefore(now)).toList();
      case 'completed':
        // Rides where departure time has passed (current time > ride create/departure time)
        return _rides.where((t) => t.departureTime.isBefore(now)).toList();
      case 'pending':
        // Rides with booking requests waiting for driver to accept
        return _rides.where((t) => t.pendingRequestsCount > 0).toList();
      case 'all':
      default:
        return List.from(_rides);
    }
  }

  @override
  Widget build(BuildContext context) {
    context.watch<AppLanguageProvider>();
    final loc = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(loc.t('my_rides.title')),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Filter Tabs
          Container(
            padding: const EdgeInsets.all(16),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterChip(loc, 'all'),
                  const SizedBox(width: 8),
                  _buildFilterChip(loc, 'ongoing'),
                  const SizedBox(width: 8),
                  _buildFilterChip(loc, 'pending'),
                  const SizedBox(width: 8),
                  _buildFilterChip(loc, 'completed'),
                ],
              ),
            ),
          ),

          // Rides List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredRides.isEmpty
                    ? _buildEmptyState(loc)
                    : RefreshIndicator(
                        onRefresh: _loadMyRides,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _filteredRides.length,
                          itemBuilder: (context, index) {
                            return _buildRideCard(loc, _filteredRides[index]);
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(AppLocalizations loc, String value) {
    final label = switch (value) {
      'all' => loc.t('driver.trips.chip.all'),
      'ongoing' => loc.t('driver.trips.chip.ongoing'),
      'pending' => loc.t('driver.trips.chip.pending'),
      'completed' => loc.t('driver.trips.chip.completed'),
      _ => value,
    };
    final isSelected = _filter == value;
    final pendingCount = value == 'pending' ? _rides.where((t) => t.pendingRequestsCount > 0).length : 0;
    return GestureDetector(
      onTap: () {
        setState(() {
          _filter = value;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: isSelected ? Colors.green : Colors.grey[200],
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.black87,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            if (value == 'pending' && pendingCount > 0) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.white24 : Colors.orange,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$pendingCount',
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(AppLocalizations loc) {
    final subtitle = switch (_filter) {
      'ongoing' => loc.t('driver.trips.empty.ongoing'),
      'completed' => loc.t('driver.trips.empty.completed'),
      'pending' => loc.t('driver.trips.empty.pending'),
      _ => loc.t('driver.trips.empty.all'),
    };
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.directions_bus_outlined, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            loc.t('driver.trips.empty.title'),
            style: TextStyle(fontSize: 18, color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  Widget _buildRideCard(AppLocalizations loc, TripModel trip) {
    final now = DateTime.now();
    final isOngoing = !trip.departureTime.isBefore(now); // departure time not passed = ongoing
    final bookedSeats = trip.totalSeats - trip.availableSeats;
    final hasPending = trip.pendingRequestsCount > 0;

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () async {
          final deleted = await Navigator.push<bool>(
            context,
            MaterialPageRoute(
              builder: (context) => DriverTripDetailsScreen(
                tripId: trip.id,
                initialTrip: trip, // Avoid "Trip not found" when API fails
              ),
            ),
          );
          if (deleted == true && mounted) _loadMyRides();
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Status Badge
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: isOngoing ? Colors.green[50] : Colors.grey[200],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          isOngoing
                              ? loc.t('driver.trips.badge.ongoing')
                              : loc.t('driver.trips.badge.completed'),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: isOngoing ? Colors.green[700] : Colors.grey[700],
                          ),
                        ),
                      ),
                      if (hasPending) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.orange[100],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            loc.tReplace('driver.trips.badge.pending_row', {
                              'n': '${trip.pendingRequestsCount}',
                            }),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.orange[800],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  Text(
                    DateFormat('dd MMM yyyy').format(trip.departureTime.toLocal()),
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Route
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
              const Padding(
                padding: EdgeInsets.only(left: 8, top: 4, bottom: 4),
                child: Icon(Icons.arrow_downward, size: 16, color: Colors.grey),
              ),
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
              const SizedBox(height: 12),

              // Time and Seats
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.access_time, size: 18, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text(
                        DateFormat('hh:mm a').format(trip.departureTime.toLocal()),
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[700],
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: bookedSeats > 0 ? Colors.green[50] : Colors.orange[50],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.event_seat,
                          size: 16,
                          color: bookedSeats > 0 ? Colors.green : Colors.orange,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          loc.tReplace('driver.trips.card.booked', {
                            'b': '$bookedSeats',
                            't': '${trip.totalSeats}',
                          }),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: bookedSeats > 0 ? Colors.green[700] : Colors.orange[700],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
