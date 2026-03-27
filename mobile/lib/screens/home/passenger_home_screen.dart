import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../providers/auth_provider.dart';
import '../../core/localization/app_localizations.dart';
import '../../models/trip_model.dart';
import '../../services/trip_service.dart';
import '../../services/notification_service.dart';
import '../trips/trip_details_screen.dart';
import '../trips/passenger_my_rides_screen.dart';
import '../trips/create_trip_screen.dart';
import '../trips/my_rides_screen.dart';
import '../profile/profile_screen.dart';
import '../profile/driver_verification_form_screen.dart';
import '../notifications/notifications_screen.dart';

class PassengerHomeScreen extends StatefulWidget {
  const PassengerHomeScreen({super.key});

  @override
  State<PassengerHomeScreen> createState() => _PassengerHomeScreenState();
}

class _PassengerHomeScreenState extends State<PassengerHomeScreen> {
  final _tripService = TripService();
  final _fromController = TextEditingController();
  final _toController = TextEditingController();
  final _scrollController = ScrollController();
  final _fromFocusNode = FocusNode();
  final _toFocusNode = FocusNode();
  DateTime _selectedDate = DateTime.now();

  List<TripModel> _searchResults = [];
  List<Map<String, dynamic>> _unionSearchResults = const [];
  bool _isSearching = false;
  bool _hasSearched = false;
  final _notificationService = NotificationService();
  int _unreadNotificationCount = 0;

