import 'package:flutter/material.dart';
import '../../../../core/feedback/app_feedback.dart';
import '../../../../models/trip_model.dart';
import '../../../../models/seat_layout.dart';
import '../../../../models/vehicle_catalog.dart';
import '../../../../services/trip_service.dart';
import '../../../../services/review_service.dart';
import '../../../../utils/launch_whatsapp.dart';
import '../../../../utils/phone_call_helper.dart';
import '../../../profile/presentation/screens/user_reviews_screen.dart';

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

  // Seat map (logical seat numbers: 1 = driver, 2..N bookable).
  SeatLayoutConfig? _layout;
  Set<int> _driverSeatIndices = {};
  List<int> _logicalSeatNumber = [];
  int _effectiveTotalSeats = 0;
  Set<int> _bookedSeatNums = {};   // confirmed
  Set<int> _pendingSeatNums = {};  // awaiting approval
  Set<int> _lockedSeatNums = {};   // reserved by this driver
  bool _seatActionBusy = false;

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

    if (_trip != null) {
      _initLayout();
      await _loadSeatStatus();
    }

    // Always load bookings - needed for Accept/Reject buttons
    await _loadBookings();

    if (!mounted) return;
    setState(() => _isLoading = false);
  }

  /// Build the same top-view layout + logical seat numbering the passenger sees,
  /// so a locked seat number always lines up across both screens (no conflict).
  void _initLayout() {
    final trip = _trip!;
    final model = trip.vehicleModelId != null
        ? VehicleCatalog.findModelById(trip.vehicleModelId!)
        : null;
    _layout = model?.layout ?? VehicleCatalog.layoutForCapacity(trip.totalSeats.clamp(1, 32));
    _effectiveTotalSeats = (model?.layout.seats.length ?? trip.totalSeats).clamp(1, 32);
    _driverSeatIndices = _layout!.seats
        .asMap()
        .entries
        .where((e) => e.value.type == 'driver')
        .map((e) => e.key)
        .toSet();
    _logicalSeatNumber = List.filled(_effectiveTotalSeats, 0);
    var next = 2;
    for (var i = 0; i < _effectiveTotalSeats; i++) {
      _logicalSeatNumber[i] = _driverSeatIndices.contains(i) ? 1 : next++;
    }
  }

  Future<void> _loadSeatStatus() async {
    final res = await _tripService.getTripBookedSeats(widget.tripId);
    if (!mounted) return;
    if (res['success'] == true) {
      Set<int> toSet(dynamic v) => Set<int>.from(
          (v as List? ?? []).map((e) => (e is num) ? e.toInt() : int.tryParse(e.toString()) ?? 0).where((n) => n > 0));
      setState(() {
        _bookedSeatNums = toSet(res['booked'])..remove(1); // seat 1 = driver, not a passenger seat
        _pendingSeatNums = toSet(res['pending']);
        _lockedSeatNums = toSet(res['locked']);
      });
    }
  }

  Future<void> _toggleSeatLock(int seatNum) async {
    if (_seatActionBusy) return;
    if (_lockedSeatNums.contains(seatNum)) {
      await _runSeatAction(() => _tripService.unlockSeats(widget.tripId, [seatNum]));
      return;
    }
    // Confirm reserve (with optional note for the relative's name).
    final controller = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Reserve seat $seatNum?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('No passenger will be able to book this seat until you release it.'),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              maxLength: 80,
              decoration: const InputDecoration(
                labelText: 'Note (optional)',
                hintText: 'e.g. for my brother',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple),
            child: const Text('Reserve'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _runSeatAction(
        () => _tripService.lockSeats(widget.tripId, [seatNum], note: controller.text));
  }

  Future<void> _runSeatAction(Future<Map<String, dynamic>> Function() action) async {
    setState(() => _seatActionBusy = true);
    final result = await action();
    if (!mounted) return;
    setState(() => _seatActionBusy = false);
    AppFeedback.show(
      context,
      result['message']?.toString() ?? (result['success'] == true ? 'Done' : 'Failed'),
      kind: result['success'] == true ? AppFeedbackKind.success : AppFeedbackKind.error,
    );
    // Refresh seat map + counts after any change.
    await _loadSeatStatus();
    final t = await _tripService.getTripDetails(widget.tripId);
    if (mounted && t['success'] == true && t['trip'] != null) {
      setState(() => _trip = t['trip']);
    }
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
          passengerId: passenger['id']?.toString() ?? '',
          seatNumbers: seatNumbers,
          passengerName: passenger['name']?.toString() ?? 'Passenger',
          phone: passenger['phone']?.toString() ?? '',
          whatsappNumber: passenger['whatsapp_number']?.toString() ?? '',
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
      AppFeedback.show(
        context,
        result['message'] ?? 'Ride deleted',
        kind: AppFeedbackKind.success,
      );
      Navigator.pop(context, true);
    } else {
      AppFeedback.show(
        context,
        result['message'] ?? 'Cannot delete',
        kind: AppFeedbackKind.error,
      );
    }
  }

  Future<void> _respondToBooking(String bookingId, String action) async {
    final result = await _tripService.respondToBooking(bookingId, action);
    if (!mounted) return;
    if (result['success']) {
      AppFeedback.show(
        context,
        result['message'] ?? 'Done',
        kind: AppFeedbackKind.success,
      );
      _loadTripDetails();
    } else {
      AppFeedback.show(
        context,
        result['message'] ?? 'Failed',
        kind: AppFeedbackKind.error,
      );
    }
  }

  Future<void> _completeTrip() async {
    final result = await _tripService.completeTrip(widget.tripId);
    if (!mounted) return;
    if (result['success']) {
      AppFeedback.show(
        context,
        result['message'] ?? 'Ride completed',
        kind: AppFeedbackKind.success,
      );
      _loadTripDetails();
    } else {
      AppFeedback.show(
        context,
        result['message'] ?? 'Could not complete',
        kind: AppFeedbackKind.error,
      );
    }
  }

  Future<void> _cancelTrip() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel trip?'),
        content: const Text(
          'This will cancel the trip and all bookings. Passengers will be notified. '
          'Frequent cancellations may lead to account restrictions.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('No')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Yes, cancel trip')),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    final result = await _tripService.cancelTrip(widget.tripId);
    if (!mounted) return;
    if (result['success']) {
      AppFeedback.show(
        context,
        result['message'] ?? 'Trip cancelled',
        kind: AppFeedbackKind.success,
      );
      Navigator.pop(context, true);
    } else {
      AppFeedback.show(
        context,
        result['message'] ?? 'Could not cancel',
        kind: AppFeedbackKind.error,
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
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            tooltip: 'More',
            onSelected: (value) {
              if (value == 'cancel_trip') {
                _cancelTrip();
              } else if (value == 'delete' && _bookings.isEmpty) {
                _showDeleteDialog();
              } else if (value == 'delete' && _bookings.isNotEmpty) {
                final confirmed = _bookings.where((b) => b.bookingStatus == 'confirmed').length;
                final pending = _bookings.where((b) => b.bookingStatus == 'pending').length;
                final msg = confirmed > 0
                    ? 'Cannot delete. $confirmed seat(s) booked. Use "Cancel trip" to cancel ride and bookings.'
                    : 'Cannot delete. $pending request(s) pending. Accept or reject first.';
                AppFeedback.show(
                  context,
                  msg,
                  kind: AppFeedbackKind.warning,
                );
              }
            },
            itemBuilder: (ctx) {
              final canCancelTrip = _trip != null &&
                  _trip!.status == 'scheduled' &&
                  _trip!.departureTime.isAfter(DateTime.now());
              return [
                if (canCancelTrip)
                  const PopupMenuItem(value: 'cancel_trip', child: Text('Cancel trip')),
                const PopupMenuItem(value: 'delete', child: Text('Delete ride (no bookings only)')),
              ];
            },
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

          // Complete ride (Driver) — only for union trips, after departure time has passed.
          // Independent driver trips auto-start and auto-complete via backend lifecycle job.
          if (!_trip!.isIndependentDriver &&
              (_trip!.status == 'scheduled' || _trip!.status == 'in_progress') &&
              !_trip!.departureTime.isAfter(DateTime.now()))
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _completeTrip,
                  icon: const Icon(Icons.check_circle),
                  label: const Text('Complete ride'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green[700],
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
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
    final layout = _layout;
    if (layout == null) {
      return const Padding(
        padding: EdgeInsets.all(8),
        child: Text('Seat layout unavailable.', style: TextStyle(color: Colors.grey)),
      );
    }
    final totalSeats = _effectiveTotalSeats;
    final Map<String, int> indexByPos = {};
    for (var i = 0; i < layout.seats.length; i++) {
      final s = layout.seats[i];
      indexByPos['${s.row}-${s.col}'] = i;
    }

    return Column(
      children: [
        // Hint
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.deepPurple[50],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(Icons.lock_outline, size: 18, color: Colors.deepPurple[400]),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Tap a free seat to reserve it (e.g. for a relative). Tap again to release.',
                  style: TextStyle(fontSize: 12, color: Colors.deepPurple[700]),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        ...List.generate(layout.rows, (rowIndex) {
          final colCount = layout.colsForRow(rowIndex);
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(colCount, (colIndex) {
                final seatIndex = indexByPos['$rowIndex-$colIndex'];
                if (seatIndex == null || seatIndex >= totalSeats) {
                  return const SizedBox(width: 56, height: 64);
                }
                return _buildSeatIcon(seatIndex);
              }),
            ),
          );
        }),
        const SizedBox(height: 12),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 14,
          runSpacing: 6,
          children: [
            _seatLegend(Colors.orange, 'Driver'),
            _seatLegend(Colors.green, 'Booked'),
            _seatLegend(Colors.orange[300]!, 'Pending'),
            _seatLegend(Colors.deepPurple, 'Reserved'),
            _seatLegend(Colors.blue[100]!, 'Free'),
          ],
        ),
      ],
    );
  }

  Widget _seatLegend(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.event_seat, size: 16, color: color),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 11)),
      ],
    );
  }

  Widget _buildSeatIcon(int seatIndex) {
    final isDriver = _driverSeatIndices.contains(seatIndex);
    final seatNum = _logicalSeatNumber[seatIndex];
    final isBooked = _bookedSeatNums.contains(seatNum);
    final isPending = _pendingSeatNums.contains(seatNum);
    final isLocked = _lockedSeatNums.contains(seatNum);

    Color color;
    if (isDriver) {
      color = Colors.orange;
    } else if (isBooked) {
      color = Colors.green;
    } else if (isPending) {
      color = Colors.orange[300]!;
    } else if (isLocked) {
      color = Colors.deepPurple;
    } else {
      color = Colors.blue[100]!;
    }

    // Only free or reserved (by us) seats are tappable. Booked/pending/driver are not.
    final canToggle = !isDriver && !isBooked && !isPending && !_seatActionBusy;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: GestureDetector(
        onTap: canToggle ? () => _toggleSeatLock(seatNum) : null,
        child: SizedBox(
          width: 56,
          child: Column(
            children: [
              Stack(
                alignment: Alignment.center,
                children: [
                  Icon(isDriver ? Icons.local_taxi : Icons.event_seat, size: 40, color: color),
                  if (isLocked)
                    const Icon(Icons.lock, size: 16, color: Colors.white),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                isDriver ? 'D' : '$seatNum',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: isDriver ? Colors.orange[900] : Colors.grey[700],
                ),
              ),
            ],
          ),
        ),
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
              InkWell(
                onTap: booking.passengerId.isNotEmpty
                    ? () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => UserReviewsScreen(
                              userId: booking.passengerId,
                              displayName: booking.passengerName,
                            ),
                          ),
                        );
                      }
                    : null,
                borderRadius: BorderRadius.circular(24),
                child: CircleAvatar(
                  backgroundColor: isPending ? Colors.orange : Colors.green,
                  child: Text(
                    booking.passengerName[0].toUpperCase(),
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: InkWell(
                  onTap: booking.passengerId.isNotEmpty
                      ? () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => UserReviewsScreen(
                                userId: booking.passengerId,
                                displayName: booking.passengerName,
                              ),
                            ),
                          );
                        }
                      : null,
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
                      const SizedBox(height: 2),
                      Text(
                        'Tap to see ratings & reviews',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                  ),
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
          if (booking.passengerId.isNotEmpty) ...[
            const SizedBox(height: 8),
            _PassengerRatingRow(passengerId: booking.passengerId, passengerName: booking.passengerName),
          ],
          if (booking.phone.trim().isNotEmpty && booking.phone != '-') ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: () {
                    launchPhoneCall(context, booking.phone);
                  },
                  icon: const Icon(Icons.call, size: 18),
                  label: const Text('Call'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.blue[700],
                    side: BorderSide(color: Colors.blue[700]!),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: () => launchWhatsApp(booking.contactForWhatsApp),
                  icon: const Icon(Icons.chat, size: 18),
                  label: const Text('WhatsApp'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.green[700],
                    side: BorderSide(color: Colors.green[700]!),
                  ),
                ),
              ],
            ),
          ] else ...[
            const SizedBox(height: 8),
            Text(
              'Passenger has not added a phone number',
              style: TextStyle(fontSize: 12, color: Colors.orange[700], fontStyle: FontStyle.italic),
            ),
          ],
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
  final String passengerId;
  final List<int> seatNumbers;
  final String passengerName;
  final String phone;
  final String whatsappNumber;
  final String bookingStatus;

  BookingInfo({
    required this.id,
    required this.passengerId,
    required this.seatNumbers,
    required this.passengerName,
    required this.phone,
    this.whatsappNumber = '',
    required this.bookingStatus,
  });

  String get contactForWhatsApp =>
      whatsappNumber.trim().isNotEmpty ? whatsappNumber : phone;
}

class _PassengerRatingRow extends StatelessWidget {
  final String passengerId;
  final String passengerName;

  const _PassengerRatingRow({required this.passengerId, required this.passengerName});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: ReviewService().getUserRatingSummary(passengerId),
      builder: (context, snapshot) {
        final total = (snapshot.data?['total_ratings'] as num?)?.toInt() ?? 0;
        final avg = (snapshot.data?['average_rating'] as num?)?.toDouble();
        final avgStr = total > 0 && avg != null ? avg.toStringAsFixed(1) : null;
        return Row(
          children: [
            if (snapshot.connectionState == ConnectionState.waiting)
              const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
            else if (total > 0 && avgStr != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.amber[50],
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.amber[200]!),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.star, color: Colors.amber[700], size: 16),
                    const SizedBox(width: 4),
                    Text('$avgStr ($total)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.amber[900])),
                  ],
                ),
              )
            else
              Text('No ratings yet', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
            const SizedBox(width: 8),
            TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => UserReviewsScreen(userId: passengerId, displayName: passengerName),
                  ),
                );
              },
              style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8), minimumSize: Size.zero),
              child: const Text('See reviews', style: TextStyle(fontSize: 12)),
            ),
          ],
        );
      },
    );
  }
}
