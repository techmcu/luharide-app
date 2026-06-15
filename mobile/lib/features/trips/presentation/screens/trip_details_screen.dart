import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../providers/app_language_provider.dart';
import '../../../../models/trip_model.dart';
import '../../../../providers/auth_provider.dart';
import '../../../../services/realtime_socket_service.dart';
import '../../../../services/trip_service.dart';
import '../../../../services/review_service.dart';
import '../../../../utils/launch_whatsapp.dart';
import '../../../../utils/phone_call_helper.dart';
import '../../../auth/presentation/screens/simple_login_screen.dart';
import '../../../profile/presentation/screens/edit_profile_screen.dart';
import '../../../profile/presentation/screens/user_reviews_screen.dart';
import 'seat_selection_screen.dart';

class TripDetailsScreen extends StatefulWidget {
  final String tripId;

  /// From search result - show immediately, no "Trip not found" while loading
  final TripModel? initialTrip;

  /// When true, prompt login before seat selection (e.g. from landing)
  final bool requireLogin;

  const TripDetailsScreen(
      {super.key,
      required this.tripId,
      this.initialTrip,
      this.requireLogin = false});

  @override
  State<TripDetailsScreen> createState() => _TripDetailsScreenState();
}

class _TripDetailsScreenState extends State<TripDetailsScreen> {
  final _tripService = TripService();
  TripModel? _trip;
  List<int> _bookedSeats = [];
  List<int> _pendingSeats = [];
  List<Map<String, dynamic>> _coPassengers = [];
  bool _isLoading = true;

  /// null = not booked, 'pending' = waiting, 'confirmed' = confirmed
  String? _userBookingStatus;
  bool _isNavigatingToBooking = false;
  bool _isLoadingDetails = false;

  StreamSubscription<Map<String, dynamic>>? _tripSocketSub;

  TripModel? get _displayTrip => _trip ?? widget.initialTrip;

  @override
  void initState() {
    super.initState();
    if (widget.initialTrip != null) {
      _trip = widget.initialTrip;
      _isLoading = false;
    }
    _loadTripDetails();
    RealtimeSocketService.instance.joinTrip(widget.tripId);
    _tripSocketSub =
        RealtimeSocketService.instance.tripUpdatedStream.listen((e) {
      final tid = e['tripId']?.toString();
      if (tid == widget.tripId && mounted) {
        _loadTripDetails();
      }
    });
  }

  @override
  void dispose() {
    _tripSocketSub?.cancel();
    RealtimeSocketService.instance.leaveTrip(widget.tripId);
    super.dispose();
  }

