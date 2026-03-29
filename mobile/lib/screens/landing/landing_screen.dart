import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/brand_config.dart';
import '../../core/localization/app_localizations.dart';
import '../../providers/app_language_provider.dart';
import '../../models/trip_model.dart';
import '../../providers/auth_provider.dart';
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

  List<TripModel> _searchResults = [];
  List<dynamic> _unionRides = [];
  bool _isSearching = false;
  bool _hasSearched = false;

  @override
  void dispose() {
    _fromController.dispose();
    _toController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  bool _isSameCalendarDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  /// Avoids overscroll / assertion on short screens or before layout.
  Future<void> _animateScrollClamped(double preferredOffset, {required int delayMs, required int durationMs}) async {
    await Future.delayed(Duration(milliseconds: delayMs));
    if (!mounted || !_scrollController.hasClients) return;
    final max = _scrollController.position.maxScrollExtent;
    final target = preferredOffset.clamp(0.0, max);
    await _scrollController.animateTo(
      target,
      duration: Duration(milliseconds: durationMs),
      curve: Curves.easeInOutCubic,
    );
  }

  Future<void> _searchTrips() async {
    final loc = AppLocalizations.of(context);
    if (_fromController.text.trim().isEmpty || _toController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(loc.t('landing.both_locations')),
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

    // Show ALL rides returned by backend — no client-side time filtering.
    // Backend already handles the date range. Hiding past-time rides caused missed results.
    setState(() {
      _isSearching = false;
      _searchResults = List<TripModel>.from(result['trips'] ?? []);
      _unionRides   = List<dynamic>.from(result['unionRides'] ?? []);
    });

    if (_searchResults.isNotEmpty && mounted) {
      await _animateScrollClamped(440, delayMs: 400, durationMs: 1100);
    } else if (_hasSearched && _searchResults.isEmpty && mounted) {
      await _animateScrollClamped(420, delayMs: 250, durationMs: 900);
    }

    if (!result['success'] && mounted) {
      final msg = result['message']?.toString();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text((msg != null && msg.isNotEmpty) ? msg : loc.t('landing.search_failed')),
          backgroundColor: Colors.red,
        ),
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

  /// Auth-guarded contact: launch if logged in, show login dialog if not.
  void _guardedContact(VoidCallback action) {
    final isLoggedIn =
        Provider.of<AuthProvider>(context, listen: false).isAuthenticated;
    if (isLoggedIn) {
      action();
    } else {
      final loc = AppLocalizations.of(context);
      showDialog(
        context: context,
        builder: (dialogCtx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              const Icon(Icons.lock_rounded, color: Color(0xFF2563EB), size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  loc.t('landing.contact.login_title'),
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          content: Text(
            loc.t('landing.contact.login_body'),
            style: const TextStyle(fontSize: 14),
          ),
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: Text(loc.t('app.cancel'), style: const TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () {
                Navigator.pop(dialogCtx);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const SimpleLoginScreen()),
                );
              },
              child: Text(
                loc.t('trip.details.login_cta'),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    context.watch<AppLanguageProvider>();
    final loc = AppLocalizations.of(context);
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
                        Text(
                          BrandConfig.appName,
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w600,
                            color: Colors.blue[800],
                            letterSpacing: 0.2,
                          ),
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
                              child: Text(loc.t('auth.login.title'), style: const TextStyle(fontWeight: FontWeight.w400, fontSize: 14)),
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
                                  BoxShadow(color: Colors.blue.withValues(alpha: 0.35), blurRadius: 10, offset: const Offset(0, 3)),
                                ],
                              ),
                              child: TextButton(
                                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SimpleSignupScreen())),
                                style: TextButton.styleFrom(
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                ),
                                child: Text(loc.t('landing.header.signup'), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: MediaQuery.of(context).size.height * 0.08),
                  // Search box - centered a bit lower on screen
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 20,
                            offset: const Offset(0, 6),
                          ),
                          BoxShadow(
                            color: Colors.blue.withValues(alpha: 0.04),
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
                              label: loc.t('ride.from.label'),
                              icon: Icons.trip_origin_rounded,
                              iconColor: Colors.green[400]!,
                              tripService: _tripService,
                            ),
                            const SizedBox(height: 14),
                            _LocationField(
                              controller: _toController,
                              label: loc.t('ride.to.label'),
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
                                      _isSameCalendarDay(_selectedDate, DateTime.now())
                                          ? loc.t('landing.date.today')
                                          : DateFormat('EEE, d MMM').format(_selectedDate),
                                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w400, color: Colors.grey[800]),
                                    ),
                                    const Spacer(),
                                    Icon(Icons.keyboard_arrow_down_rounded, color: Colors.grey[400], size: 22),
                                  ],
                                ),
                              ),
                            ),
                            // Passenger count removed for simpler flow (ride is per passenger token).
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
                                  BoxShadow(color: Colors.blue.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 3)),
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
                                    : Text(loc.t('landing.search.cta'), style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, letterSpacing: 0.3)),
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
                    loc.t('landing.tagline'),
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
                          Text(loc.t('landing.results.title'), style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.grey[800])),
                          if (_searchResults.isNotEmpty)
                            Text(
                              loc.tReplace('landing.results.count', {'n': '${_searchResults.length}'}),
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w400, color: Colors.grey[600]),
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      if (_searchResults.isEmpty && _unionRides.isEmpty)
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.all(32),
                            child: Column(
                              children: [
                                Icon(Icons.search_off, size: 56, color: Colors.grey[300]),
                                const SizedBox(height: 16),
                                Text(loc.t('landing.results.empty'), style: TextStyle(fontSize: 16, fontWeight: FontWeight.w400, color: Colors.grey[500])),
                              ],
                            ),
                          ),
                        )
                      else ...[
                        if (_searchResults.isNotEmpty) ...[
                          Text(
                            loc.t('landing.section.independent'),
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[700],
                            ),
                          ),
                          const SizedBox(height: 8),
                          ..._searchResults.map((trip) => _buildTripCard(loc, trip)),
                          const SizedBox(height: 16),
                        ],
                        if (_unionRides.isNotEmpty) ...[
                          Text(
                            loc.t('landing.section.union'),
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[700],
                            ),
                          ),
                          const SizedBox(height: 8),
                          ..._unionRides.map((ride) => _buildUnionRideCard(loc, ride as Map<String, dynamic>)),
                        ],
                      ],
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
                      // LuhaRide + tagline (primary), then small powered-by line
                      Text(
                        loc.t('brand.footer.app_line'),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          color: Colors.blue[800],
                          letterSpacing: 0.3,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        loc.t('brand.footer.tagline'),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey[600],
                          letterSpacing: 0.4,
                          height: 1.25,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        loc.brandFooterParentLine,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w400,
                          color: Colors.grey[500],
                          letterSpacing: 0.35,
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

  Widget _buildTripCard(AppLocalizations loc, TripModel trip) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Independent driver label
            Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue[200]!),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.directions_car_rounded, size: 16, color: Colors.blue[700]),
                  const SizedBox(width: 6),
                  Text(loc.t('landing.card.independent_tag'), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.blue[800])),
                ],
              ),
            ),
            Row(children: [
              const Icon(Icons.trip_origin, color: Colors.green, size: 20),
              const SizedBox(width: 8),
              Expanded(child: Text(trip.fromLocation, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
            ]),
            const SizedBox(height: 8),
            Row(children: [
              const Icon(Icons.location_on, color: Colors.red, size: 20),
              const SizedBox(width: 8),
              Expanded(child: Text(trip.toLocation, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
            ]),
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.access_time, size: 18, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text(trip.formattedDepartureTime, style: const TextStyle(fontSize: 14)),
                  ],
                ),
                Row(
                  children: [
                    const Icon(Icons.event_seat, size: 18, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text(
                      loc.tReplace('landing.card.seats', {
                        'a': '${trip.availableSeats}',
                        't': '${trip.totalSeats}',
                      }),
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: trip.availableSeats > 0 ? Colors.green : Colors.red),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.currency_rupee, size: 20, color: Colors.blue),
                Text(
                  trip.farePerSeat.toStringAsFixed(0),
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.blue),
                ),
              ],
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => _onTripTap(trip),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), padding: const EdgeInsets.symmetric(vertical: 12)),
                child: Text(loc.t('landing.card.book'), style: const TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUnionRideCard(AppLocalizations loc, Map<String, dynamic> ride) {
    final from = (ride['from_location'] ?? '').toString();
    final to = (ride['to_location'] ?? '').toString();
    final unionName = (ride['union_name'] ?? '').toString();
    final driverName = (ride['driver_name'] ?? '').toString();
    final vehicleNumber = (ride['vehicle_number'] ?? '').toString();
    final phone = (ride['phone'] ?? '').toString();
    final whatsapp = (ride['whatsapp_number'] ?? '').toString();

    // UTC-safe parsing: backend stores UTC without 'Z' suffix
    DateTime? departure;
    final rawDt = ride['departure_time'];
    if (rawDt is String && rawDt.isNotEmpty) {
      final withZ = (rawDt.endsWith('Z') || rawDt.contains('+')) ? rawDt : '${rawDt}Z';
      departure = DateTime.tryParse(withZ)?.toLocal();
    } else if (rawDt is DateTime) {
      departure = rawDt.toLocal();
    }

    final departureText = departure != null
        ? DateFormat('dd MMM yyyy • hh:mm a').format(departure)
        : loc.t('landing.union.time_na');

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Union ride label
            Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF7ED),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange[200]!),
              ),
              child: Row(
                children: [
                  const Icon(Icons.business_rounded, size: 16, color: Colors.orange),
                  const SizedBox(width: 6),
                  Text(loc.t('landing.union.tag'), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.orange[800])),
                  if (unionName.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Expanded(child: Text(unionName, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.orange), maxLines: 1, overflow: TextOverflow.ellipsis)),
                  ],
                ],
              ),
            ),
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
            Row(children: [
              if (phone.isNotEmpty) ...[
                Expanded(child: _contactBtn(Icons.call_rounded, loc.t('landing.contact.call'), const Color(0xFF16A34A), () => _guardedContact(() => _launchPhone(phone)))),
                const SizedBox(width: 8),
              ],
              if ((whatsapp.isNotEmpty || phone.isNotEmpty))
                Expanded(child: _contactBtn(Icons.chat_rounded, loc.t('landing.contact.whatsapp'), const Color(0xFF25D366), () => _guardedContact(() => _launchWhatsApp(whatsapp.isNotEmpty ? whatsapp : phone)))),
            ]),
          ],
        ),
      ),
    );
  }

  Future<void> _launchPhone(String phone) async {
    final uri = Uri(scheme: 'tel', path: phone.trim());
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  Future<void> _launchWhatsApp(String raw) async {
    if (raw.trim().isEmpty) return;
    final number = raw.replaceAll(RegExp(r'\s+'), '');
    final uri = Uri.parse('https://wa.me/$number');
    if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Widget _contactBtn(IconData icon, String label, Color color, VoidCallback onTap) {
    return Material(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 17, color: color),
              const SizedBox(width: 5),
              Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: color)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Plain location input — no suggestions, no autocomplete, no TypeAhead.
class _LocationField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final Color iconColor;
  // tripService kept in signature for backward compatibility but not used for suggestions
  final TripService? tripService;

  const _LocationField({
    required this.controller,
    required this.label,
    required this.icon,
    required this.iconColor,
    this.tripService,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      textCapitalization: TextCapitalization.words,
      enableSuggestions: false,
      autocorrect: false,
      autofillHints: const [],
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: iconColor, size: 22),
        border: InputBorder.none,
        contentPadding: const EdgeInsets.symmetric(vertical: 14),
        labelStyle: TextStyle(fontSize: 15, fontWeight: FontWeight.w400, color: Colors.grey[600]),
      ),
      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w400, color: Colors.grey[800]),
    );
  }
}
