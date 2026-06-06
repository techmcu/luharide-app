import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/feedback/app_feedback.dart';
import '../../../../models/trip_model.dart';
import '../../../../providers/auth_provider.dart';
import '../../../../services/trip_service.dart';
import '../../../../services/union_service.dart';
import '../../../../utils/phone_call_helper.dart';
import '../../../../utils/trip_self_book_guard.dart';
import '../../../../widgets/shimmer_trip_card.dart';
import '../../../auth/presentation/screens/simple_login_screen.dart';
import '../../../../widgets/brand_app_bar_title.dart';
import 'trip_details_screen.dart';

// ── Palette constants ────────────────────────────────────────────────────────
const _kBlue   = Color(0xFF2563EB);
const _kGreen  = Color(0xFF16A34A);
const _kWa     = Color(0xFF25D366);
const _kRed    = Color(0xFFDC2626);
const _kBg     = Color(0xFFF8FAFC);
const _kCard   = Colors.white;

// ── Utility helpers (pure functions – no state) ─────────────────────────────
Future<void> _launchPhone(BuildContext context, String phone, {String? driverId, String? unionId}) async {
  if (driverId != null && unionId != null) {
    UnionService().logContact(driverId: driverId, unionId: unionId, contactType: 'call');
  }
  await launchPhoneCall(context, phone);
}

Future<void> _launchWhatsApp(String raw, {String? driverId, String? unionId}) async {
  if (raw.trim().isEmpty) return;
  if (driverId != null && unionId != null) {
    UnionService().logContact(driverId: driverId, unionId: unionId, contactType: 'whatsapp');
  }
  final number = raw.replaceAll(RegExp(r'\s+'), '');
  final uri = Uri.parse('https://wa.me/$number');
  if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
}

// ── Auth guard – check login before contacting driver ───────────────────────
void _guardedContact(BuildContext ctx, VoidCallback action) {
  final isLoggedIn = Provider.of<AuthProvider>(ctx, listen: false).isAuthenticated;
  if (isLoggedIn) {
    action();
  } else {
    _showLoginDialog(ctx);
  }
}

void _showLoginDialog(BuildContext ctx) {
  showDialog(
    context: ctx,
    builder: (dialogCtx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Row(
        children: [
          Icon(Icons.lock_rounded, color: _kBlue, size: 22),
          SizedBox(width: 8),
          Text('Login Required', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
        ],
      ),
      content: const Text(
        'You need to be logged in to contact the driver.',
        style: TextStyle(fontSize: 14, color: Colors.black87),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogCtx),
          child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: _kBlue,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          onPressed: () {
            Navigator.pop(dialogCtx);
            Navigator.push(ctx, MaterialPageRoute(builder: (_) => const SimpleLoginScreen()));
          },
          child: const Text('Login', style: TextStyle(fontWeight: FontWeight.w700)),
        ),
      ],
    ),
  );
}

// ── Route header widget (shared between both card types) ────────────────────
class _RouteRow extends StatelessWidget {
  const _RouteRow({required this.from, required this.to});
  final String from;
  final String to;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Column(
          children: [
            const Icon(Icons.trip_origin, color: _kGreen, size: 18),
            Container(
              width: 2,
              height: 22,
              margin: const EdgeInsets.symmetric(vertical: 2),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [_kGreen, _kRed],
                ),
                borderRadius: BorderRadius.circular(1),
              ),
            ),
            const Icon(Icons.location_on, color: _kRed, size: 18),
          ],
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                from,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 16),
              Text(
                to,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
}


class _IconBtn extends StatelessWidget {
  const _IconBtn({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });
  final IconData icon;
  final String   label;
  final Color    color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: onTap == null ? Colors.grey[100] : color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: onTap == null ? Colors.grey : color),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: onTap == null ? Colors.grey : color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Driver trip card ─────────────────────────────────────────────────────────
class _TripCard extends StatelessWidget {
  const _TripCard({required this.trip, required this.onBook});
  final TripModel trip;
  final VoidCallback onBook;

