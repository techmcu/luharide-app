import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/localization/app_localizations.dart';
import '../../providers/app_language_provider.dart';
import '../../core/brand_config.dart';
import '../../core/constants/api_constants.dart';
import '../../models/trip_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/realtime_socket_service.dart';
import '../../services/trip_service.dart';
import '../../services/review_service.dart';
import '../../utils/launch_whatsapp.dart';
import '../auth/simple_login_screen.dart';
import '../profile/user_reviews_screen.dart';
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
  /// null = not booked, 'pending' = waiting, 'confirmed' = confirmed
  String? _userBookingStatus;

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
    _tripSocketSub = RealtimeSocketService.instance.tripUpdatedStream.listen((e) {
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
          _userBookingStatus = result['user_booking_status'] as String?;
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

  void _shareTrip() {
    final t = _displayTrip;
    if (t == null) return;
    final from = t.fromLocation;
    final to = t.toLocation;
    final date = DateFormat('dd MMM yyyy, hh:mm a').format(t.departureTime.toLocal());
    final shareUrl = '${ApiConstants.baseUrl}/trips/${widget.tripId}';
    final text = '${BrandConfig.appName}: $from → $to on $date. Book or view: $shareUrl';
    Share.share(text, subject: '${BrandConfig.appName} trip');
  }

  void _copyTripLink() {
    final shareUrl = '${ApiConstants.baseUrl}/trips/${widget.tripId}';
    Clipboard.setData(ClipboardData(text: shareUrl));
    if (!mounted) return;
    final loc = AppLocalizations.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(loc.t('trip.details.link_copied')), duration: const Duration(seconds: 2)),
    );
  }

  @override
  Widget build(BuildContext context) {
    context.watch<AppLanguageProvider>();
    final loc = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(loc.t('trip.details.title')),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          if (_displayTrip != null)
            PopupMenuButton<String>(
              icon: const Icon(Icons.share),
              tooltip: loc.t('trip.details.share_tooltip'),
              onSelected: (v) {
                if (v == 'share') _shareTrip();
                else if (v == 'copy') _copyTripLink();
              },
              itemBuilder: (ctx) => [
                PopupMenuItem(value: 'share', child: Text(loc.t('trip.details.share_link'))),
                PopupMenuItem(value: 'copy', child: Text(loc.t('trip.details.copy_link'))),
              ],
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _displayTrip == null
              ? Center(child: Text(loc.t('trip.details.not_found')))
              : _buildTripDetails(loc),
      bottomNavigationBar: _displayTrip != null && _displayTrip!.availableSeats > 0
          ? _buildBookButton(loc)
          : null,
    );
  }

  Widget _buildTripDetails(AppLocalizations loc) {
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
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    loc.t('trip.details.schedule'),
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
                  Text(
                    loc.t('trip.details.vehicle_details'),
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
                        loc.tReplace('trip.details.seats_available', {
                          'a': '${_displayTrip!.availableSeats}',
                          't': '${_displayTrip!.totalSeats}',
                        }),
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

          // Driver Card – tap avatar/name to see ratings; Message via WhatsApp (no number shown)
          if (_displayTrip!.driver != null)
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      loc.t('trip.details.driver_section'),
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
                              _displayTrip!.driver!.name[0].toUpperCase(),
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
                                      Icon(Icons.verified, color: Colors.blue[700], size: 20),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Tap to see ratings & reviews',
                                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
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
                    if (_userBookingStatus == 'confirmed' &&
                        _displayTrip!.driver!.contactNumber != null &&
                        _displayTrip!.driver!.contactNumber!.trim().isNotEmpty) ...[
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: () => launchWhatsApp(_displayTrip!.driver!.contactNumber),
                        icon: const Icon(Icons.chat, size: 18),
                        label: Text(loc.t('trip.details.whatsapp')),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.green[700],
                          side: BorderSide(color: Colors.green[700]!),
                        ),
                      ),
                    ] else if (_userBookingStatus == 'pending') ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.orange[50],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.orange[200]!),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.lock_clock, size: 16, color: Colors.orange[700]),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Booking pending — driver contact will be shared once confirmed.',
                                style: TextStyle(fontSize: 12, color: Colors.orange[800]),
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
                  Text(
                    loc.t('trip.details.fare_per_seat'),
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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

  Widget _buildBookButton(AppLocalizations loc) {
    return Container(
      padding: const EdgeInsets.all(16),
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
          onPressed: () async {
            final authProvider = context.read<AuthProvider>();
            if (widget.requireLogin && !authProvider.isAuthenticated) {
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: Text(loc.t('trip.details.login_required_title')),
                  content: Text(loc.t('trip.details.login_required_body')),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx), child: Text(loc.t('app.cancel'))),
                    TextButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const SimpleLoginScreen()),
                        );
                      },
                      child: Text(loc.t('trip.details.login_cta')),
                    ),
                  ],
                ),
              );
              return;
            }
            // Independent driver: open seat selection (dynamic layout by trip totalSeats)
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
    );
  }

}

class _DriverRatingRow extends StatelessWidget {
  final String driverId;
  final String driverName;

  const _DriverRatingRow({required this.driverId, required this.driverName});

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    return FutureBuilder<Map<String, dynamic>>(
      future: ReviewService().getUserRatingSummary(driverId),
      builder: (context, snapshot) {
        final total = (snapshot.data?['total_ratings'] as num?)?.toInt() ?? 0;
        final avg = (snapshot.data?['average_rating'] as num?)?.toDouble();
        final avgStr = total > 0 && avg != null ? avg.toStringAsFixed(1) : null;
        return Row(
          children: [
            if (snapshot.connectionState == ConnectionState.waiting)
              const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(strokeWidth: 2))
            else if (total > 0 && avgStr != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
                    Text('$avgStr ($total)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.amber[900])),
                  ],
                ),
              )
            else
              Text(loc.t('trip.details.no_ratings'), style: TextStyle(fontSize: 13, color: Colors.grey[600])),
            const SizedBox(width: 12),
            TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => UserReviewsScreen(userId: driverId, displayName: driverName),
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
