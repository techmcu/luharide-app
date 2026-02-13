import 'package:flutter/material.dart';
import '../../models/trip_model.dart';
import '../../services/trip_service.dart';

class DriverTripDetailsScreen extends StatefulWidget {
  final String tripId;
  final TripModel? initialTrip; // Fallback when API fails - pass from My Rides list

  const DriverTripDetailsScreen({
    super.key,
    required this.tripId,
    this.initialTrip,
  });

  @override
  State<DriverTripDetailsScreen> createState() => _DriverTripDetailsScreenState();
}

class _DriverTripDetailsScreenState extends State<DriverTripDetailsScreen> {
  final _tripService = TripService();
  TripModel? _trip;
  bool _isLoading = true;
  List<BookingInfo> _bookings = [];
  String? _bookingsError;
  bool _loadingBookings = false;

  @override
  void initState() {
    super.initState();
    _loadTripDetails();
  }

  Future<void> _loadTripDetails() async {
    setState(() => _isLoading = true);
    
    final result = await _tripService.getTripDetails(widget.tripId);
    
    if (result['success'] && result['trip'] != null) {
      _trip = result['trip'];
    } else if (widget.initialTrip != null) {
      // Fallback: use trip from My Rides list when API fails ( avoids "Trip not found" )
      _trip = widget.initialTrip;
    }
    
    // Always load bookings - needed for Accept/Reject buttons
    await _loadBookings();
    
    if (!mounted) return;
    setState(() => _isLoading = false);
  }

  Future<void> _loadBookings() async {
    setState(() {
      _loadingBookings = true;
      _bookingsError = null;
    });
    
    final bookingsResult = await _tripService.getTripBookings(widget.tripId);
    
    if (!mounted) return;
    setState(() {
      _loadingBookings = false;
      if (bookingsResult['success'] == true && bookingsResult['bookings'] != null) {
        _bookings = _parseBookings(bookingsResult['bookings'] as List);
        _bookingsError = null;
      } else {
        _bookings = [];
        _bookingsError = bookingsResult['message']?.toString() ?? 'Could not load requests';
      }
    });
  }

  List<BookingInfo> _parseBookings(List<dynamic> bookingsJson) {
    final List<BookingInfo> list = [];
    for (final b in bookingsJson) {
      final passenger = (b['passenger'] is Map) ? Map<String, dynamic>.from(b['passenger']) : {};
      final rawSeats = b['seat_numbers'];
      List<int> seatNumbers = [];
      if (rawSeats is List) {
        seatNumbers = rawSeats.map((e) => (e is num) ? e.toInt() : int.tryParse(e.toString()) ?? 0).where((n) => n > 0).toList();
      } else if (rawSeats != null) {
        seatNumbers = [int.tryParse(rawSeats.toString()) ?? 0].where((n) => n > 0).toList();
      }
      if (seatNumbers.isNotEmpty) {
        list.add(BookingInfo(
          id: b['id']?.toString() ?? '',
          seatNumbers: seatNumbers,
          passengerName: passenger['name']?.toString() ?? 'Passenger',
          phone: passenger['phone']?.toString() ?? passenger['email']?.toString() ?? '-',
          bookingStatus: b['status']?.toString() ?? 'confirmed',
        ));
      }
    }
    return list;
  }