  Future<void> _loadTripDetails() async {
    if (_isLoadingDetails) return;
    _isLoadingDetails = true;

    if (widget.initialTrip == null && mounted) {
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
          _userBookingStatus = result['user_booking_status'] as String?;
          _coPassengers = (result['co_passengers'] as List<dynamic>?)
              ?.where((e) => e is Map)
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList() ?? [];
        }
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
    } finally {
      _isLoadingDetails = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    context.watch<AppLanguageProvider>();
    context.watch<AuthProvider>();
    final loc = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(loc.t('trip.details.title')),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: const [],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _displayTrip == null
              ? Center(child: Text(loc.t('trip.details.not_found')))
              : _buildTripDetails(loc),
      bottomNavigationBar: _tripDetailsBottomBar(loc),
    );
  }

  /// Book CTA, or info bar if the current user is the trip owner (same user id as driver).
  Widget? _tripDetailsBottomBar(AppLocalizations loc) {
    final t = _displayTrip;
    if (t == null || t.availableSeats <= 0) return null;
    final uid = context.read<AuthProvider>().user?.id;
    if (t.isCreatedByUserId(uid)) {
      return _buildOwnRideBottomBar(loc);
    }
    return _buildBookButton(loc);
  }

  Widget _buildOwnRideBottomBar(AppLocalizations loc) {
    return SafeArea(
      top: false,
      minimum: EdgeInsets.zero,
      child: Material(
        color: Colors.amber[50],
        elevation: 8,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline, color: Colors.amber[900], size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  loc.t('trip.details.own_ride_hint'),
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.35,
                    color: Colors.amber[900],
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTripDetails(AppLocalizations loc) {
    final user = context.read<AuthProvider>().user;
    final phoneMissing = user?.phone == null || (user?.phone ?? '').trim().isEmpty;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Phone number warning banner
          if (phoneMissing)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const EditProfileScreen()),
                  ).then((_) {
                    if (mounted) setState(() {});
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.orange[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.orange[300]!),
                  ),
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
            ),

          // Route Card
          Card(
            elevation: 2,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _buildRouteRow(
                    icon: Icons.trip_origin,
                    color: Colors.green,
                    label: loc.t('ride.from.label'),
                    value: _displayTrip!.fromLocation,
                  ),
                  const SizedBox(height: 16),
                  _buildRouteRow(
                    icon: Icons.location_on,
                    color: Colors.red,
                    label: loc.t('ride.to.label'),
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
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    loc.t('trip.details.schedule'),
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Icon(Icons.calendar_today,
                          size: 20, color: Colors.blue),
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
                      const Icon(Icons.access_time,
                          size: 20, color: Colors.blue),
                      const SizedBox(width: 8),
                      Text(
                        _displayTrip!.formattedDepartureTime,
                        style: const TextStyle(fontSize: 16),
                      ),
                      if (_displayTrip!.formattedDuration != 'N/A') ...[
                        const SizedBox(width: 8),
                        Text(
                          '(${_displayTrip!.formattedDuration})',
                          style:
                              TextStyle(fontSize: 14, color: Colors.grey[600]),
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
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    loc.t('trip.details.vehicle_details'),
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  if (_displayTrip!.vehicleNumber != null)
                    Row(
                      children: [
                        const Icon(Icons.directions_car,
                            size: 20, color: Colors.grey),
                        const SizedBox(width: 8),
                        Text(
                          _displayTrip!.vehicleNumber!,
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.event_seat,
                          size: 20, color: Colors.grey),
                      const SizedBox(width: 8),
                      Text(
                        loc.tReplace('trip.details.seats_available', {
                          'a': '${_displayTrip!.availableSeats}',
                          't': '${_displayTrip!.totalSeats}',
                        }),
                        style: TextStyle(
                          fontSize: 16,
                          color: _displayTrip!.availableSeats > 0
                              ? Colors.green
                              : Colors.red,
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
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      loc.t('trip.details.driver_section'),
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    InkWell(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => UserReviewsScreen(
                              userId: _displayTrip!.driver!.id,
                              displayName: _displayTrip!.driver!.name,
                            ),
                          ),
                        );
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: Colors.green,
                            child: Text(
                              _displayTrip!.driver!.name.isNotEmpty
                                  ? _displayTrip!.driver!.name[0].toUpperCase()
                                  : 'D',
                              style: const TextStyle(color: Colors.white),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
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
                                      Icon(Icons.verified,
                                          color: Colors.blue[700], size: 20),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Tap to see ratings & reviews',
                                  style: TextStyle(
                                      fontSize: 12, color: Colors.grey[600]),
                                ),
                              ],
                            ),
                          ),
                          Icon(Icons.chevron_right, color: Colors.grey[600]),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    _DriverRatingRow(
                      driverId: _displayTrip!.driver!.id,
                      driverName: _displayTrip!.driver!.name,
                    ),
                    // Contact only visible after confirmed booking
                    if ((_userBookingStatus == 'confirmed' || _userBookingStatus == 'completed') &&
                        _displayTrip!.driver!.phone != null &&
                        _displayTrip!.driver!.phone!
                            .trim()
                            .isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => launchPhoneCall(
                                  context, _displayTrip!.driver!.phone!),
                              icon: const Icon(Icons.call, size: 18),
                              label: Text(loc.t('trip.details.call')),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.green[700],
                                side: BorderSide(color: Colors.green[700]!),
                              ),
                            ),
                          ),
                          if (_displayTrip!.driver!.whatsappNumber != null &&
                              _displayTrip!.driver!.whatsappNumber!
                                  .trim()
                                  .isNotEmpty) ...[
                            const SizedBox(width: 10),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () => launchWhatsApp(
                                    _displayTrip!.driver!.whatsappNumber),
                                icon: const Icon(Icons.chat, size: 18),
                                label: Text(loc.t('trip.details.whatsapp')),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.green[700],
                                  side: BorderSide(color: Colors.green[700]!),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ] else if (_userBookingStatus == 'pending') ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.orange[50],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.orange[200]!),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.lock_clock,
                                size: 16, color: Colors.orange[700]),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                loc.t('trip.details.pending_contact'),
                                style: TextStyle(
                                    fontSize: 12, color: Colors.orange[800]),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          const SizedBox(height: 16),

          // Fellow Travelers — hide only on completed/cancelled trips
          if (_coPassengers.isNotEmpty &&
              _displayTrip?.status != 'completed' && _displayTrip?.status != 'cancelled')
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: _FellowTravelersCard(passengers: _coPassengers),
            ),

          // Fare Card
          Card(
            elevation: 2,
            color: Colors.blue[50],
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    loc.t('trip.details.fare_per_seat'),
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  Row(
                    children: [
                      const Icon(Icons.currency_rupee,
                          size: 24, color: Colors.blue),
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
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBookButton(AppLocalizations loc) {
    return SafeArea(
      top: false,
      minimum: EdgeInsets.zero,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withValues(alpha: 0.2),
              blurRadius: 4,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SizedBox(
          height: 56,
          child: ElevatedButton.icon(
            onPressed: _isNavigatingToBooking ? null : () async {
              final authProvider = context.read<AuthProvider>();
              if (widget.requireLogin && !authProvider.isAuthenticated) {
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: Text(loc.t('trip.details.login_required_title')),
                    content: Text(loc.t('trip.details.login_required_body')),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: Text(loc.t('app.cancel'))),
                      TextButton(
                        onPressed: () {
                          Navigator.pop(ctx);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const SimpleLoginScreen()),
                          );
                        },
                        child: Text(loc.t('trip.details.login_cta')),
                      ),
                    ],
                  ),
                );
                return;
              }
              setState(() => _isNavigatingToBooking = true);
              try {
                final t = _displayTrip!;
                final booked = List<int>.from(_bookedSeats);
                final pending = List<int>.from(_pendingSeats);
                final result = await Navigator.push<bool>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => SeatSelectionScreen(
                      trip: t,
                      initialBookedSeats: booked.isEmpty ? null : booked,
                      initialPendingSeats: pending.isEmpty ? null : pending,
                    ),
                  ),
                );
                if (result == true) await _loadTripDetails();
                if (mounted && result == true && Navigator.canPop(context)) {
                  Navigator.pop(context, true);
                }
              } finally {
                if (mounted) setState(() => _isNavigatingToBooking = false);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            icon: const Icon(Icons.directions_bus, size: 24),
            label: Text(
              loc.t('trip.details.book_ride'),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ),
    );
  }
}

