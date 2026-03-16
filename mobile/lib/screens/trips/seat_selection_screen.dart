import 'package:flutter/material.dart';
import '../../models/trip_model.dart';
import '../../models/seat_layout.dart';
import '../../services/trip_service.dart';
import '../../models/vehicle_catalog.dart';

class SeatSelectionScreen extends StatefulWidget {
  final TripModel trip;
  /// From trip details - show correct colors immediately
  final List<int>? initialBookedSeats;
  final List<int>? initialPendingSeats;

  const SeatSelectionScreen({
    super.key,
    required this.trip,
    this.initialBookedSeats,
    this.initialPendingSeats,
  });

  @override
  State<SeatSelectionScreen> createState() => _SeatSelectionScreenState();
}

class _SeatSelectionScreenState extends State<SeatSelectionScreen> {
  static const int _maxSeats = 32; // Independent driver max; layout must match driver's capacity

  final _tripService = TripService();
  final Set<int> _selectedSeats = {};
  late List<bool> _seatStatus; // true = booked or pending or driver, false = available
  bool _isLoadingSeats = true;
  bool _isSubmitting = false; // guard against double-tap
  Set<int> _bookedSeats = {};
  Set<int> _pendingSeats = {}; // for UI: show booked vs pending
  int _availableCount = 0;
  String? _loadError;
  late SeatLayoutConfig _layout;
  late Set<int> _driverSeatIndices; // 0-based indices where type == 'driver' (same as verification)
  late List<int> _logicalSeatNumber; // seat index -> API seat number (driver = 1, others = 2..N)
  late int _effectiveTotalSeats; // min(totalSeats, 32) for layout

  @override
  void initState() {
    super.initState();
    _initLayout();
    _loadSeatStatus();
  }

  void _initLayout() {
    // Use driver's selected vehicle layout (fixed at verification) — same top-view for passenger
    final vehicleModel = widget.trip.vehicleModelId != null
        ? VehicleCatalog.findModelById(widget.trip.vehicleModelId!)
        : null;
    _layout = vehicleModel?.layout ?? VehicleCatalog.layoutForCapacity(widget.trip.totalSeats.clamp(1, _maxSeats));
    _effectiveTotalSeats = (vehicleModel?.layout.seats.length ?? widget.trip.totalSeats).clamp(1, _maxSeats);
    _driverSeatIndices = _layout.seats
        .asMap()
        .entries
        .where((e) => e.value.type == 'driver')
        .map((e) => e.key)
        .toSet();
    // API convention: seat 1 = driver (reserved). Others = 2, 3, ..., N.
    _logicalSeatNumber = List.filled(_effectiveTotalSeats, 0);
    var next = 2;
    for (var i = 0; i < _effectiveTotalSeats; i++) {
      if (_driverSeatIndices.contains(i)) {
        _logicalSeatNumber[i] = 1;
      } else {
        _logicalSeatNumber[i] = next++;
      }
    }
  }

  void _applySeatData(Set<int> booked, Set<int> pending) {
    final totalSeats = _effectiveTotalSeats;
    // Backend sends seat 1 as driver; ensure driver is always in booked for UI
    _bookedSeats = Set<int>.from(booked)
      ..addAll(_driverSeatIndices.map((i) => _logicalSeatNumber[i]));
    _pendingSeats = pending;
    _seatStatus = List.generate(totalSeats, (index) {
      final logical = _logicalSeatNumber[index];
      return _bookedSeats.contains(logical) || _pendingSeats.contains(logical);
    });
    _availableCount = totalSeats - _bookedSeats.length - _pendingSeats.length;
  }

  Future<void> _loadSeatStatus() async {
    setState(() {
      _isLoadingSeats = true;
      _loadError = null;
    });

    final totalSeats = _effectiveTotalSeats;

    // Use initial data immediately so colors show right away
    final initBooked = widget.initialBookedSeats ?? [];
    final initPending = widget.initialPendingSeats ?? [];
    if (initBooked.isNotEmpty || initPending.isNotEmpty) {
      _applySeatData(
        Set<int>.from(initBooked),
        Set<int>.from(initPending),
      );
      setState(() => _isLoadingSeats = false);
    }

    final result = await _tripService.getTripBookedSeats(widget.trip.id);

    if (!mounted) return;

    if (result['success'] == true) {
      final booked = Set<int>.from((result['booked'] ?? []).map((e) => (e is num) ? e.toInt() : int.tryParse(e.toString()) ?? 0));
      final pending = Set<int>.from((result['pending'] ?? []).map((e) => (e is num) ? e.toInt() : int.tryParse(e.toString()) ?? 0));
      _applySeatData(booked, pending);
      // _availableCount already set in _applySeatData (includes driver seat as reserved)
    } else if (initBooked.isEmpty && initPending.isEmpty) {
      _loadError = result['message']?.toString();
      final bookedCount = totalSeats - widget.trip.availableSeats.clamp(0, totalSeats);
      _bookedSeats = Set.from(_driverSeatIndices.map((i) => _logicalSeatNumber[i]));
      _pendingSeats = {};
      _seatStatus = List.generate(totalSeats, (index) =>
        index < bookedCount || _driverSeatIndices.contains(index));
      _availableCount = widget.trip.availableSeats;
    }

    setState(() => _isLoadingSeats = false);
  }

