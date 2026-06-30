import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../providers/auth_provider.dart';
import '../../../../providers/app_language_provider.dart';
import '../../../../widgets/brand_app_bar_title.dart';
import '../../../../core/brand_config.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../models/trip_model.dart';
import '../../../../models/picked_location.dart';
import '../../../../utils/phone_call_helper.dart';
import '../../../../utils/trip_self_book_guard.dart';
import '../../../../services/trip_service.dart';
import '../../../../services/union_service.dart';
import '../../../../services/notification_service.dart';
import '../../../trips/presentation/screens/trip_details_screen.dart';
import '../../../trips/presentation/screens/passenger_my_rides_screen.dart';
import '../../../trips/presentation/screens/create_trip_screen.dart';
import '../../../trips/presentation/screens/my_rides_screen.dart';
import '../../../profile/presentation/screens/profile_screen.dart';
import '../../../profile/presentation/screens/driver_verification_form_screen.dart';
import '../../../notifications/presentation/screens/notifications_screen.dart';
import '../../../../core/feedback/app_feedback.dart';
import '../../../../widgets/location_picker_screen.dart';

class PassengerHomeScreen extends StatefulWidget {
  const PassengerHomeScreen({super.key});

  @override
  State<PassengerHomeScreen> createState() => _PassengerHomeScreenState();
}

class _PassengerHomeScreenState extends State<PassengerHomeScreen> {
  final _tripService = TripService();
  final _fromController = TextEditingController();
  final _toController = TextEditingController();
  // Coordinates captured from autocomplete (null → text search fallback).
  double? _fromLat, _fromLng, _toLat, _toLng;
  final _scrollController = ScrollController();
  DateTime _selectedDate = DateTime.now();