class _DriverRatingRow extends StatefulWidget {
  final String driverId;
  final String driverName;

  const _DriverRatingRow({required this.driverId, required this.driverName});

  @override
  State<_DriverRatingRow> createState() => _DriverRatingRowState();
}

class _DriverRatingRowState extends State<_DriverRatingRow> {
  late final Future<Map<String, dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _future = ReviewService().getUserRatingSummary(widget.driverId);
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    return FutureBuilder<Map<String, dynamic>>(
      future: _future,
      builder: (context, snapshot) {
        final total = (snapshot.data?['total_ratings'] as num?)?.toInt() ?? 0;
        final avg = (snapshot.data?['average_rating'] as num?)?.toDouble();
        final avgStr = total > 0 && avg != null ? avg.toStringAsFixed(1) : null;
        return Row(
          children: [
            if (snapshot.connectionState == ConnectionState.waiting)
              const SizedBox(
                  height: 24,
                  width: 24,
                  child: CircularProgressIndicator(strokeWidth: 2))
            else if (total > 0 && avgStr != null)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.amber[50],
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.amber[200]!),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.star, color: Colors.amber[700], size: 18),
                    const SizedBox(width: 6),
                    Text('$avgStr ($total)',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.amber[900])),
                  ],
                ),
              )
            else
              Text(loc.t('trip.details.no_ratings'),
                  style: TextStyle(fontSize: 13, color: Colors.grey[600])),
            const SizedBox(width: 12),
            TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => UserReviewsScreen(
                        userId: widget.driverId, displayName: widget.driverName),
                  ),
                );
              },
              child: Text(loc.t('trip.details.see_reviews')),
            ),
          ],
        );
      },
    );
  }
}