  // Location suggestions (debounced) for find-ride search bar
  List<String> _fromSuggestions = [];
  List<String> _toSuggestions = [];
  Timer? _debounceFrom;
  Timer? _debounceTo;
  static const _suggestionDebounce = Duration(milliseconds: 350);
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 12),
              Expanded(child: Text('Verification approved! You can now create rides.')),
            ],
          ),
          backgroundColor: Colors.green[600],
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  @override
  void dispose() {
    _debounceFrom?.cancel();
    _debounceTo?.cancel();
    _fromFocusNode.dispose();
    _toFocusNode.dispose();
    _fromController.dispose();
    _toController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onFromChanged(String value) {
    _debounceFrom?.cancel();
    if (value.trim().length < 2) {
      setState(() => _fromSuggestions = []);
      return;
    }
    _debounceFrom = Timer(_suggestionDebounce, () async {
      final suggestions = await _tripService.getLocationSuggestions(value.trim());
      if (!mounted) return;
      setState(() => _fromSuggestions = suggestions);
    });
  }

  void _onToChanged(String value) {
    _debounceTo?.cancel();
    if (value.trim().length < 2) {
      setState(() => _toSuggestions = []);
      return;
    }
    _debounceTo = Timer(_suggestionDebounce, () async {
      final suggestions = await _tripService.getLocationSuggestions(value.trim());
      if (!mounted) return;
      setState(() => _toSuggestions = suggestions);
    });
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

  Future<void> _searchTrips() async {
    if (_fromController.text.trim().isEmpty || _toController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter both From and To locations'),
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message']),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final user = authProvider.user;
    final t = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('LuhaRide', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.grey[800],
        actions: [
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
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const NotificationsScreen(),
                ),
              );
              _loadNotificationsOnce();
            },
          ),
          IconButton(
            icon: const Icon(Icons.person_outline, size: 22),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ProfileScreen(userRole: 'passenger'),
                ),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        controller: _scrollController,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Welcome Header - light, professional
            Container(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
              child: Row(
                children: [
                    CircleAvatar(
                    radius: 24,
                    backgroundColor: Colors.blue[50],
                    child: Text(
                      _avatarInitial(user?.name),
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                        color: Colors.blue[700],
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _displayName(user?.name),
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[800],
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        // Rating reminder is handled by backend job (pending_rate_notifications + notifications table).
                        Row(
                          children: [
                            Icon(Icons.star_outline_rounded, color: Colors.grey[500], size: 16),
                            const SizedBox(width: 4),
                            Text(
                              'Complete rides to get rated',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[500],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Search Box
            Padding(
              padding: const EdgeInsets.all(16),
              child: Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      // From Location with suggestions
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          TextField(
                            controller: _fromController,
                            focusNode: _fromFocusNode,
                            textCapitalization: TextCapitalization.words,
                            onChanged: _onFromChanged,
                            onTap: () => setState(() {}),
                            decoration: InputDecoration(
                              labelText: t.t('ride.from.label'),
                              hintText: t.t('ride.from.placeholder'),
                              prefixIcon: const Icon(Icons.trip_origin, color: Colors.green),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                          if (_fromSuggestions.isNotEmpty && _fromFocusNode.hasFocus)
                            Container(
                              margin: const EdgeInsets.only(top: 4),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.08),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              constraints: const BoxConstraints(maxHeight: 180),
                              child: ListView.builder(
                                shrinkWrap: true,
                                padding: EdgeInsets.zero,
                                itemCount: _fromSuggestions.length,
                                itemBuilder: (context, i) {
                                  final s = _fromSuggestions[i];
                                  return ListTile(
                                    dense: true,
                                    leading: Icon(Icons.place, size: 20, color: Colors.grey[600]),
                                    title: Text(s, style: const TextStyle(fontSize: 14)),
                                    onTap: () {
                                      _fromController.text = s;
                                      setState(() => _fromSuggestions = []);
                                      _fromFocusNode.unfocus();
                                    },
                                  );
                                },
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // To Location with suggestions
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          TextField(
                            controller: _toController,
                            focusNode: _toFocusNode,
                            textCapitalization: TextCapitalization.words,
                            onChanged: _onToChanged,
                            onTap: () => setState(() {}),
                            decoration: InputDecoration(
                              labelText: t.t('ride.to.label'),
                              hintText: t.t('ride.to.placeholder'),
                              prefixIcon: const Icon(Icons.location_on, color: Colors.red),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                          if (_toSuggestions.isNotEmpty && _toFocusNode.hasFocus)
                            Container(
                              margin: const EdgeInsets.only(top: 4),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.08),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              constraints: const BoxConstraints(maxHeight: 180),
                              child: ListView.builder(
                                shrinkWrap: true,
                                padding: EdgeInsets.zero,
                                itemCount: _toSuggestions.length,
                                itemBuilder: (context, i) {
                                  final s = _toSuggestions[i];
                                  return ListTile(
                                    dense: true,
                                    leading: Icon(Icons.place, size: 20, color: Colors.grey[600]),
                                    title: Text(s, style: const TextStyle(fontSize: 14)),
                                    onTap: () {
                                      _toController.text = s;
                                      setState(() => _toSuggestions = []);
                                      _toFocusNode.unfocus();
                                    },
                                  );
                                },
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Date Selector
                      InkWell(
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
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey[400]!),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.calendar_today, color: Colors.blue),
                              const SizedBox(width: 12),
                              Text(
                                '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
                                style: const TextStyle(fontSize: 16),
                              ),
                              const Spacer(),
                              const Icon(Icons.arrow_drop_down),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Search Button
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton.icon(
                          onPressed: _isSearching ? null : _searchTrips,
                          icon: _isSearching
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.search),
                          label: Text(
                            _isSearching ? 'Searching...' : 'Search Trips',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
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

          ],
        ),
      ),
      bottomNavigationBar: _buildFooter(context),
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
    final effectiveWa = whatsapp.isNotEmpty ? whatsapp : phone;

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
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.07), blurRadius: 10, offset: const Offset(0, 3))],
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
                if (phone.isNotEmpty || effectiveWa.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Row(children: [
                    if (phone.isNotEmpty) ...[
                      Expanded(child: _contactBtn(Icons.call_rounded, 'Call', const Color(0xFF16A34A), () => _launchPhone(phone))),
                      const SizedBox(width: 8),
                    ],
                    if (effectiveWa.isNotEmpty)
                      Expanded(child: _contactBtn(Icons.chat_rounded, 'WhatsApp', const Color(0xFF25D366), () => _launchWhatsApp(effectiveWa))),
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
    final status = user?.driverVerificationStatus ?? 'none';
    if (status == 'approved') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const CreateTripScreen()),
      ).then((_) {
        _searchTrips(); // Refresh after creating
      });
    } else if (status == 'pending') {
      _showVerifyPopup(
        context,
        'Your driver verification is pending. Admin usually reviews within 24–48 hours.\n\n'
        'Agar isse zyada delay ho jaye, to aap supportluharide@gmail.com par politely email karke '
        'apni request ka status pooch sakte hain (subject mein apna naam aur phone number likh kar).',
      );
    } else {
      _showVerifyPopup(context, 'Please verify your documents first to create rides.');
    }
  }

  void _showVerifyPopup(BuildContext context, String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.verified_user_outlined, color: Colors.orange[700], size: 28),
            const SizedBox(width: 10),
            const Text('Verify First', style: TextStyle(fontSize: 18)),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const DriverVerificationFormScreen()),
              ).then((refresh) {
                if (refresh == true) {
                  context.read<AuthProvider>().refreshUser();
                }
              });
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Verify Documents'),
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
                      '${trip.farePerSeat.toStringAsFixed(0)}',
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

            // Independent driver: only Book (seat selection on trip details)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
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
      color: color.withOpacity(0.1),
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
            color: Colors.black.withOpacity(0.05),
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