  List<TripModel> _searchResults = [];
  List<Map<String, dynamic>> _unionSearchResults = const [];
  bool _isSearching = false;
  bool _hasSearched = false;
  final _notificationService = NotificationService();
  int _unreadNotificationCount = 0;
  bool _isNavigating = false;
  Timer? _debounceSearch;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadNotificationsOnce());
  }

  /// Single API call for both verification snackbar and unread badge — no duplicate requests.
  Future<void> _loadNotificationsOnce() async {
    final user = context.read<AuthProvider>().user;
    final role = (user?.role ?? '').toString().toLowerCase();
    final result = await _notificationService.getNotifications();
    if (!result['success'] || !mounted) return;
    final list = result['notifications'] as List? ?? [];
    final unreadList = list.where((n) => n is Map && (n['is_read'] != true)).toList();
    final unreadCount = unreadList.length;
    if (!mounted) return;
    setState(() => _unreadNotificationCount = unreadCount);
    if (role == 'union_admin' || role == 'admin') return;
    final verificationApproved = unreadList.any((n) => n is Map && n['type'] == 'verification_approved');
    if (verificationApproved && mounted) {
      context.read<AuthProvider>().refreshUser();
      AppFeedback.show(
        context,
        'Verification approved! You can now create rides.',
        kind: AppFeedbackKind.success,
        icon: Icons.check_circle_outline,
        duration: const Duration(seconds: 5),
      );
    }
  }

  @override
  void dispose() {
    _debounceSearch?.cancel();
    _fromController.dispose();
    _toController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  static String _avatarInitial(String? name) {
    if (name == null || name.trim().isEmpty) return 'P';
    return name.trim().substring(0, 1).toUpperCase();
  }

  static String _displayName(String? name) {
    final n = name?.trim();
    if (n == null || n.isEmpty) return 'User';
    return n.split(' ').first;
  }

  void _debouncedSearch() {
    _debounceSearch?.cancel();
    _debounceSearch = Timer(const Duration(milliseconds: 300), _searchTrips);
  }

  Future<void> _searchTrips() async {
    if (_fromController.text.trim().isEmpty || _toController.text.trim().isEmpty) {
      AppFeedback.show(
        context,
        'Please enter both From and To locations',
        kind: AppFeedbackKind.warning,
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
      fromLat: _fromLat, fromLng: _fromLng,
      toLat: _toLat, toLng: _toLng,
    );

    if (!mounted) return;
    // Show ALL rides the backend returns — no client-side time filtering.
    // Hiding past-time rides caused rides to disappear. Backend handles date range.
    final List<Map<String, dynamic>> unionRides = [];
    for (final r in (result['unionRides'] ?? result['union_rides'] ?? const []) as List<dynamic>) {
      if (r is Map) unionRides.add(r.cast<String, dynamic>());
    }
    setState(() {
      _isSearching = false;
      _searchResults = List<TripModel>.from(result['trips'] ?? []);
      _unionSearchResults = unionRides;
    });

    // Smooth auto-scroll to results (same as landing: so user sees where results are)
    final hasAnyResults = _searchResults.isNotEmpty || _unionSearchResults.isNotEmpty;
    if (mounted) {
      await Future.delayed(const Duration(milliseconds: 350));
      if (mounted) {
        final targetOffset = hasAnyResults ? 420.0 : 400.0;
        _scrollController.animateTo(
          targetOffset,
          duration: const Duration(milliseconds: 900),
          curve: Curves.easeInOutCubic,
        );
      }
    }

    if (!result['success'] && mounted) {
      AppFeedback.show(
        context,
        result['message'].toString(),
        kind: AppFeedbackKind.error,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    context.watch<AppLanguageProvider>();
    final authProvider = context.watch<AuthProvider>();
    final user = authProvider.user;
    final t = AppLocalizations.of(context);
    // Independent-driver create flow only; union admins manage rides from Union tab.
    final showCreateRideAction =
        (user?.role ?? '').toString().toLowerCase() != 'union_admin';

    return PopScope(
      canPop: _fromController.text.isEmpty && _toController.text.isEmpty,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (_toController.text.isNotEmpty) {
          _toController.clear();
          setState(() {
            _hasSearched = false;
            _searchResults = [];
            _unionSearchResults = const [];
          });
          return;
        }
        if (_fromController.text.isNotEmpty) {
          _fromController.clear();
          setState(() {});
          return;
        }
      },
      child: Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      appBar: AppBar(
        centerTitle: false,
        title: const BrandAppBarTitleAppName(),
        elevation: 0,
        backgroundColor: const Color(0xFFF8F9FB),
        foregroundColor: Colors.grey[800],
        actions: [
          if (showCreateRideAction)
            IconButton(
              icon: const Icon(Icons.add_circle_outline, size: 24),
              tooltip: 'Create ride',
              onPressed: () => _onCreateRideTap(context, user),
            ),
          IconButton(
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(Icons.notifications_outlined, size: 22),
                if (_unreadNotificationCount > 0)
                  Positioned(
                    right: -2,
                    top: -2,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 14,
                        minHeight: 14,
                      ),
                      child: Text(
                        _unreadNotificationCount > 9
                            ? '9+'
                            : '$_unreadNotificationCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
            onPressed: _isNavigating ? null : () async {
              setState(() => _isNavigating = true);
              try {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const NotificationsScreen(),
                  ),
                );
                _loadNotificationsOnce();
              } finally {
                if (mounted) setState(() => _isNavigating = false);
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.person_outline, size: 22),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ProfileScreen(userRole: 'passenger'),
                ),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        controller: _scrollController,
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Greeting + heading
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: const Color(0xFF2563EB).withValues(alpha: 0.08),
                    child: Text(
                      _avatarInitial(user?.name),
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF2563EB),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Hi, ${_displayName(user?.name).split(' ').first}',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Colors.grey[500]),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          'Where are you going?',
                          style: TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w800,
                            color: Colors.grey[900],
                            letterSpacing: -0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Search Box
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 20,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    const SizedBox(height: 14),
                    // From field
                    _buildLocationPickerField(
                      controller: _fromController,
                      icon: Icons.circle,
                      iconColor: const Color(0xFF22C55E),
                      iconSize: 10,
                      hint: 'Starting location',
                      label: t.t('ride.from.label'),
                      onPicked: (p) { _fromLat = p.lat; _fromLng = p.lng; },
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Divider(height: 1, color: Colors.grey[200]),
                    ),
                    // To field
                    _buildLocationPickerField(
                      controller: _toController,
                      icon: Icons.location_on_rounded,
                      iconColor: const Color(0xFFEF4444),
                      iconSize: 18,
                      hint: 'Enter destination',
                      label: t.t('ride.to.label'),
                      onPicked: (p) { _toLat = p.lat; _toLng = p.lng; },
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Divider(height: 1, color: Colors.grey[200]),
                    ),
                    // Date Selector
                    InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: _selectedDate,
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(const Duration(days: 30)),
                        );
                        if (date != null) {
                          setState(() => _selectedDate = date);
                        }
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_today_rounded, color: Color(0xFF2563EB), size: 18),
                            const SizedBox(width: 14),
                            Text(
                              DateFormat('EEE, dd MMM yyyy').format(_selectedDate),
                              style: TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w500,
                                color: Colors.grey[800],
                              ),
                            ),
                            const Spacer(),
                            Icon(Icons.keyboard_arrow_down_rounded, color: Colors.grey[400], size: 20),
                          ],
                        ),
                      ),
                    ),
                    // Search Button
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
                      child: SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          onPressed: _isSearching ? null : _debouncedSearch,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2563EB),
                            disabledBackgroundColor: const Color(0xFF93C5FD),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                          child: _isSearching
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2.5,
                                  ),
                                )
                              : const Text(
                                  'Search Rides',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                    letterSpacing: 0.2,
                                  ),
                                ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Search Results
            if (_hasSearched)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Search Results',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (_searchResults.isNotEmpty || _unionSearchResults.isNotEmpty)
                          Text(
                            '${_searchResults.length + _unionSearchResults.length} rides found',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    
                    if (_isSearching)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(32),
                          child: CircularProgressIndicator(),
                        ),
                      )
                    else if (_searchResults.isEmpty && _unionSearchResults.isEmpty)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            children: [
                              Icon(Icons.search_off, size: 60, color: Colors.grey[400]),
                              const SizedBox(height: 16),
                              Text(
                                'No trips found',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey[600],
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Try different locations or dates',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[500],
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Independent driver trips (book on app, seat selection)
                          if (_searchResults.isNotEmpty) ...[
                            Text(
                              'Independent driver rides',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey[800],
                              ),
                            ),
                            const SizedBox(height: 8),
                            ..._searchResults.map(
                              (trip) => _buildTripCard(trip, key: ValueKey(trip.id)),
                            ),
                            const SizedBox(height: 16),
                          ],
                          // Union-managed schedules (call only, no seat booking)
                          if (_unionSearchResults.isNotEmpty) ...[
                            Text(
                              'Union scheduled rides',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey[800],
                              ),
                            ),
                            const SizedBox(height: 8),
                            ..._unionSearchResults.map(
                              (ride) => _buildUnionRideCard(ride),
                            ),
                          ],
                        ],
                      ),
                  ],
                ),
              ),

            // Bottom system-bar inset is applied globally (main.dart SafeArea); keep
            // only the small keyboard-follow nudge here (viewPadding would double-pad).
            SizedBox(height: 12 + MediaQuery.viewInsetsOf(context).bottom * 0.3),
          ],
        ),
      ),
      bottomNavigationBar: _buildFooter(context),
    ),
    );
  }

  Widget _buildLocationPickerField({
    required TextEditingController controller,
    required IconData icon,
    required Color iconColor,
    required double iconSize,
    required String hint,
    required String label,
    ValueChanged<PickedLocation>? onPicked,
  }) {
    return GestureDetector(
      onTap: () async {
        final result = await Navigator.push<PickedLocation>(
          context,
          MaterialPageRoute(
            builder: (_) => LocationPickerScreen(
              title: label,
              initialValue: controller.text,
              tripService: _tripService,
            ),
          ),
        );
        if (result != null) {
          controller.text = result.name;
          onPicked?.call(result);
          setState(() {});
        }
      },
      child: AbsorbPointer(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 2),
          child: TextField(
            controller: controller,
            readOnly: true,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: Colors.black87),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14.5, fontWeight: FontWeight.w400),
              prefixIcon: Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Icon(icon, color: iconColor, size: iconSize),
              ),
              prefixIconConstraints: const BoxConstraints(minWidth: 30),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ),
      ),
    );
  }

  // Union ride card — shows union name, route, time, driver, and contact buttons.
  Widget _buildUnionRideCard(Map<String, dynamic> ride) {
    final from        = (ride['from_location']  ?? '').toString();
    final to          = (ride['to_location']    ?? '').toString();
    final unionName   = (ride['union_name']     ?? '').toString();
    final driverName  = (ride['driver_name']    ?? '').toString();
    final vehicleNo   = (ride['vehicle_number'] ?? '').toString();
    final phone       = (ride['phone']          ?? '').toString();
    final whatsapp    = (ride['whatsapp_number']?? '').toString();
    final unionDriverId = ride['union_driver_id']?.toString();
    final unionId       = ride['union_id']?.toString();

    // UTC-safe parsing: backend stores UTC without 'Z', add it before parsing
    final depRaw = ride['departure_time']?.toString() ?? '';
    DateTime? depTime;
    if (depRaw.isNotEmpty) {
      final withZ = (depRaw.endsWith('Z') || depRaw.contains('+')) ? depRaw : '${depRaw}Z';
      depTime = DateTime.tryParse(withZ)?.toLocal();
    }
    final timeLabel = depTime != null
        ? DateFormat('dd MMM yyyy • hh:mm a').format(depTime)
        : 'Time N/A';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.07), blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Union ride label + union name
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: const BoxDecoration(
              color: Color(0xFFFFF7ED),
              borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
            ),
            child: Row(children: [
              const Icon(Icons.business_rounded, size: 15, color: Colors.orange),
              const SizedBox(width: 6),
              Text('Union ride', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.orange[800])),
              if (unionName.isNotEmpty) ...[
                const SizedBox(width: 8),
                Expanded(child: Text(unionName, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.orange), maxLines: 1, overflow: TextOverflow.ellipsis)),
              ],
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Route
                Row(children: [
                  const Icon(Icons.trip_origin, color: Colors.green, size: 18),
                  const SizedBox(width: 8),
                  Expanded(child: Text(from, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis)),
                ]),
                const SizedBox(height: 6),
                Row(children: [
                  const Icon(Icons.location_on, color: Colors.red, size: 18),
                  const SizedBox(width: 8),
                  Expanded(child: Text(to, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis)),
                ]),
                const SizedBox(height: 10),
                // Meta chips
                Wrap(spacing: 14, runSpacing: 4, children: [
                  _metaChip(Icons.access_time_rounded, timeLabel),
                  if (driverName.isNotEmpty) _metaChip(Icons.person_rounded, driverName),
                  if (vehicleNo.isNotEmpty)  _metaChip(Icons.directions_car_rounded, vehicleNo),
                ]),
                if (phone.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(child: _contactBtn(Icons.call_rounded, 'Call', const Color(0xFF16A34A), () => _launchPhone(phone, driverId: unionDriverId, unionId: unionId))),
                    if (whatsapp.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Expanded(child: _contactBtn(Icons.chat_rounded, 'WhatsApp', const Color(0xFF25D366), () => _launchWhatsApp(whatsapp, driverId: unionDriverId, unionId: unionId))),
                    ],
                  ]),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _metaChip(IconData icon, String label) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 14, color: Colors.grey[500]),
      const SizedBox(width: 4),
      Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[700])),
    ],
  );

  void _onCreateRideTap(BuildContext context, user) {
    if ((user?.role ?? '').toString().toLowerCase() == 'union_admin') return;
    final status = user?.driverVerificationStatus ?? 'none';
    if (status == 'approved') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const CreateTripScreen()),
      ).then((_) {
        _searchTrips(); // Refresh after creating
      });
    } else if (status == 'pending') {
      final loc = AppLocalizations.of(context);
      _showVerifyPopup(
        context,
        loc.tReplace('profile.verify.pending_body', {'supportEmail': BrandConfig.supportEmail}),
        allowOpenForm: false,
      );
    } else {
      _showVerifyPopup(context, AppLocalizations.of(context).t('profile.verify.need_docs'));
    }
  }

  void _showVerifyPopup(BuildContext context, String message, {bool allowOpenForm = true}) {
    final loc = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.verified_user_outlined, color: Colors.orange[700], size: 28),
            const SizedBox(width: 10),
            Expanded(child: Text(loc.t('profile.verify.dialog_title'), style: const TextStyle(fontSize: 18))),
          ],
        ),
        content: Text(message),
        actions: [
          if (allowOpenForm)
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(loc.t('app.cancel')),
            ),
          if (!allowOpenForm)
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(loc.t('app.ok')))
          else
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                final auth = context.read<AuthProvider>();
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const DriverVerificationFormScreen()),
                ).then((refresh) {
                  if (refresh == true && mounted) {
                    auth.refreshUser();
                  }
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: Text(loc.t('profile.verify_docs_btn')),
            ),
        ],
      ),
    );
  }

  
  Widget _buildTripCard(TripModel trip, {Key? key}) {
    return Card(
      key: key,
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Independent driver label (book on app, seat selection)
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
                  Text('Independent driver • Book on app', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.blue[800])),
                ],
              ),
            ),
            // Route
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
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
                      const SizedBox(height: 8),
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
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 24),

            // Time and Seats
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.access_time, size: 18, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text(
                      trip.formattedDepartureTime,
                      style: const TextStyle(fontSize: 14),
                    ),
                  ],
                ),
                Row(
                  children: [
                    const Icon(Icons.event_seat, size: 18, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text(
                      '${trip.availableSeats} / ${trip.totalSeats} seats',
                      style: TextStyle(
                        fontSize: 14,
                        color: trip.availableSeats > 0 ? Colors.green : Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Fare and Driver
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.currency_rupee, size: 20, color: Colors.blue),
                    Text(
                      trip.farePerSeat.toStringAsFixed(0),
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                  ],
                ),
                if (trip.driver != null)
                  Row(
                    children: [
                      const Icon(Icons.person, size: 18, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text(
                        trip.driver!.name,
                        style: const TextStyle(fontSize: 14),
                      ),
                      if (trip.driver!.isVerified) ...[
                        const SizedBox(width: 4),
                        Icon(Icons.verified, color: Colors.blue[700], size: 16),
                      ],
                    ],
                  ),
              ],
            ),
            
            const SizedBox(height: 14),

            // Contact + Book
            Row(
              children: [
                if (trip.driver != null && (trip.driver!.phone ?? '').isNotEmpty)
                  _buildSmallContactBtn(
                    Icons.call_rounded,
                    const Color(0xFF16A34A),
                    () => _launchPhone(trip.driver!.phone!),
                  ),
                if (trip.driver != null && (trip.driver!.whatsappNumber ?? '').trim().isNotEmpty) ...[
                  const SizedBox(width: 8),
                  _buildSmallContactBtn(
                    Icons.chat_rounded,
                    const Color(0xFF25D366),
                    () => _launchWhatsApp(trip.driver!.whatsappNumber!),
                  ),
                ],
                if (trip.driver != null && (trip.driver!.phone ?? '').isNotEmpty)
                  const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () async {
                      final uid = context.read<AuthProvider>().user?.id;
                      if (trip.isCreatedByUserId(uid)) {
                        await showCannotBookOwnTripDialog(context);
                        return;
                      }
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => TripDetailsScreen(tripId: trip.id, initialTrip: trip),
                        ),
                      );
                      if (result == true && mounted) _searchTrips();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text(
                      'Book',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
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

  Future<void> _launchPhone(String phone, {String? driverId, String? unionId}) async {
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

  Widget _buildSmallContactBtn(IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(11),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, size: 20, color: color),
      ),
    );
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

  Widget _buildFooter(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    final isDriver = user?.isDriverVerified == true;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: _buildFooterItem(
                context,
                icon: Icons.book_online,
                label: 'My bookings',
                iconColor: Colors.orange[700]!,
                bgColor: Colors.orange[50]!,
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PassengerMyRidesScreen())),
              ),
            ),
            const SizedBox(width: 6),
            if (isDriver) ...[
              Expanded(
                child: _buildFooterItem(
                  context,
                  icon: Icons.route,
                  label: 'My rides',
                  iconColor: Colors.green[700]!,
                  bgColor: Colors.green[50]!,
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MyRidesScreen())),
                ),
              ),
              const SizedBox(width: 6),
            ],
            Expanded(
              child: _buildFooterItem(
                context,
                icon: Icons.person,
                label: 'Profile',
                iconColor: Colors.blue[700]!,
                bgColor: Colors.blue[50]!,
                isHighlight: true,
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProfileScreen(userRole: user?.role ?? 'passenger'))),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFooterItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color iconColor,
    required Color bgColor,
    required VoidCallback onTap,
    bool isHighlight = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isHighlight ? bgColor : null,
          border: Border.all(color: Colors.grey[300]!),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 20, color: iconColor),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