class _FellowTravelersCard extends StatelessWidget {
  final List<Map<String, dynamic>> passengers;
  static const _maxVisible = 100;

  const _FellowTravelersCard({required this.passengers});

  @override
  Widget build(BuildContext context) {
    final shown = passengers.length > _maxVisible ? _maxVisible : passengers.length;
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(Icons.people_outline, size: 22, color: Colors.blue[700]),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Fellow Travelers (${passengers.length})',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Tap to see their ratings',
                style: TextStyle(fontSize: 12, color: Colors.grey[500]),
              ),
            ),
            const SizedBox(height: 12),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: shown,
              itemBuilder: (ctx, i) => _buildPassengerTile(ctx, passengers[i]),
            ),
            if (passengers.length > _maxVisible)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  '+${passengers.length - _maxVisible} more travelers',
                  style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPassengerTile(BuildContext context, Map<String, dynamic> p) {
    final id = p['id']?.toString() ?? '';
    final rawName = (p['name']?.toString() ?? '').trim();
    final name = rawName.isNotEmpty ? rawName : 'Passenger';
    final totalRatings = (p['total_ratings'] as num?)?.toInt() ?? 0;
    final rawAvg = (p['average_rating'] as num?)?.toDouble() ?? 0;
    final avgRating = rawAvg.isFinite ? rawAvg : 0.0;
    final seatNumbers = (p['seat_numbers'] as List?)
        ?.map((s) => s != null ? int.tryParse(s.toString()) : null)
        .where((n) => n != null && n > 0)
        .map((n) => n!.toString())
        .toList() ?? [];
    final status = p['status']?.toString() ?? '';
    final isPending = status == 'pending';

    return InkWell(
      onTap: id.isNotEmpty
          ? () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => UserReviewsScreen(userId: id, displayName: name),
                ),
              )
          : null,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: isPending ? Colors.orange[100] : Colors.blue[100],
              child: Text(
                name[0].toUpperCase(),
                style: TextStyle(
                  color: isPending ? Colors.orange[800] : Colors.blue[800],
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      if (seatNumbers.isNotEmpty)
                        Text(
                          'Seat ${seatNumbers.join(', ')}',
                          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                        ),
                      if (isPending) ...[
                        if (seatNumbers.isNotEmpty)
                          Text(' · ', style: TextStyle(fontSize: 12, color: Colors.grey[400])),
                        Text(
                          'Pending',
                          style: TextStyle(fontSize: 12, color: Colors.orange[700], fontWeight: FontWeight.w500),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            if (totalRatings > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.amber[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.amber[200]!),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.star, color: Colors.amber[700], size: 14),
                    const SizedBox(width: 3),
                    Text(
                      '${avgRating.toStringAsFixed(1)} ($totalRatings)',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.amber[900],
                      ),
                    ),
                  ],
                ),
              )
            else
              Text(
                'New',
                style: TextStyle(fontSize: 12, color: Colors.grey[500]),
              ),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right, size: 18, color: Colors.grey[400]),
          ],
        ),
      ),
    );
  }
}