  @override
  Widget build(BuildContext context) {
    final driver = trip.driver;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.07), blurRadius: 12, offset: const Offset(0, 3)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Independent driver label
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: _kBlue.withValues(alpha: 0.08),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                Icon(Icons.directions_car_filled_rounded, size: 18, color: _kBlue),
                const SizedBox(width: 8),
                Text('Independent driver • Book on app', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _kBlue)),
              ],
            ),
          ),
          // Fare + seats
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.currency_rupee, size: 20, color: _kBlue),
                    Text(
                      trip.farePerSeat.toStringAsFixed(0),
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: _kBlue),
                    ),
                  ],
                ),
                Row(
                  children: [
                    const Icon(Icons.event_seat, size: 18, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text(
                      '${trip.availableSeats} / ${trip.totalSeats} seats',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: trip.availableSeats > 0 ? _kGreen : _kRed),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: _RouteRow(from: trip.fromLocation, to: trip.toLocation),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: Wrap(
              spacing: 16,
              runSpacing: 6,
              children: [
                _MetaChip(icon: Icons.access_time_rounded, label: trip.formattedDepartureTime),
                if (trip.formattedDuration != 'N/A')
                  _MetaChip(icon: Icons.timer_rounded, label: trip.formattedDuration),
                if (driver != null && driver.name.isNotEmpty)
                  _MetaChip(icon: Icons.person_rounded, label: driver.name),
                if (trip.vehicleNumber != null && trip.vehicleNumber!.isNotEmpty)
                  _MetaChip(icon: Icons.directions_car_rounded, label: trip.vehicleNumber!),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: onBook,
                icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                label: const Text('View Details & Book', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kBlue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  elevation: 0,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Union ride card ──────────────────────────────────────────────────────────
class _UnionCard extends StatelessWidget {
  const _UnionCard({required this.ride});
  final Map<String, dynamic> ride;

  static DateTime? _parseTime(dynamic raw) {
    if (raw is String) {
      final s = raw.trim();
      if (s.isEmpty) return null;
      final withZ = (s.endsWith('Z') || s.contains('+')) ? s : '${s}Z';
      return DateTime.tryParse(withZ)?.toLocal();
    }
    if (raw is DateTime) return raw.toLocal();
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final from        = (ride['from_location'] ?? '').toString();
    final to          = (ride['to_location'] ?? '').toString();
    final unionName   = (ride['union_name'] ?? '').toString();
    final driverName  = (ride['driver_name'] ?? '').toString();
    final vehicle     = (ride['vehicle_number'] ?? '').toString();
    final phone       = (ride['phone'] ?? '').toString();
    final whatsapp    = (ride['whatsapp_number'] ?? '').toString();
    final departure   = _parseTime(ride['departure_time']);
    final unionDriverId = ride['union_driver_id']?.toString();
    final unionId       = ride['union_id']?.toString();

    final timeText = departure != null
        ? DateFormat('dd MMM • hh:mm a').format(departure)
        : 'Time N/A';

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.07), blurRadius: 12, offset: const Offset(0, 3)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Union ride label
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: const BoxDecoration(
              color: Color(0xFFFFF7ED),
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                const Icon(Icons.business_rounded, size: 15, color: Colors.orange),
                const SizedBox(width: 6),
                Text('Union ride', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.orange[800])),
                if (unionName.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      unionName,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.orange),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: _RouteRow(from: from, to: to),
          ),
          // ── Meta ────────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: Wrap(
              spacing: 16,
              runSpacing: 6,
              children: [
                _MetaChip(icon: Icons.access_time_rounded, label: timeText),
                if (driverName.isNotEmpty) _MetaChip(icon: Icons.person_rounded, label: driverName),
                if (vehicle.isNotEmpty)    _MetaChip(icon: Icons.directions_car_rounded, label: vehicle),
              ],
            ),
          ),
          // ── Contact buttons ──────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: _ContactButtonsWithLog(
              phone: phone,
              whatsapp: whatsapp,
              unionDriverId: unionDriverId,
              unionId: unionId,
            ),
          ),
        ],
      ),
    );
  }
}

class _ContactButtonsWithLog extends StatelessWidget {
  const _ContactButtonsWithLog({
    required this.phone,
    required this.whatsapp,
    this.unionDriverId,
    this.unionId,
  });
  final String phone;
  final String whatsapp;
  final String? unionDriverId;
  final String? unionId;

  @override
  Widget build(BuildContext context) {
    final hasPhone = phone.trim().isNotEmpty;
    final effectiveWa = whatsapp.trim().isNotEmpty ? whatsapp : phone;
    final hasWa = effectiveWa.trim().isNotEmpty;

    if (!hasPhone && !hasWa) return const SizedBox.shrink();

    return Row(
      children: [
        if (hasPhone) ...[
          Expanded(
            child: _IconBtn(
              icon: Icons.call_rounded,
              label: 'Call',
              color: _kGreen,
              onTap: () => _guardedContact(
                context,
                () => _launchPhone(context, phone, driverId: unionDriverId, unionId: unionId),
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
        if (hasWa)
          Expanded(
            child: _IconBtn(
              icon: Icons.chat_rounded,
              label: 'WhatsApp',
              color: _kWa,
              onTap: () => _guardedContact(
                context,
                () => _launchWhatsApp(effectiveWa, driverId: unionDriverId, unionId: unionId),
              ),
            ),
          ),
      ],
    );
  }
}

// ── Tiny meta chip (time / driver / vehicle) ─────────────────────────────────
class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.icon, required this.label});
  final IconData icon;
  final String   label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: Colors.grey[500]),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 13, color: Colors.grey[700])),
      ],
    );
  }
}

