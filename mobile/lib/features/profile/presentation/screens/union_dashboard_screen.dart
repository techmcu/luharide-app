import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/feedback/app_feedback.dart';
import '../../../../core/constants/input_limits.dart';
import '../../../../services/union_service.dart';
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

  Future<void> _callDriver(Map<String, dynamic> driver) async {
    final phone = (driver['phone'] ?? '').toString();
    if (phone.isEmpty) return;
    final driverId = driver['id'];
    if (driverId != null && _unionId != null) {
      UnionService().logContact(
        driverId: driverId is int ? driverId : int.tryParse(driverId.toString()) ?? 0,
        unionId: _unionId!,
        contactType: 'call',
      );
    }
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  Future<void> _whatsappDriver(Map<String, dynamic> driver) async {
    final number = (driver['whatsapp_number'] ?? '').toString();
    if (number.isEmpty) return;
    final driverId = driver['id'];
    if (driverId != null && _unionId != null) {
      UnionService().logContact(
        driverId: driverId is int ? driverId : int.tryParse(driverId.toString()) ?? 0,
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
                      // Contact Analytics Section (Advanced Feature)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: _buildSectionLabelWithBadge(
                          'Contact Analytics',
                          Icons.analytics_rounded,
                          advancedBadge: true,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: _buildContactStatsCard(),
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
                          child: _buildSectionLabelWithBadge(
                            'Drivers (${_drivers.length})',
                            Icons.people_alt_rounded,
                            advancedBadge: false,
                          ),
                        ),
                        const SizedBox(height: 12),
                        ..._drivers
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
            label: 'Active Rides',
            value: scheduledRides.toString(),
            icon: Icons.directions_car_filled_rounded,
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

  // ── Contact Analytics Card (Advanced Feature) ─────────────────────────────

  Widget _buildContactStatsCard() {
    final today = _contactStats?['today'] as Map<String, dynamic>? ?? {};
    final week = _contactStats?['week'] as Map<String, dynamic>? ?? {};
    final month = _contactStats?['month'] as Map<String, dynamic>? ?? {};
    final driverStats = _contactStats?['drivers'] as List? ?? [];

    final todayCalls = today['calls'] ?? 0;
    final todayWa = today['whatsapp'] ?? 0;
    final weekCalls = week['calls'] ?? 0;
    final weekWa = week['whatsapp'] ?? 0;
    final monthCalls = month['calls'] ?? 0;
    final monthWa = month['whatsapp'] ?? 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _advancedColor.withValues(alpha: 0.15)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Summary row: Today / Week / Month
          Row(
            children: [
              Expanded(
                child: _contactPeriodChip(
                  'Today',
                  todayCalls,
                  todayWa,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _contactPeriodChip(
                  '7 days',
                  weekCalls,
                  weekWa,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _contactPeriodChip(
                  '30 days',
                  monthCalls,
                  monthWa,
                ),
              ),
            ],
          ),
          if (driverStats.isNotEmpty) ...[
            const SizedBox(height: 14),
            const Divider(height: 1),
            const SizedBox(height: 12),
            const Text(
              'Per driver (last 30 days)',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.black54),
            ),
            const SizedBox(height: 8),
            ...driverStats.take(5).map((d) {
              final name = (d['name'] ?? 'Driver').toString();
              final calls = d['calls'] ?? 0;
              final wa = d['whatsapp_clicks'] ?? 0;
              final total = (calls as int) + (wa as int);
              if (total == 0) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 14,
                      backgroundColor: _advancedBg,
                      child: Text(
                        name.isNotEmpty ? name[0].toUpperCase() : 'D',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: _advancedColor,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        name,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (calls > 0)
                      _miniContactBadge(Icons.call_rounded, calls, const Color(0xFF43A047)),
                    if (wa > 0) ...[
                      const SizedBox(width: 6),
                      _miniContactBadge(Icons.chat_rounded, wa, const Color(0xFF25D366)),
                    ],
                  ],
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  Widget _contactPeriodChip(String label, int calls, int whatsapp) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 10, color: Colors.black54, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.call_rounded, size: 12, color: Color(0xFF43A047)),
              const SizedBox(width: 3),
              Text(
                '$calls',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.chat_rounded, size: 12, color: Color(0xFF25D366)),
              const SizedBox(width: 3),
              Text(
                '$whatsapp',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _miniContactBadge(IconData icon, int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 3),
          Text(
            '$count',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color),
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

  Widget _buildSectionLabelWithBadge(String title, IconData icon, {bool advancedBadge = false}) {
    return Row(
      children: [
        Icon(icon, size: 20, color: advancedBadge ? _advancedColor : _orange),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: advancedBadge ? _advancedColor : const Color(0xFF222222),
          ),
        ),
        if (advancedBadge) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: _advancedBg,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: _advancedColor.withValues(alpha: 0.3)),
            ),
            child: const Text(
              'Pro',
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.bold,
                color: _advancedColor,
              ),
            ),
          ),
        ],
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

  Widget _buildDriverCard(Map<String, dynamic> driver) {
    final name = (driver['name'] ?? '').toString();
    final vehicleNumber = (driver['vehicle_number'] ?? '').toString();
    final phone = (driver['phone'] ?? '').toString();
    final whatsapp = (driver['whatsapp_number'] ?? '').toString();
    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'D';

    // Find per-driver stats from contact stats
    final driverStats = _contactStats?['drivers'] as List? ?? [];
    final driverId = driver['id'];
    Map<String, dynamic>? driverStat;
    for (final ds in driverStats) {
      if (ds['id'] == driverId) {
        driverStat = ds as Map<String, dynamic>;
        break;
      }
    }
    final driverCalls = driverStat?['calls'] ?? 0;
    final driverWa = driverStat?['whatsapp_clicks'] ?? 0;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
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
          // Per-driver contact stats (if any)
          if ((driverCalls as int) > 0 || (driverWa as int) > 0) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Row(
                children: [
                  const Icon(Icons.trending_up_rounded, size: 14, color: Colors.black45),
                  const SizedBox(width: 6),
                  const Text(
                    '30d: ',
                    style: TextStyle(fontSize: 11, color: Colors.black45),
                  ),
                  if (driverCalls > 0) ...[
                    const Icon(Icons.call_rounded, size: 11, color: Color(0xFF43A047)),
                    const SizedBox(width: 2),
                    Text(
                      '$driverCalls',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ],
                  if (driverCalls > 0 && driverWa > 0)
                    const SizedBox(width: 8),
                  if (driverWa > 0) ...[
                    const Icon(Icons.chat_rounded, size: 11, color: Color(0xFF25D366)),
                    const SizedBox(width: 2),
                    Text(
                      '$driverWa',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ],
                  const Spacer(),
                  Text(
                    'contacts from passengers',
                    style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                  ),
                ],
              ),
            ),
          ],
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
