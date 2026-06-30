import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/feedback/app_feedback.dart';
import '../../../../providers/app_language_provider.dart';
import '../../../../providers/auth_provider.dart';
import '../../../../models/trip_model.dart';
import '../../../../utils/trip_self_book_guard.dart';
import '../../../../models/seat_layout.dart';
import '../../../profile/presentation/screens/edit_profile_screen.dart';
import '../../../../services/realtime_socket_service.dart';
import '../../../../services/trip_service.dart';
import '../../../../models/vehicle_catalog.dart';

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
  final Random _rand = Random.secure();

  /// One key per booking attempt — duplicate POSTs / retries return same booking (server migration 030).
  String _newIdempotencyKey() {
    const chars = '0123456789abcdefghijklmnopqrstuvwxyz';
    return List.generate(28, (_) => chars[_rand.nextInt(chars.length)]).join();
  }
  final Set<int> _selectedSeats = {};
  late List<bool> _seatStatus; // true = booked or pending or driver, false = available
  bool _isLoadingSeats = true;
  bool _isSubmitting = false; // guard against double-tap
  Set<int> _bookedSeats = {};
  Set<int> _pendingSeats = {}; // for UI: show booked vs pending
  int _availableCount = 0;
  String? _loadError;
  StreamSubscription<Map<String, dynamic>>? _tripSocketSub;
  late SeatLayoutConfig _layout;
  late Set<int> _driverSeatIndices; // 0-based indices where type == 'driver' (same as verification)
  late List<int> _logicalSeatNumber; // seat index -> API seat number (driver = 1, others = 2..N)
  late int _effectiveTotalSeats; // min(totalSeats, 32) for layout

  @override
  void initState() {
    super.initState();
    _initLayout();
    _loadSeatStatus();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final uid = context.read<AuthProvider>().user?.id;
      if (widget.trip.isCreatedByUserId(uid)) {
        showCannotBookOwnTripDialog(context).then((_) {
          if (mounted) Navigator.of(context).pop();
        });
      }
    });
    final id = widget.trip.id;
    RealtimeSocketService.instance.joinTrip(id);
    _tripSocketSub = RealtimeSocketService.instance.tripUpdatedStream.listen((e) {
      final tid = e['tripId']?.toString();
      if (tid == id && mounted) {
        _loadSeatStatus(forceRefresh: true);
      }
    });
  }

  @override
  void dispose() {
    _tripSocketSub?.cancel();
    RealtimeSocketService.instance.leaveTrip(widget.trip.id);
    super.dispose();
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

  Future<void> _loadSeatStatus({bool forceRefresh = false}) async {
    setState(() {
      _isLoadingSeats = true;
      _loadError = null;
    });

    final totalSeats = _effectiveTotalSeats;
    final initBooked = widget.initialBookedSeats ?? [];
    final initPending = widget.initialPendingSeats ?? [];
    final hasInitialData = initBooked.isNotEmpty || initPending.isNotEmpty;

    if (hasInitialData) {
      _applySeatData(Set<int>.from(initBooked), Set<int>.from(initPending));
      setState(() => _isLoadingSeats = false);
    }

    // Skip API call when we have fresh data from trip details — backend validates on booking.
    if (hasInitialData && !forceRefresh) {
      return;
    }

    final result = await _tripService.getTripBookedSeats(widget.trip.id);

    if (!mounted) return;

    if (result['success'] == true) {
      final booked = Set<int>.from((result['booked'] ?? []).map((e) => (e is num) ? e.toInt() : int.tryParse(e.toString()) ?? 0));
      final pending = Set<int>.from((result['pending'] ?? []).map((e) => (e is num) ? e.toInt() : int.tryParse(e.toString()) ?? 0));
      // Driver-reserved (locked) seats are unbookable — show them as booked (grey).
      final locked = Set<int>.from((result['locked'] ?? []).map((e) => (e is num) ? e.toInt() : int.tryParse(e.toString()) ?? 0));
      _applySeatData(booked.union(locked), pending);
    } else if (!hasInitialData) {
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
    final loc = AppLocalizations.of(context);
    if (_driverSeatIndices.contains(seatNumber)) {
      AppFeedback.show(
        context,
        loc.t('seat.select.driver_reserved'),
        kind: AppFeedbackKind.warning,
        duration: const Duration(seconds: 2),
      );
      return;
    }
    if (_seatStatus[seatNumber]) {
      final logicalNum = _logicalSeatNumber[seatNumber];
      final msg = _pendingSeats.contains(logicalNum)
          ? loc.tReplace('seat.select.seat_pending_other', {'n': '$logicalNum'})
          : loc.tReplace('seat.select.seat_booked', {'n': '$logicalNum'});
      AppFeedback.show(
        context,
        msg,
        kind: AppFeedbackKind.error,
        duration: const Duration(seconds: 2),
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
    // Always refresh latest seat status just before booking to reduce stale UI risk.
    await _loadSeatStatus(forceRefresh: true);

    if (!mounted) return;
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
      idempotencyKey: _newIdempotencyKey(),
    );

    if (!mounted) return;

    // Close loading dialog
    Navigator.pop(context);
    setState(() => _isSubmitting = false);

    final loc = AppLocalizations.of(context);
    if (result['success']) {
      Navigator.pop(context, true);
      final m = result['message']?.toString();
      final successText =
          (m != null && m.isNotEmpty) ? m : loc.t('seat.select.booking_confirmed_fallback');
      AppFeedback.show(
        context,
        successText,
        kind: AppFeedbackKind.success,
        duration: const Duration(seconds: 3),
      );
    } else {
      final raw = result['message']?.toString() ?? '';
      // Backend sends PHONE_REQUIRED: prefix when passenger phone is missing
      if (raw.startsWith('PHONE_REQUIRED:')) {
        _showPhoneRequiredDialog();
        return;
      }
      final msg = raw.isNotEmpty ? raw : loc.t('seat.select.booking_failed_fallback');
      final isAlreadyBooked = msg.toLowerCase().contains('already') ||
          msg.toLowerCase().contains('conflict') ||
          msg.toLowerCase().contains('pending');
      AppFeedback.show(
        context,
        isAlreadyBooked ? loc.t('seat.select.already_booking') : msg,
        kind: isAlreadyBooked ? AppFeedbackKind.warning : AppFeedbackKind.error,
        duration: const Duration(seconds: 4),
      );
      // Reload seat status so UI shows updated booked seats
      _loadSeatStatus(forceRefresh: true);
    }
  }

  void _showPhoneRequiredDialog() {
    final loc = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(loc.t('booking.phone_required.title')),
        content: Text(loc.t('booking.phone_required.body')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(loc.t('app.cancel')),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const EditProfileScreen()),
              ).then((_) {
                if (mounted) setState(() {});
              });
            },
            child: Text(loc.t('booking.phone_required.go_to_profile')),
          ),
        ],
      ),
    );
  }

  void _confirmBooking() {
    final loc = AppLocalizations.of(context);
    if (_selectedSeats.isEmpty) {
      AppFeedback.show(
        context,
        loc.t('seat.select.pick_one'),
        kind: AppFeedbackKind.warning,
      );
      return;
    }

    // Check if user has phone number — required for independent driver rides
    final user = context.read<AuthProvider>().user;
    final phone = user?.phone;
    if (phone == null || phone.trim().isEmpty) {
      _showPhoneRequiredDialog();
      return;
    }

    final totalFare = _selectedSeats.length * widget.trip.farePerSeat;
    final seatsStr = _selectedSeats.map((s) => _logicalSeatNumber[s]).join(', ');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(loc.t('seat.select.confirm_title')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(loc.tReplace('seat.select.selected_seats', {'s': seatsStr})),
            const SizedBox(height: 8),
            Text(loc.tReplace('seat.select.number_of_seats', {'n': '${_selectedSeats.length}'})),
            const SizedBox(height: 8),
            Text(
              loc.tReplace('seat.select.total_pay', {'amt': totalFare.toStringAsFixed(0)}),
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
            onPressed: () => Navigator.pop(ctx),
            child: Text(loc.t('app.cancel')),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx); // Close dialog
              await _doBooking(totalFare);
            },
            child: Text(loc.t('seat.select.confirm_booking')),
          ),
        ],
      ),
    );
  }

  bool get _userPhoneMissing {
    final user = context.read<AuthProvider>().user;
    final phone = user?.phone;
    return phone == null || phone.trim().isEmpty;
  }

  @override
  Widget build(BuildContext context) {
    context.watch<AppLanguageProvider>();
    context.watch<AuthProvider>();
    final loc = AppLocalizations.of(context);
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
    final phoneMissing = _userPhoneMissing;

    // Responsive seat size is bounded by the widest row's width here, then also
    // fit to the available HEIGHT inside the LayoutBuilder below — so big
    // vehicles show as many seats as possible on small screens (and the grid
    // still scrolls when it can't all fit at the minimum size).
    final maxCols = layout.cols.clamp(1, 6);

    return Scaffold(
      appBar: AppBar(
        title: Text(loc.t('seat.select.title')),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Phone number warning banner
          if (phoneMissing)
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const EditProfileScreen()),
                ).then((_) {
                  if (mounted) setState(() {});
                });
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                color: Colors.orange[50],
                child: Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, color: Colors.orange[800], size: 22),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        loc.t('booking.phone_required.banner'),
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.orange[900],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    Icon(Icons.arrow_forward_ios, size: 14, color: Colors.orange[700]),
                  ],
                ),
              ),
            ),

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
                    Flexible(
                      child: Text(
                        widget.trip.fromLocation,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
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
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
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
                            loc.tReplace('seat.select.available_count', {'n': '$_availableCount'}),
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
                          loc.tReplace('seat.select.per_seat', {
                            'amt': widget.trip.farePerSeat.toStringAsFixed(0),
                          }),
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

          // Cab Full banner — every seat is taken; booking isn't possible.
          if (!_isLoadingSeats && _availableCount <= 0)
            Container(
              width: double.infinity,
              color: Colors.red[50],
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  Icon(Icons.event_busy, color: Colors.red[700], size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      loc.t('seat.select.cab_full'),
                      style: TextStyle(color: Colors.red[800], fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),

          // Compact status strip — counts in one line + a single horizontally
          // scrollable legend line. Frees vertical space so the seat map fits
          // on small screens and large (12+ seat) vehicles.
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
            child: Column(
              children: [
                if (!_isLoadingSeats) ...[
                  Row(
                    children: [
                      _buildCountInline(loc.t('seat.select.summary.confirmed'), _bookedSeats.length, Colors.grey[700]!),
                      _buildCountDivider(),
                      _buildCountInline(loc.t('seat.select.summary.pending'), _pendingSeats.length, Colors.orange[800]!),
                      _buildCountDivider(),
                      _buildCountInline(loc.t('seat.select.summary.available'), _availableCount, Colors.green[700]!),
                    ],
                  ),
                  if (_loadError != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        loc.t('seat.select.tap_refresh'),
                        style: TextStyle(fontSize: 12, color: Colors.orange[700]),
                      ),
                    ),
                  const SizedBox(height: 6),
                ],
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildLegend(Colors.orange, Icons.local_taxi, loc.t('seat.select.legend.driver')),
                      const SizedBox(width: 14),
                      _buildLegend(Colors.blue[100]!, Icons.event_seat_outlined, loc.t('seat.select.legend.available')),
                      const SizedBox(width: 14),
                      _buildLegend(Colors.green, Icons.event_seat, loc.t('seat.select.legend.selected')),
                      const SizedBox(width: 14),
                      _buildLegend(Colors.grey, Icons.event_seat, loc.t('seat.select.legend.booked')),
                      const SizedBox(width: 14),
                      _buildLegend(Colors.orange[300]!, Icons.event_seat, loc.t('seat.select.legend.pending')),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Seat Layout - pull to refresh for latest seat status
          Expanded(
            child: _isLoadingSeats
                ? const Center(child: CircularProgressIndicator())
                : LayoutBuilder(
                    builder: (context, constraints) {
                      // Auto-fit seat size to the available HEIGHT so large
                      // vehicles show more seats at once on small screens.
                      // Bounded by width; min 34 keeps seats tappable; the grid
                      // still scrolls when it can't all fit at the minimum.
                      final widthDim =
                          (MediaQuery.of(context).size.width - 32) / maxCols - 16;
                      final rowsCount = layout.rows < 1 ? 1 : layout.rows;
                      // Per row ≈ seatDim + 12 (seat) + 16 (row gap); reserve
                      // ~50 for the front marker and 32 for outer padding.
                      final heightDim =
                          (constraints.maxHeight - 82) / rowsCount - 28;
                      final seatDim = [widthDim, heightDim]
                          .reduce((a, b) => a < b ? a : b)
                          .clamp(34.0, 60.0);
                      return RefreshIndicator(
                    onRefresh: () => _loadSeatStatus(forceRefresh: true),
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            // Front-of-vehicle marker (orientation cue + subtle brand).
                            // The actual driver seat is shown inside the grid below
                            // (orange 'D'), so this stays small — no duplicate "Driver".
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: Colors.grey[200],
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.airline_seat_recline_normal, size: 14, color: Colors.grey[600]),
                                      const SizedBox(width: 4),
                                      Text(
                                        'LuhaRide',
                                        style: TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.w600,
                                          letterSpacing: 0.3,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
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
                                      return SizedBox(width: seatDim + 16, height: seatDim + 22);
                                    }
                                    return _buildSeat(seatIndex, seatDim);
                                  }),
                                ),
                              );
                            }),
                          ],
                        ),
                      ),
                    ),
                      );
                    },
                  ),
          ),

          // Bottom bar: keep above system nav / home indicator (SafeArea wraps full bar).
          SafeArea(
            top: false,
            minimum: EdgeInsets.zero,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withValues(alpha: 0.3),
                    blurRadius: 4,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _availableCount <= 0
                              ? loc.t('seat.select.full_short')
                              : _selectedSeats.isEmpty
                                  ? loc.t('seat.select.prompt_select')
                                  : loc.tReplace('seat.select.seats_selected', {
                                      'n': '${_selectedSeats.length}',
                                    }),
                          // Explicit dark color: the bar background is hardcoded
                          // white, so without this the text is invisible in dark theme.
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: _availableCount <= 0 ? Colors.red[700] : Colors.black87,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (_selectedSeats.isNotEmpty)
                          Text(
                            loc.tReplace('seat.select.total', {
                              'amt': (_selectedSeats.length * widget.trip.farePerSeat).toStringAsFixed(0),
                            }),
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
                    child: Text(
                      loc.t('seat.select.book_now'),
                      style: const TextStyle(
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

  // One compact "Label N" count cell. Flexible + ellipsis so three of them
  // never overflow, even with large system font or long translations.
  Widget _buildCountInline(String label, int count, Color color) {
    return Flexible(
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: '$label ',
              style: TextStyle(fontSize: 12, color: Colors.grey[700]),
            ),
            TextSpan(
              text: '$count',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _buildCountDivider() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Text('|', style: TextStyle(color: Colors.grey[400])),
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

  Widget _buildSeat(int seatNumber, double dim) {
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
          width: dim,
          height: dim + 12,
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
                size: dim * 0.5,
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