// ── Section header ────────────────────────────────────────────────────────────
class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label, required this.count});
  final String label;
  final int    count;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.black87)),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(color: _kBlue.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
            child: Text('$count', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _kBlue)),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// Main screen
// ════════════════════════════════════════════════════════════════════════════

class SearchTripsScreen extends StatefulWidget {
  const SearchTripsScreen({super.key});

  @override
  State<SearchTripsScreen> createState() => _SearchTripsScreenState();
}

class _SearchTripsScreenState extends State<SearchTripsScreen> {
  final _tripService   = TripService();
  final _fromCtrl      = TextEditingController();
  final _toCtrl        = TextEditingController();
  DateTime  _date      = DateTime.now();
  List<TripModel>   _trips      = [];
  List<dynamic>     _unionRides = [];
  bool _loading  = false;
  bool _searched = false;
  CancelToken? _searchCancelToken;
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCancelToken?.cancel('disposed');
    _fromCtrl.dispose();
    _toCtrl.dispose();
    super.dispose();
  }

  // ── Date picker ─────────────────────────────────────────────────────────
  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 90)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(colorScheme: const ColorScheme.light(primary: _kBlue)),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _date = picked);
  }

  // ── Debounced search (300ms) to prevent rapid-fire API calls ──────────
  void _debouncedSearch() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), _search);
  }

  // ── Search ───────────────────────────────────────────────────────────────
  Future<void> _search() async {
    final from = _fromCtrl.text.trim();
    final to   = _toCtrl.text.trim();
    if (from.isEmpty || to.isEmpty) {
      AppFeedback.show(
        context,
        'Please enter both From and To locations',
        kind: AppFeedbackKind.warning,
      );
      return;
    }

    // Cancel any in-flight search before starting a new one
    _searchCancelToken?.cancel('new search');
    _searchCancelToken = CancelToken();

    setState(() { _loading = true; _searched = true; });

    final result = await _tripService.searchTrips(
      from: from, to: to, date: _date,
      cancelToken: _searchCancelToken,
    );

    if (!mounted) return;
    if (result['cancelled'] == true) return;

    setState(() {
      _loading    = false;
      _trips      = List<TripModel>.from(result['trips'] ?? []);
      _unionRides = List<dynamic>.from(result['unionRides'] ?? []);
    });

    if (result['success'] != true) {
      AppFeedback.show(
        context,
        result['message'] ?? 'Search failed',
        kind: AppFeedbackKind.error,
      );
    }
  }

  // ── Build ────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: _kBg,
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        centerTitle: false,
        title: const BrandAppBarTitle(
          onColoredBar: true,
          title: Text('Find a Ride', style: TextStyle(fontWeight: FontWeight.w700)),
        ),
        backgroundColor: _kBlue,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SafeArea(
        top: false,
        child: NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) => [
            SliverToBoxAdapter(child: _buildSearchForm(t)),
          ],
          body: _buildResultsScrollable(),
        ),
      ),
    );
  }

  // ── Search form ──────────────────────────────────────────────────────────
  Widget _buildSearchForm(AppLocalizations t) {
    return Container(
      color: _kBlue,
      child: Container(
        margin: const EdgeInsets.only(top: 1),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(0)),
        ),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
        child: Column(
          children: [
            // From
            _LocationField(
              controller: _fromCtrl,
              label: t.t('ride.from.label'),
              hint: t.t('ride.from.placeholder'),
              icon: Icons.trip_origin,
              iconColor: _kGreen,
              tripService: _tripService,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 10),
            // To
            _LocationField(
              controller: _toCtrl,
              label: t.t('ride.to.label'),
              hint: t.t('ride.to.placeholder'),
              icon: Icons.location_on,
              iconColor: _kRed,
              tripService: _tripService,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _debouncedSearch(),
            ),
            const SizedBox(height: 10),
            // Date row
            Row(
              children: [
                Expanded(child: _buildDateTile()),
                const SizedBox(width: 10),
                // Search button
                SizedBox(
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: _loading ? null : _debouncedSearch,
                    icon: _loading
                        ? const SizedBox(
                            width: 16, height: 16,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : const Icon(Icons.search_rounded),
                    label: const Text('Search', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _kBlue,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateTile() {
    return InkWell(
      onTap: _pickDate,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey[300]!),
          borderRadius: BorderRadius.circular(12),
          color: const Color(0xFFF8FAFC),
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_today_rounded, size: 18, color: _kBlue),
            const SizedBox(width: 8),
            Text(
              DateFormat('dd MMM, yyyy').format(_date),
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  // ── Results: scrollable body for NestedScrollView (search form + results scroll together
  // when keyboard is open so fields stay reachable). ───────────────────────
  Widget _buildResultsScrollable() {
    if (!_searched) {
      return CustomScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        slivers: [
          SliverFillRemaining(
            hasScrollBody: false,
            child: _buildEmptyState(
              icon: Icons.search_rounded,
              title: 'Search for rides',
              subtitle: 'Enter locations above and tap Search',
            ),
          ),
        ],
      );
    }
    if (_loading) {
      return CustomScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            sliver: SliverToBoxAdapter(child: ShimmerTripCards(count: 3)),
          ),
        ],
      );
    }
    if (_trips.isEmpty && _unionRides.isEmpty) {
      return CustomScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        slivers: [
          SliverFillRemaining(
            hasScrollBody: false,
            child: _buildEmptyState(
              icon: Icons.directions_car_outlined,
              title: 'No rides found',
              subtitle: 'Try different locations or a different date',
            ),
          ),
        ],
      );
    }

    final children = <Widget>[
      if (_trips.isNotEmpty) ...[
        _SectionLabel(label: 'Independent driver rides', count: _trips.length),
        ..._trips.map((t) => _TripCard(
              trip: t,
              onBook: () {
                final uid = context.read<AuthProvider>().user?.id;
                if (t.isCreatedByUserId(uid)) {
                  showCannotBookOwnTripDialog(context);
                  return;
                }
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => TripDetailsScreen(tripId: t.id, initialTrip: t)),
                );
              },
            )),
        const SizedBox(height: 8),
      ],
      if (_unionRides.isNotEmpty) ...[
        _SectionLabel(label: 'Union scheduled rides', count: _unionRides.length),
        ..._unionRides.map((r) => _UnionCard(ride: r as Map<String, dynamic>)),
      ],
    ];

    return CustomScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          sliver: SliverList(delegate: SliverChildListDelegate(children)),
        ),
      ],
    );
  }

  Widget _buildEmptyState({required IconData icon, required String title, required String subtitle}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 72, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.black54)),
            const SizedBox(height: 6),
            Text(subtitle, style: TextStyle(fontSize: 14, color: Colors.grey[500]), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class _LocationField extends StatelessWidget {
  const _LocationField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    required this.iconColor,
    required this.tripService,
    this.textInputAction,
    this.onSubmitted,
  });
  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final Color iconColor;
  final TripService tripService;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    final kb = MediaQuery.viewInsetsOf(context).bottom;
    return TypeAheadField<String>(
      controller: controller,
      debounceDuration: const Duration(milliseconds: 300),
      hideOnEmpty: true,
      hideOnLoading: true,
      hideOnError: true,
      constraints: const BoxConstraints(maxHeight: 200),
      decorationBuilder: (context, child) => Material(
        type: MaterialType.card,
        elevation: 4,
        borderRadius: BorderRadius.circular(12),
        child: ClipRRect(borderRadius: BorderRadius.circular(12), child: child),
      ),
      builder: (context, controller, focusNode) => TextField(
        controller: controller,
        focusNode: focusNode,
        textCapitalization: TextCapitalization.words,
        textInputAction: textInputAction,
        onSubmitted: onSubmitted,
        enableSuggestions: false,
        autocorrect: false,
        autofillHints: const [],
        maxLength: 100,
        buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
        scrollPadding: EdgeInsets.only(bottom: 24 + kb),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          prefixIcon: Icon(icon, color: iconColor, size: 20),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey[300]!)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey[300]!)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _kBlue, width: 1.5)),
          filled: true,
          fillColor: const Color(0xFFF8FAFC),
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          labelStyle: TextStyle(color: Colors.grey[600]),
          isDense: true,
        ),
      ),
      suggestionsCallback: (search) => tripService.getLocationSuggestions(search),
      itemBuilder: (context, suggestion) => ListTile(
        leading: Icon(Icons.location_on_outlined, color: Colors.grey[400], size: 20),
        title: Text(suggestion, style: const TextStyle(fontSize: 14)),
        dense: true,
        visualDensity: VisualDensity.compact,
      ),
      onSelected: (suggestion) => controller.text = suggestion,
    );
  }
}
