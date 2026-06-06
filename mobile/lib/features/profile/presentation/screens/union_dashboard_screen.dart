import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/feedback/app_feedback.dart';
import '../../../../core/constants/input_limits.dart';
import '../../../../services/union_service.dart';
import '../../../../utils/phone_call_helper.dart';
import 'union_create_rides_screen.dart';
import 'union_manage_drivers_screen.dart';
import 'union_routes_screen.dart';

class UnionDashboardScreen extends StatefulWidget {
  const UnionDashboardScreen({super.key});

  @override
  State<UnionDashboardScreen> createState() => _UnionDashboardScreenState();
}

class _UnionDashboardScreenState extends State<UnionDashboardScreen> {
  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _stats;
  Map<String, dynamic>? _contactStats;
  List<dynamic> _drivers = const [];
  String _posterHeader = '';
  String _posterCustomText = '';
  String _posterCustomTextPosition = 'right';
  String _posterLayoutType = 'classic';
  String _posterTheme = 'saffron';
  String? _unionId;

  // Contact filter state
  String _contactPeriod = 'today'; // today, week, month
  String? _contactDriverFilter; // null = all drivers
  bool _contactLoading = false;

  List<dynamic> get _filteredDrivers {
    if (_contactDriverFilter == null) return _drivers;
    return _drivers.where((d) {
      final id = (d as Map<String, dynamic>)['id']?.toString();
      return id == _contactDriverFilter;
    }).toList();
  }

  static const _orange = Color(0xFFFF6B00);
  static const _orangeLight = Color(0xFFFFF3E0);
  static const _purple = Color(0xFF7B1FA2);
  static const _advancedColor = Color(0xFF0D47A1);
  static const _advancedBg = Color(0xFFE3F2FD);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final service = UnionService();

    final unionResult = await service.getMyUnion();

    final results = await Future.wait([
      service.getDashboard(),
      service.getDrivers(),
      service.getContactStats(),
    ]);

    final dashboardResult = results[0];
    final driversResult = results[1];
    final contactResult = results[2];

    Map<String, dynamic>? stats;
    String? error;
    if (dashboardResult['success'] == true) {
      stats = dashboardResult['data'] as Map<String, dynamic>?;
    } else {
      error = dashboardResult['message']?.toString() ?? 'Failed to load dashboard';
    }

    List<dynamic> drivers = const [];
    if (driversResult['success'] == true) {
      final raw = driversResult['drivers'];
      if (raw is List) drivers = raw;
    }

    Map<String, dynamic>? contactStats;
    if (contactResult['success'] == true) {
      contactStats = contactResult['data'] as Map<String, dynamic>?;
    }

    String posterHeader = '';
    String posterCustomText = '';
    String posterCustomTextPosition = 'right';
    String posterLayoutType = 'classic';
    String posterTheme = 'saffron';
    String? unionId;
    Map<String, dynamic>? unionMap;
    if (unionResult['success'] == true) {
      unionMap = unionResult['union'] as Map<String, dynamic>?;
      posterHeader = (unionMap?['poster_header'] ?? '').toString();
      posterCustomText = (unionMap?['poster_custom_text'] ?? '').toString();
      posterCustomTextPosition = (unionMap?['poster_custom_text_position'] ?? 'right').toString();
      posterLayoutType = (unionMap?['poster_layout_type'] ?? 'classic').toString();
      posterTheme = (unionMap?['poster_theme'] ?? 'saffron').toString();
      unionId = unionMap?['id']?.toString();
    }

