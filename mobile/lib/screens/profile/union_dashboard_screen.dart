import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/config/env_config.dart';
import '../../services/union_service.dart';
import 'union_create_rides_screen.dart';
import 'union_documents_screen.dart';
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
  List<dynamic> _drivers = const [];
  String _posterHeader = '';
  Map<String, dynamic>? _union;

  static const _orange = Color(0xFFFF6B00);
  static const _orangeLight = Color(0xFFFFF3E0);
  static const _purple = Color(0xFF7B1FA2);

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

    // Call getMyUnion FIRST — backend self-heals role to union_admin if union is approved.
    // Only after that call the dashboard (which requires union_admin role).
    final unionResult = await service.getMyUnion();

    final results = await Future.wait([
      service.getDashboard(),
      service.getDrivers(),
    ]);

    final dashboardResult = results[0];
    final driversResult   = results[1];

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

    String posterHeader = '';
    Map<String, dynamic>? unionMap;
    if (unionResult['success'] == true) {
      unionMap = unionResult['union'] as Map<String, dynamic>?;
      posterHeader = (unionMap?['poster_header'] ?? '').toString();
    }

    if (!mounted) return;
    setState(() {
      _stats = stats;
      _drivers = drivers;
      _posterHeader = posterHeader;
      _union = unionMap;
      _error = error;
      _loading = false;
    });
  }

  Future<void> _callDriver(String phone) async {
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  Future<void> _whatsappDriver(String number) async {
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
          'Union hub',
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
                        child: _buildDocumentsCard(context),
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
                            'Your drivers (${_drivers.length})',
                            Icons.people_alt_rounded,
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
                  color: Colors.white.withOpacity(0.2),
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
            color: const Color(0xFF1A237E).withOpacity(0.3),
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
              color: Colors.white.withOpacity(0.15),
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
    final totalDrivers   = _stats?['total_drivers'] ?? 0;
    final ridesToday     = _stats?['rides_today'] ?? 0;

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
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
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
            style: TextStyle(fontSize: 11, color: color.withOpacity(0.8)),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

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

  Widget _buildActionGrid(BuildContext context) {
    return Column(
      children: [
        // Row 1: Drivers + Routes
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
        // Row 2: Create Rides (full width — most important action)
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
              color: Colors.black.withOpacity(0.07),
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
          border: Border.all(color: _orange.withOpacity(0.3)),
          boxShadow: [
            BoxShadow(
              color: _orange.withOpacity(0.12),
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
                color: _orange.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.arrow_forward_rounded, color: _orange, size: 18),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDriverCard(Map<String, dynamic> driver) {
    final name = (driver['name'] ?? '').toString();
    final vehicleNumber = (driver['vehicle_number'] ?? '').toString();
    final phone = (driver['phone'] ?? '').toString();
    final whatsapp = (driver['whatsapp_number'] ?? '').toString();
    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'D';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: _orange.withOpacity(0.15),
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
                    onTap: () => _callDriver(phone),
                    tooltip: 'Call',
                  ),
                if (whatsapp.isNotEmpty) ...[
                  const SizedBox(width: 6),
                  _iconBtn(
                    icon: Icons.chat_rounded,
                    color: const Color(0xFF25D366),
                    onTap: () => _whatsappDriver(whatsapp),
                    tooltip: 'WhatsApp',
                  ),
                ],
              ],
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
            color: color.withOpacity(0.12),
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
              color: Colors.black.withOpacity(0.04),
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
                color: _orange.withOpacity(0.1),
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

  String _docFullUrl(String? u) {
    if (u == null || u.isEmpty) return '';
    if (u.startsWith('http://') || u.startsWith('https://')) return u;
    final base = EnvConfig.socketUrl.replaceAll(RegExp(r'/+$'), '');
    if (u.startsWith('/')) return '$base$u';
    return '$base/$u';
  }

  /// KYC docs + stand notes — same data as registration; tap to edit (like independent driver flow).
  Widget _buildDocumentsCard(BuildContext context) {
    final u = _union;
    final aadhaar = u?['owner_aadhaar_url']?.toString();
    final office = u?['office_photo_url']?.toString();
    final rc = u?['owner_vehicle_rc_url']?.toString();
    final notes = (u?['union_share_notes'] ?? '').toString().trim();
    final hasThumb = [aadhaar, office, rc].any((s) => s != null && s.isNotEmpty);

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const UnionDocumentsScreen()),
      ).then((saved) {
        if (saved == true) _load();
      }),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: hasThumb ? _orange.withOpacity(0.35) : Colors.grey.shade200,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
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
                  color: _orange.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.folder_shared_rounded, color: _orange, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Union documents',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    const SizedBox(height: 4),
                    if (hasThumb)
                      Row(
                        children: [
                          _docThumb(_docFullUrl(aadhaar)),
                          const SizedBox(width: 6),
                          _docThumb(_docFullUrl(office)),
                          const SizedBox(width: 6),
                          _docThumb(_docFullUrl(rc)),
                        ],
                      )
                    else
                      Text(
                        'Aadhaar, office photo, RC — tap to add or update',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                      ),
                    if (notes.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        notes,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade700, fontStyle: FontStyle.italic),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: _orange.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'View / edit',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: _orange,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _docThumb(String full) {
    if (full.isEmpty) {
      return Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(Icons.image_not_supported_outlined, size: 20, color: Colors.grey[500]),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.network(
        full,
        width: 44,
        height: 44,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(
          width: 44,
          height: 44,
          color: Colors.grey[200],
          child: Icon(Icons.broken_image_outlined, size: 20, color: Colors.grey[600]),
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
            color: hasHeader ? _purple.withOpacity(0.3) : Colors.grey.shade200,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
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
                  color: _purple.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.picture_as_pdf_rounded,
                  color: _purple,
                  size: 22,
                ),
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
                          ? 'Header: "$_posterHeader"'
                          : 'Tap to set a custom header for your ride posters\n(e.g. blessing, deity name)',
                      style: TextStyle(
                        fontSize: 12,
                        color: hasHeader ? _purple : Colors.grey.shade500,
                        fontStyle: hasHeader ? FontStyle.italic : FontStyle.normal,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: _purple.withOpacity(0.1),
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
    final ctrl    = TextEditingController(text: _posterHeader);
    bool saving   = false;

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
                // Handle
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
                // Header row
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: _purple.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.picture_as_pdf_rounded, color: _purple, size: 22),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Poster header',
                            style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            'This line appears at the very top of every ride poster',
                            style: TextStyle(fontSize: 12, color: Colors.black54),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                // Preview box
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF6B00),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      ValueListenableBuilder<TextEditingValue>(
                        valueListenable: ctrl,
                        builder: (_, v, __) => v.text.isNotEmpty
                            ? Text(
                                '*  ${v.text}  *',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontStyle: FontStyle.italic,
                                  fontSize: 14,
                                ),
                                textAlign: TextAlign.center,
                              )
                            : const SizedBox.shrink(),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'YOUR UNION NAME',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'TAXI UNION  -  DAILY RIDE SCHEDULE',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.6),
                          fontSize: 9,
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Live preview of your poster header above',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                // Examples row
                Wrap(
                  spacing: 8,
                  children: [
                    'Jai Mata Di',
                    'Jai Shri Ram',
                    'Jai Bholenath',
                    'Shri Ganeshaye Namah',
                  ].map((example) => ActionChip(
                    label: Text(example, style: const TextStyle(fontSize: 12)),
                    onPressed: () => ctrl.text = example,
                    backgroundColor: _purple.withOpacity(0.08),
                    labelStyle: TextStyle(color: _purple),
                  )).toList(),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: ctrl,
                  maxLength: 60,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) async {
                    if (saving) return;
                    setSheet(() => saving = true);

                    final result = await UnionService().updateBranding(
                      posterHeader: ctrl.text.trim(),
                    );

                    setSheet(() => saving = false);
                    if (!mounted) return;

                    if (result['success'] == true) {
                      setState(() => _posterHeader = ctrl.text.trim());
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Row(children: [
                            Icon(Icons.check_circle_rounded,
                                color: Colors.white, size: 18),
                            SizedBox(width: 8),
                            Text('Poster branding saved'),
                          ]),
                          backgroundColor: _purple,
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                              result['message']?.toString() ?? 'Failed to save'),
                          backgroundColor: Colors.red,
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                      );
                    }
                  },
                  decoration: InputDecoration(
                    labelText: 'Custom header text (optional)',
                    hintText: 'e.g. Jai Mata Di',
                    prefixIcon: const Icon(Icons.format_quote_rounded, size: 20),
                    helperText: 'Leave blank to remove the header line from posters',
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
                const SizedBox(height: 16),
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
                            );
                            setSheet(() => saving = false);
                            if (!mounted) return;
                            if (result['success'] == true) {
                              setState(() => _posterHeader = ctrl.text.trim());
                              Navigator.pop(ctx);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: const Row(children: [
                                    Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
                                    SizedBox(width: 8),
                                    Text('Poster branding saved'),
                                  ]),
                                  backgroundColor: _purple,
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                              );
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(result['message']?.toString() ?? 'Failed to save'),
                                  backgroundColor: Colors.red,
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
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