  void _showDeleteDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Ride?'),
        content: const Text(
          'No one has booked this ride yet. Are you sure you want to delete it? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await _deleteTrip();
            },
            child: const Text('Yes, Delete', style: TextStyle(color: Colors.red, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteTrip() async {
    final result = await _tripService.deleteTrip(widget.tripId);
    if (!mounted) return;
    if (result['success']) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result['message'] ?? 'Ride deleted'), backgroundColor: Colors.green),
      );
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result['message'] ?? 'Cannot delete'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _respondToBooking(String bookingId, String action) async {
    final result = await _tripService.respondToBooking(bookingId, action);
    if (!mounted) return;
    if (result['success']) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result['message'] ?? 'Done'), backgroundColor: Colors.green),
      );
      _loadTripDetails();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result['message'] ?? 'Failed'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ride Details'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(
              Icons.delete_outline,
              color: _bookings.isEmpty ? null : Colors.grey[400],
            ),
            onPressed: () {
              if (_bookings.isEmpty) {
                _showDeleteDialog();
              } else {
                final pending = _bookings.where((b) => b.bookingStatus == 'pending').length;
                final confirmed = _bookings.where((b) => b.bookingStatus == 'confirmed').length;
                final msg = confirmed > 0
                    ? 'Cannot delete. $confirmed seat(s) are booked. Passengers would be affected.'
                    : 'Cannot delete. $pending request(s) pending. Accept or reject them first.';
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(msg), backgroundColor: Colors.orange),
                );
              }
            },
            tooltip: 'Delete ride',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _trip == null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 64, color: Colors.grey),
                      const SizedBox(height: 16),
                      const Text('Trip not found'),
                      if (widget.initialTrip == null) ...[
                        const SizedBox(height: 8),
                        TextButton.icon(
                          onPressed: _loadTripDetails,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Retry'),
                        ),
                      ],
                    ],
                  ),
                )
              : _buildTripDetails(),
    );
  }

  Widget _buildTripDetails() {
    final bookedSeats = _trip!.totalSeats - _trip!.availableSeats;
    final totalSeats = _trip!.totalSeats;

    return RefreshIndicator(
      onRefresh: _loadBookings,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Trip Status Header
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.green[50],
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _trip!.status.toUpperCase(),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.green[700],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _trip!.formattedDepartureTime,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: bookedSeats > 0 ? Colors.green : Colors.orange,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '$bookedSeats/$totalSeats Booked',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Route Card
          Padding(
            padding: const EdgeInsets.all(16),
            child: Card(
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
                      value: _trip!.fromLocation,
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Icon(Icons.arrow_downward, color: Colors.grey),
                    ),
                    _buildRouteRow(
                      icon: Icons.location_on,
                      color: Colors.red,
                      label: 'To',
                      value: _trip!.toLocation,
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Seat Layout
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Seat Layout',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          '${_trip!.availableSeats} available',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.green[700],
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildSeatLayout(),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Booking Requests - always show; driver can Accept/Reject
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.people, color: Colors.green),
                        const SizedBox(width: 8),
                        Text(
                          'Booking Requests (${_bookings.length})',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (_loadingBookings)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: CircularProgressIndicator(),
                        ),
                      )
                    else if (_bookingsError != null)
                      Column(
                        children: [
                          Text(
                            _bookingsError!,
                            style: TextStyle(color: Colors.red[700]),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 12),
                          ElevatedButton.icon(
                            onPressed: _loadBookings,
                            icon: const Icon(Icons.refresh),
                            label: const Text('Retry'),
                          ),
                        ],
                      )
                    else if (_bookings.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          'No requests yet. Pull down to refresh.',
                          style: TextStyle(color: Colors.grey[600]),
                          textAlign: TextAlign.center,
                        ),
                      )
                    else
                      ..._bookings.map((booking) => _buildPassengerCard(booking)),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
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

  Widget _buildSeatLayout() {
    final totalSeats = _trip!.totalSeats;
    final seatsPerRow = totalSeats <= 7 ? 2 : 3;
    final rows = (totalSeats / seatsPerRow).ceil();

    return Column(
      children: [
        // Driver seat
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.airline_seat_recline_extra, size: 24),
            ),
          ],
        ),
        const SizedBox(height: 16),
        // Seats grid
        ...List.generate(rows, (rowIndex) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(seatsPerRow, (colIndex) {
                final seatNumber = rowIndex * seatsPerRow + colIndex;
                if (seatNumber >= totalSeats) {
                  return const SizedBox(width: 50);
                }
                return _buildSeatIcon(seatNumber);
              }),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildSeatIcon(int seatNumber) {
    final seatNum = seatNumber + 1;
    final isBooked = _bookings.any((b) => b.seatNumbers.contains(seatNum));
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Column(
        children: [
          Icon(
            Icons.event_seat,
            size: 40,
            color: isBooked ? Colors.green : Colors.grey[300],
          ),
          const SizedBox(height: 4),
          Text(
            '${seatNumber + 1}',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: isBooked ? Colors.green : Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPassengerCard(BookingInfo booking) {
    final isPending = booking.bookingStatus == 'pending';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isPending ? Colors.orange[50] : Colors.green[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: isPending ? Colors.orange[200]! : Colors.green[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: isPending ? Colors.orange : Colors.green,
                child: Text(
                  booking.passengerName[0].toUpperCase(),
                  style: const TextStyle(color: Colors.white),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      booking.passengerName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      booking.phone,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: isPending ? Colors.orange : Colors.green,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Seat${booking.seatNumbers.length > 1 ? "s" : ""} ${booking.seatNumbers.join(", ")}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          if (isPending) ...[
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: booking.id.isNotEmpty
                      ? () => _respondToBooking(booking.id, 'reject')
                      : null,
                  child: const Text('Reject', style: TextStyle(color: Colors.red)),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: booking.id.isNotEmpty
                      ? () => _respondToBooking(booking.id, 'accept')
                      : null,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                  child: const Text('Accept'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// Model for booking info
class BookingInfo {
  final String id;
  final List<int> seatNumbers;
  final String passengerName;
  final String phone;
  final String bookingStatus;

  BookingInfo({
    required this.id,
    required this.seatNumbers,
    required this.passengerName,
    required this.phone,
    required this.bookingStatus,
  });
}