    if (!mounted) return;
    setState(() {
      _stats = stats;
      _contactStats = contactStats;
      _drivers = drivers;
      _posterHeader = posterHeader;
      _posterCustomText = posterCustomText;
      _posterCustomTextPosition = posterCustomTextPosition;
      _posterLayoutType = posterLayoutType;
      _posterTheme = posterTheme;
      _unionId = unionId;
      _error = error;
      _loading = false;
    });
  }

  Future<void> _refreshContactStats() async {
    setState(() => _contactLoading = true);
    final now = DateTime.now();
    String? from;
    String? to;
    if (_contactPeriod == 'today') {
      final d = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      from = d;
      to = d;
    } else if (_contactPeriod == 'week') {
      final start = now.subtract(const Duration(days: 7));
      from = '${start.year}-${start.month.toString().padLeft(2, '0')}-${start.day.toString().padLeft(2, '0')}';
      to = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    } else if (_contactPeriod == 'month') {
      final start = now.subtract(const Duration(days: 30));
      from = '${start.year}-${start.month.toString().padLeft(2, '0')}-${start.day.toString().padLeft(2, '0')}';
      to = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    }
    final result = await UnionService().getContactStats(
      from: from,
      to: to,
      driverId: _contactDriverFilter,
    );
    if (!mounted) return;
    setState(() {
      if (result['success'] == true) {
        _contactStats = result['data'] as Map<String, dynamic>?;
      }
      _contactLoading = false;
    });
  }

  Future<void> _callDriver(Map<String, dynamic> driver) async {
    final phone = (driver['phone'] ?? '').toString();
    if (phone.isEmpty) return;
    final driverId = driver['id']?.toString();
    if (driverId != null && driverId.isNotEmpty && _unionId != null) {
      UnionService().logContact(
        driverId: driverId,
        unionId: _unionId!,
        contactType: 'call',
      );
    }
    await launchPhoneCall(context, phone);
  }

  Future<void> _whatsappDriver(Map<String, dynamic> driver) async {
    final number = (driver['whatsapp_number'] ?? '').toString();
    if (number.isEmpty) return;
    final driverId = driver['id']?.toString();
    if (driverId != null && driverId.isNotEmpty && _unionId != null) {
      UnionService().logContact(
        driverId: driverId,
        unionId: _unionId!,
        contactType: 'whatsapp',
      );
    }
    final clean = number.replaceAll(RegExp(r'\D'), '');
    final uri = Uri.parse('https://wa.me/91$clean');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text(
          'Union Hub',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: _orange,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loading ? null : _load,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _loading
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: _orange),
                  SizedBox(height: 16),
                  Text('Loading...', style: TextStyle(color: Colors.grey)),
                ],
              ),
            )
          : _error != null
              ? _buildError()
              : RefreshIndicator(
                  color: _orange,
                  onRefresh: _load,
                  child: ListView(
                    padding: EdgeInsets.zero,
                    children: [
                      _buildHeader(),
                      const SizedBox(height: 20),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: _buildGrandTotal(),
                      ),
                      const SizedBox(height: 12),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: _buildStatsRow(),
                      ),
                      const SizedBox(height: 24),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: _buildSectionLabel('Quick actions', Icons.touch_app_rounded),
                      ),
                      const SizedBox(height: 12),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: _buildActionGrid(context),
                      ),
                      const SizedBox(height: 20),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: _buildPosterBrandingCard(context),
                      ),
                      const SizedBox(height: 28),
                      if (_drivers.isNotEmpty) ...[
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: _buildSectionLabel(
                            'Drivers & Calls (${_drivers.length})',
                            Icons.people_alt_rounded,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: _buildContactFilters(),
                        ),
                        const SizedBox(height: 10),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: _buildContactTotalBar(),
                        ),
                        const SizedBox(height: 12),
                        if (_contactLoading)
                          const Padding(
                            padding: EdgeInsets.all(20),
                            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                          )
                        else
                          ..._filteredDrivers
                              .map((d) => Padding(
                                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                                    child: _buildDriverCard(d as Map<String, dynamic>),
                                  ))
                              .toList(),
                        const SizedBox(height: 8),
                      ] else ...[
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: _buildNoDriversCard(context),
                        ),
                        const SizedBox(height: 8),
                      ],
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [_orange, Color(0xFFFF8C00)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.local_taxi_rounded, color: Colors.white, size: 28),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Your union',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Drivers, routes, schedules and posters',
                      style: TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGrandTotal() {
    final total = _stats?['total_rides_all_time'] ?? 0;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1A237E), Color(0xFF283593)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1A237E).withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.emoji_events_rounded, color: Colors.amber, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Grand Total Rides',
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
                const SizedBox(height: 2),
                Text(
                  total.toString(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    height: 1.1,
                  ),
                ),
                const Text(
                  'All rides ever created by your union',
                  style: TextStyle(color: Colors.white54, fontSize: 11),
                ),
              ],
            ),
          ),
          const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white38, size: 16),
        ],
      ),
    );
  }

  Widget _buildStatsRow() {
    final scheduledRides = _stats?['scheduled_rides'] ?? 0;
    final totalDrivers = _stats?['total_drivers'] ?? 0;
    final ridesToday = _stats?['rides_today'] ?? 0;

    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            label: 'Upcoming',
            value: scheduledRides.toString(),
            icon: Icons.schedule_rounded,
            color: const Color(0xFF1E88E5),
            bgColor: const Color(0xFFE3F2FD),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildStatCard(
            label: 'Today\'s Rides',
            value: ridesToday.toString(),
            icon: Icons.today_rounded,
            color: const Color(0xFFFF6B00),
            bgColor: const Color(0xFFFFF3E0),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildStatCard(
            label: 'Drivers',
            value: totalDrivers.toString(),
            icon: Icons.people_alt_rounded,
            color: const Color(0xFF8E24AA),
            bgColor: const Color(0xFFF3E5F5),
          ),
        ),
      ],
    );
  }

  // ── Contact Filters (period + driver dropdown) ─────────────────────────────

  Widget _buildContactFilters() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.filter_alt_rounded, size: 16, color: _advancedColor),
              const SizedBox(width: 6),
              const Text(
                'Filter calls',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              if (_contactDriverFilter != null || _contactPeriod != 'today')
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _contactPeriod = 'today';
                      _contactDriverFilter = null;
                    });
                    _refreshContactStats();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Reset',
                      style: TextStyle(fontSize: 11, color: Colors.red.shade700, fontWeight: FontWeight.w500),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          // Period chips
          Row(
            children: [
              _buildFilterChip('today', 'Today'),
              const SizedBox(width: 8),
              _buildFilterChip('week', '7 Days'),
              const SizedBox(width: 8),
              _buildFilterChip('month', '30 Days'),
            ],
          ),
          const SizedBox(height: 10),
          // Driver dropdown
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8F9FA),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                isExpanded: true,
                value: _contactDriverFilter,
                hint: const Text('All drivers', style: TextStyle(fontSize: 13)),
                icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 20),
                style: const TextStyle(fontSize: 13, color: Colors.black87),
                items: [
                  const DropdownMenuItem<String>(
                    value: null,
                    child: Text('All drivers'),
                  ),
                  ..._drivers.map((d) {
                    final id = (d as Map<String, dynamic>)['id']?.toString() ?? '';
                    final name = (d['name'] ?? 'Driver').toString();
                    return DropdownMenuItem<String>(
                      value: id,
                      child: Text(name, overflow: TextOverflow.ellipsis),
                    );
                  }),
                ],
                onChanged: (val) {
                  setState(() => _contactDriverFilter = val);
                  _refreshContactStats();
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String value, String label) {
    final selected = _contactPeriod == value;
    return GestureDetector(
      onTap: () {
        setState(() => _contactPeriod = value);
        _refreshContactStats();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? _advancedColor : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : Colors.grey.shade700,
          ),
        ),
      ),
    );
  }

  // ── Grand total bar for calls ─────────────────────────────────────────────

  Widget _buildContactTotalBar() {
    final periodData = _contactStats?[_contactPeriod] as Map<String, dynamic>? ?? {};
    final calls = periodData['calls'] ?? 0;
    final wa = periodData['whatsapp'] ?? 0;
    final grandTotal = _contactStats?['grand_total'] as Map<String, dynamic>? ?? {};
    final grandCalls = grandTotal['calls'] ?? 0;
    final grandWa = grandTotal['whatsapp'] ?? 0;

    final periodLabel = _contactPeriod == 'today'
        ? 'Today'
        : _contactPeriod == 'week'
            ? 'Last 7 days'
            : 'Last 30 days';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1A237E), Color(0xFF283593)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      periodLabel,
                      style: const TextStyle(color: Colors.white60, fontSize: 11),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.phone_rounded, size: 14, color: Colors.greenAccent),
                        const SizedBox(width: 4),
                        Text(
                          '$calls',
                          style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(width: 14),
                        const Icon(Icons.chat_rounded, size: 14, color: Color(0xFF25D366)),
                        const SizedBox(width: 4),
                        Text(
                          '$wa',
                          style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                width: 1,
                height: 36,
                color: Colors.white24,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '30 Days Total',
                      style: TextStyle(color: Colors.white60, fontSize: 11),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.phone_rounded, size: 14, color: Colors.greenAccent),
                        const SizedBox(width: 4),
                        Text(
                          '$grandCalls',
                          style: const TextStyle(color: Colors.amber, fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(width: 14),
                        const Icon(Icons.chat_rounded, size: 14, color: Color(0xFF25D366)),
                        const SizedBox(width: 4),
                        Text(
                          '$grandWa',
                          style: const TextStyle(color: Colors.amber, fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Section Labels ─────────────────────────────────────────────────────────

  Widget _buildSectionLabel(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 20, color: _orange),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Color(0xFF222222),
          ),
        ),
      ],
    );
  }


  // ── Stats Card ─────────────────────────────────────────────────────────────

  Widget _buildStatCard({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
    required Color bgColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 10),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(fontSize: 11, color: color.withValues(alpha: 0.8)),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // ── Quick Actions ──────────────────────────────────────────────────────────

  Widget _buildActionGrid(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildActionCard(
                icon: Icons.people_alt_rounded,
                iconBg: const Color(0xFFE3F2FD),
                iconColor: const Color(0xFF1E88E5),
                title: 'Drivers',
                subtitle: 'Add & manage\nyour union drivers',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const UnionManageDriversScreen()),
                ).then((_) => _load()),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildActionCard(
                icon: Icons.route_rounded,
                iconBg: const Color(0xFFE8F5E9),
                iconColor: const Color(0xFF43A047),
                title: 'Routes',
                subtitle: 'Save common routes\nlike Purola → Dehradun',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const UnionRoutesScreen()),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _buildActionCardWide(
          icon: Icons.add_road_rounded,
          iconBg: const Color(0xFFFFF3E0),
          iconColor: _orange,
          title: 'Schedules & posters',
          subtitle: 'Pick drivers, set route and time — get your daily schedule and PDF',
          badge: 'Main',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const UnionCreateRidesScreen()),
          ),
        ),
      ],
    );
  }

  Widget _buildActionCard({
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.07),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: iconColor, size: 26),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: Color(0xFF222222),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: const TextStyle(fontSize: 12, color: Colors.grey, height: 1.4),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Text(
                  'Open →',
                  style: TextStyle(
                    fontSize: 12,
                    color: iconColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionCardWide({
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    String? badge,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [_orangeLight, Colors.white],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _orange.withValues(alpha: 0.3)),
          boxShadow: [
            BoxShadow(
              color: _orange.withValues(alpha: 0.12),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(14)),
              child: Icon(icon, color: iconColor, size: 30),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (badge != null)
                    Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: _orange,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        badge,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF222222),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 12, color: Colors.black54, height: 1.4),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _orange.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.arrow_forward_rounded, color: _orange, size: 18),
            ),
          ],
        ),
      ),
    );
  }

  // ── Driver Card with Contact Stats ─────────────────────────────────────────

  Map<String, dynamic>? _getDriverContactData(String driverId) {
    final drivers = _contactStats?['drivers'] as List<dynamic>? ?? [];
    for (final d in drivers) {
      if (d is Map<String, dynamic> && d['id']?.toString() == driverId) {
        return d;
      }
    }
    return null;
  }

  Widget _buildDriverCard(Map<String, dynamic> driver) {
    final name = (driver['name'] ?? '').toString();
    final vehicleNumber = (driver['vehicle_number'] ?? '').toString();
    final phone = (driver['phone'] ?? '').toString();
    final whatsapp = (driver['whatsapp_number'] ?? '').toString();
    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'D';
    final driverId = driver['id']?.toString() ?? '';

    final contactData = _getDriverContactData(driverId);
    final driverCalls = contactData?['calls'] ?? 0;
    final driverWa = contactData?['whatsapp_clicks'] ?? 0;
    final totalContacts = (driverCalls as int) + (driverWa as int);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: totalContacts > 0
            ? Border.all(color: _advancedColor.withValues(alpha: 0.15))
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: _orange.withValues(alpha: 0.15),
                child: Text(
                  initial,
                  style: const TextStyle(
                    color: _orange,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name.isNotEmpty ? name : 'Driver',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    if (vehicleNumber.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 3),
                        child: Row(
                          children: [
                            const Icon(Icons.directions_car_rounded, size: 13, color: Colors.grey),
                            const SizedBox(width: 4),
                            Text(
                              vehicleNumber,
                              style: const TextStyle(fontSize: 12, color: Colors.black54),
                            ),
                          ],
                        ),
                      ),
                    if (phone.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Row(
                          children: [
                            const Icon(Icons.phone_rounded, size: 13, color: Colors.grey),
                            const SizedBox(width: 4),
                            Text(
                              phone,
                              style: const TextStyle(fontSize: 12, color: Colors.black54),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              if (phone.isNotEmpty || whatsapp.isNotEmpty)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (phone.isNotEmpty)
                      _iconBtn(
                        icon: Icons.call_rounded,
                        color: const Color(0xFF43A047),
                        onTap: () => _callDriver(driver),
                        tooltip: 'Call',
                      ),
                    if (whatsapp.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      _iconBtn(
                        icon: Icons.chat_rounded,
                        color: const Color(0xFF25D366),
                        onTap: () => _whatsappDriver(driver),
                        tooltip: 'WhatsApp',
                      ),
                    ],
                  ],
                ),
            ],
          ),
          // Call stats row
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: totalContacts > 0
                  ? _advancedBg.withValues(alpha: 0.5)
                  : Colors.grey.shade50,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.analytics_rounded,
                  size: 14,
                  color: totalContacts > 0 ? _advancedColor : Colors.grey.shade400,
                ),
                const SizedBox(width: 6),
                Icon(Icons.phone_rounded, size: 13, color: Colors.green.shade600),
                const SizedBox(width: 3),
                Text(
                  '$driverCalls',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: driverCalls > 0 ? Colors.green.shade700 : Colors.grey.shade500,
                  ),
                ),
                const SizedBox(width: 14),
                const Icon(Icons.chat_rounded, size: 13, color: Color(0xFF25D366)),
                const SizedBox(width: 3),
                Text(
                  '$driverWa',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: driverWa > 0 ? const Color(0xFF25D366) : Colors.grey.shade500,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: totalContacts > 0 ? _advancedColor.withValues(alpha: 0.1) : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Total: $totalContacts',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: totalContacts > 0 ? _advancedColor : Colors.grey.shade500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _iconBtn({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    required String tooltip,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
      ),
    );
  }

  Widget _buildNoDriversCard(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const UnionManageDriversScreen()),
      ).then((_) => _load()),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _orange.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.person_add_alt_1_rounded, color: _orange, size: 26),
            ),
            const SizedBox(width: 16),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'No drivers added yet',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Tap here to add your first driver',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  // ── Poster Branding Card ───────────────────────────────────────────────────

  Widget _buildPosterBrandingCard(BuildContext context) {
    final hasHeader = _posterHeader.isNotEmpty;
    return GestureDetector(
      onTap: () => _showBrandingSheet(context),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: hasHeader ? _purple.withValues(alpha: 0.3) : Colors.grey.shade200,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _purple.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.picture_as_pdf_rounded, color: _purple, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Poster header',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      hasHeader
                          ? 'Header: $_posterHeader'
                          : 'Tap to set a custom header for your ride posters\n(e.g. blessing, deity name)',
                      style: TextStyle(
                        fontSize: 12,
                        color: hasHeader ? _purple : Colors.grey.shade500,
                        fontStyle: hasHeader ? FontStyle.italic : FontStyle.normal,
                      ),
                    ),
                    if (_posterCustomText.trim().isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          'Small text (${_posterCustomTextPosition.toUpperCase()}): ${_posterCustomText.trim()}',
                          style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: _purple.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  hasHeader ? 'Edit' : 'Set Up',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: _purple,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showBrandingSheet(BuildContext context) async {
    final ctrl = TextEditingController(text: _posterHeader);
    final customCtrl = TextEditingController(text: _posterCustomText);
    bool saving = false;
    String selectedPosition = _posterCustomTextPosition;
    final positionLabels = <String, String>{'left': 'Left', 'right': 'Right'};
    final positionIcons = <String, IconData>{
      'left': Icons.vertical_align_center_rounded,
      'right': Icons.vertical_align_center_rounded,
    };
    String selectedTheme = _posterTheme;
    final themeLabels = <String, String>{
      'saffron': 'Saffron',
      'sky': 'Sky',
      'mint': 'Mint',
      'rose': 'Rose',
    };

    Color previewBg(String key) {
      switch (key) {
        case 'sky': return const Color(0xFFB3E5FC);
        case 'mint': return const Color(0xFFC8E6C9);
        case 'rose': return const Color(0xFFF8BBD0);
        default: return const Color(0xFFFFC107);
      }
    }

    Color previewText(String key) {
      switch (key) {
        case 'sky': return const Color(0xFF0F172A);
        case 'mint': return const Color(0xFF1B4332);
        case 'rose': return const Color(0xFF3F1D2E);
        default: return const Color(0xFF212121);
      }
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) {
          return Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
              top: 8,
              left: 20,
              right: 20,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40, height: 4,
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const Row(
                  children: [
                    Icon(Icons.picture_as_pdf_rounded, color: _purple, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Simple poster settings',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Only this saved text will be used in poster',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: const Color(0xFFFFF8F3),
                    border: Border.all(color: _orange.withValues(alpha: 0.25)),
                  ),
                  child: ValueListenableBuilder<TextEditingValue>(
                    valueListenable: ctrl,
                    builder: (_, headerVal, __) => ValueListenableBuilder<TextEditingValue>(
                      valueListenable: customCtrl,
                      builder: (_, customVal, __) {
                        final header = headerVal.text.trim();
                        final small = customVal.text.trim();
                        final pos = positionLabels[selectedPosition] ?? 'Bottom';
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Mini preview',
                              style: TextStyle(fontSize: 11, color: Colors.black54, fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                              decoration: BoxDecoration(
                                color: previewBg(selectedTheme),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Column(
                                children: [
                                  Text(
                                    header.isEmpty ? 'No custom header' : header,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontStyle: FontStyle.italic,
                                      fontSize: header.isEmpty ? 11 : 13,
                                      fontWeight: header.isEmpty ? FontWeight.w400 : FontWeight.w600,
                                      color: previewText(selectedTheme),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'YOUR UNION NAME',
                                    style: TextStyle(
                                      color: previewText(selectedTheme),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (small.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Text(
                                'Small text ($pos): $small',
                                style: const TextStyle(fontSize: 12, color: Colors.black87),
                              ),
                            ],
                          ],
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  children: [
                    'Jai Mata Di',
                    'Jai Shri Ram',
                    'Jai Bholenath',
                    'Shri Ganeshaye Namah',
                  ].map((example) => ActionChip(
                    label: Text(example, style: const TextStyle(fontSize: 12)),
                    onPressed: () {
                      ctrl.text = example;
                      ctrl.selection = TextSelection.collapsed(offset: ctrl.text.length);
                    },
                    backgroundColor: _purple.withValues(alpha: 0.08),
                    labelStyle: TextStyle(color: _purple),
                  )).toList(),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: ctrl,
                  maxLength: InputLimits.posterHeader,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: 'Header text (optional)',
                    hintText: 'e.g. Jai Mata Di',
                    prefixIcon: const Icon(Icons.format_quote_rounded, size: 20),
                    helperText: 'This line appears on top of poster',
                    filled: true,
                    fillColor: const Color(0xFFF8F8F8),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade200),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade200),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: _purple, width: 1.5),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: customCtrl,
                  maxLength: InputLimits.posterCustomText,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: 'Small custom text (optional)',
                    hintText: 'e.g. Helpline: 98xxxxxx',
                    prefixIcon: const Icon(Icons.edit_note_rounded, size: 20),
                    helperText: 'Will appear in small style on selected position',
                    filled: true,
                    fillColor: const Color(0xFFF8F8F8),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade200),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade200),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: _purple, width: 1.5),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                const Text('Small text position', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  children: ['left', 'right'].map((pos) {
                    final active = selectedPosition == pos;
                    return ChoiceChip(
                      selected: active,
                      avatar: Icon(positionIcons[pos], size: 16, color: active ? Colors.white : Colors.black54),
                      label: Text(positionLabels[pos] ?? pos),
                      onSelected: (_) => setSheet(() => selectedPosition = pos),
                      selectedColor: _purple,
                      labelStyle: TextStyle(color: active ? Colors.white : Colors.black87),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 10),
                const Text('Poster color', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  children: ['saffron', 'sky', 'mint', 'rose'].map((key) {
                    final active = selectedTheme == key;
                    return ChoiceChip(
                      selected: active,
                      label: Text(themeLabels[key] ?? key),
                      onSelected: (_) => setSheet(() => selectedTheme = key),
                      selectedColor: _purple,
                      labelStyle: TextStyle(color: active ? Colors.white : Colors.black87),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: saving
                        ? null
                        : () async {
                            setSheet(() => saving = true);
                            final result = await UnionService().updateBranding(
                              posterHeader: ctrl.text.trim(),
                              posterCustomText: customCtrl.text.trim(),
                              posterCustomTextPosition: selectedPosition,
                              posterLayoutType: _posterLayoutType,
                              posterTheme: selectedTheme,
                            );
                            setSheet(() => saving = false);
                            if (!context.mounted) return;
                            if (result['success'] == true) {
                              setState(() {
                                _posterHeader = ctrl.text.trim();
                                _posterCustomText = customCtrl.text.trim();
                                _posterCustomTextPosition = selectedPosition;
                                _posterTheme = selectedTheme;
                              });
                              if (ctx.mounted) Navigator.pop(ctx);
                              AppFeedback.show(
                                context,
                                'Poster branding saved',
                                kind: AppFeedbackKind.success,
                                icon: Icons.check_circle_rounded,
                              );
                            } else {
                              AppFeedback.show(
                                context,
                                result['message']?.toString() ?? 'Failed to save',
                                kind: AppFeedbackKind.error,
                              );
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _purple,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                    ),
                    child: saving
                        ? const SizedBox(
                            width: 22, height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Text(
                            'Save Branding',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.wifi_off_rounded, size: 48, color: Colors.red.shade400),
            ),
            const SizedBox(height: 20),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, color: Colors.black54),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try Again'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _orange,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