  void _toggleSeat(int seatNumber) {
    if (_driverSeatIndices.contains(seatNumber)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Driver seat is reserved and cannot be booked'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }
    if (_seatStatus[seatNumber]) {
      final logicalNum = _logicalSeatNumber[seatNumber];
      final msg = _pendingSeats.contains(logicalNum)
          ? 'Seat $logicalNum is pending (requested by another passenger)'
          : 'Seat $logicalNum is already booked';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }

    setState(() {
      if (_selectedSeats.contains(seatNumber)) {
        _selectedSeats.remove(seatNumber);
      } else {
        _selectedSeats.add(seatNumber);
      }
    });
  }

  Color _getSeatColor(int seatNumber) {
    if (_driverSeatIndices.contains(seatNumber)) {
      return Colors.orange; // Driver seat - same as driver verification
    }
    final logicalNum = _logicalSeatNumber[seatNumber];
    if (_seatStatus[seatNumber]) {
      if (_bookedSeats.contains(logicalNum)) {
        return Colors.grey; // Confirmed/Booked
      }
      return Colors.orange[300]!; // Pending - more visible
    } else if (_selectedSeats.contains(seatNumber)) {
      return Colors.green; // Selected
    } else {
      return Colors.blue[100]!; // Available
    }
  }

  IconData _getSeatIcon(int seatNumber) {
    if (_driverSeatIndices.contains(seatNumber)) {
      return Icons.local_taxi; // Same icon as driver verification
    }
    if (_seatStatus[seatNumber]) {
      return Icons.event_seat;
    } else if (_selectedSeats.contains(seatNumber)) {
      return Icons.event_seat;
    } else {
      return Icons.event_seat_outlined;
    }
  }

  Future<void> _doBooking(double totalFare) async {
    if (_isSubmitting) return; // prevent double-tap
    setState(() => _isSubmitting = true);

    // Send logical seat numbers (driver = 1 is never sent)
    final seatNumbers = _selectedSeats.map((s) => _logicalSeatNumber[s]).toList()..sort();

    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
        ),
      ),
    );

    final result = await _tripService.createBooking(
      tripId: widget.trip.id,
      seatNumbers: seatNumbers,
    );

    if (!mounted) return;

    // Close loading dialog
    Navigator.pop(context);
    setState(() => _isSubmitting = false);

    if (result['success']) {
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message'] ?? 'Booking confirmed!'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 3),
        ),
      );
    } else {
      final msg = result['message'] ?? 'Booking failed';
      // Special message for already-booked case
      final isAlreadyBooked = msg.toLowerCase().contains('already') ||
          msg.toLowerCase().contains('conflict') ||
          msg.toLowerCase().contains('pending');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isAlreadyBooked ? 'You already have a booking for this trip.' : msg),
          backgroundColor: isAlreadyBooked ? Colors.orange : Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
      // Reload seat status so UI shows updated booked seats
      _loadSeatStatus();
    }
  }

  void _confirmBooking() {
    if (_selectedSeats.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one seat'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final totalFare = _selectedSeats.length * widget.trip.farePerSeat;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Booking'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Selected Seats: ${_selectedSeats.map((s) => _logicalSeatNumber[s]).join(', ')}'),
            const SizedBox(height: 8),
            Text('Number of Seats: ${_selectedSeats.length}'),
            const SizedBox(height: 8),
            Text(
              'Total (pay after ride): ₹${totalFare.toStringAsFixed(0)}',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.blue,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context); // Close dialog
              await _doBooking(totalFare);
            },
            child: const Text('Confirm Booking'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final totalSeats = _effectiveTotalSeats;
    // Use EXACT same layout as driver verification (set in initState)
    final layout = _layout;
    final seatPositions = layout.seats;
    // Map (row,col) -> seatIndex (0-based, used for status & booking)
    final Map<String, int> indexByPos = {};
    for (var i = 0; i < seatPositions.length; i++) {
      final s = seatPositions[i];
      indexByPos['${s.row}-${s.col}'] = i;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Seats'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Trip Info Header
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.blue[50],
            child: Column(
              children: [
                Row(
                  children: [
                    const Icon(Icons.trip_origin, color: Colors.green),
                    const SizedBox(width: 8),
                    Text(
                      widget.trip.fromLocation,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8),
                      child: Icon(Icons.arrow_forward, size: 20),
                    ),
                    const Icon(Icons.location_on, color: Colors.red),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        widget.trip.toLocation,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      widget.trip.formattedDepartureTime,
                      style: TextStyle(color: Colors.grey[700]),
                    ),
                    Row(
                      children: [
                        if (!_isLoadingSeats &&
                            _availableCount >= 0) ...[
                          Text(
                            '$_availableCount available',
                            style: TextStyle(
                              fontSize: 12,
                              color: _availableCount > 0
                                  ? Colors.green[700]
                                  : Colors.red,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 12),
                        ],
                        Text(
                          '₹${widget.trip.farePerSeat.toStringAsFixed(0)} per seat',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Seat count & Legend
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Seat count summary
                if (!_isLoadingSeats) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.blue[200]!),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildCountChip('Confirmed', _bookedSeats.length, Colors.grey),
                        _buildCountChip('Pending', _pendingSeats.length, Colors.orange),
                        _buildCountChip('Available', _availableCount, Colors.green),
                      ],
                    ),
                  ),
                  if (_loadError != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Tap ↓ to refresh',
                      style: TextStyle(fontSize: 12, color: Colors.orange[700]),
                    ),
                  ],
                  const SizedBox(height: 12),
                ],
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 16,
                  runSpacing: 8,
                  children: [
                    _buildLegend(Colors.orange, Icons.local_taxi, 'Driver'),
                    _buildLegend(Colors.blue[100]!, Icons.event_seat_outlined, 'Available'),
                    _buildLegend(Colors.green, Icons.event_seat, 'Selected'),
                    _buildLegend(Colors.grey, Icons.event_seat, 'Booked'),
                    _buildLegend(Colors.orange[300]!, Icons.event_seat, 'Pending'),
                  ],
                ),
              ],
            ),
          ),

          // Seat Layout - pull to refresh for latest seat status
          Expanded(
            child: _isLoadingSeats
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _loadSeatStatus,
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            // Driver seat indicator
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.grey[300],
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Row(
                                    children: [
                                      Icon(Icons.airline_seat_recline_extra, size: 30),
                                      SizedBox(width: 8),
                                      Text(
                                        'Driver',
                                        style: TextStyle(fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 24),
                            // Seats Grid - based on same SeatLayoutConfig as verification
                            ...List.generate(layout.rows, (rowIndex) {
                              final colCount = layout.colsForRow(rowIndex);
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 16),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: List.generate(colCount, (colIndex) {
                                    final key = '$rowIndex-$colIndex';
                                    final seatIndex = indexByPos[key];
                                    if (seatIndex == null || seatIndex >= totalSeats) {
                                      return const SizedBox(width: 60, height: 70);
                                    }
                                    return _buildSeat(seatIndex);
                                  }),
                                ),
                              );
                            }),
                          ],
                        ),
                      ),
                    ),
                  ),
          ),

          // Bottom Bar - Selected Info
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.3),
                  blurRadius: 4,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _selectedSeats.isEmpty
                              ? 'Select seats'
                              : '${_selectedSeats.length} seat(s) selected',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (_selectedSeats.isNotEmpty)
                          Text(
                            'Total: ₹${(_selectedSeats.length * widget.trip.farePerSeat).toStringAsFixed(0)}',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton(
                    onPressed: _selectedSeats.isEmpty ? null : _confirmBooking,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 16,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Book Now',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCountChip(String label, int count, Color color) {
    return Column(
      children: [
        Text(
          '$count',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(fontSize: 11, color: Colors.grey[700]),
        ),
      ],
    );
  }

  Widget _buildLegend(Color color, IconData icon, String label) {
    return Row(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildSeat(int seatNumber) {
    final isDriver = _driverSeatIndices.contains(seatNumber);
    final isBooked = _seatStatus[seatNumber];
    final isSelected = _selectedSeats.contains(seatNumber);
    final color = _getSeatColor(seatNumber);
    final icon = _getSeatIcon(seatNumber);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: GestureDetector(
        onTap: () => _toggleSeat(seatNumber),
        child: Container(
          width: 60,
          height: 70,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected ? Colors.green : Colors.grey[300]!,
              width: isSelected ? 3 : 1,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 30,
                color: isDriver
                    ? Colors.orange[800]
                    : isBooked
                        ? (_bookedSeats.contains(_logicalSeatNumber[seatNumber]) ? Colors.grey[700] : Colors.orange[700])
                        : isSelected
                            ? Colors.green[700]
                            : Colors.blue,
              ),
              const SizedBox(height: 4),
              Text(
                isDriver ? 'D' : '${_logicalSeatNumber[seatNumber]}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: isDriver ? Colors.orange[900] : (isBooked ? Colors.grey[600] : Colors.black87),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}