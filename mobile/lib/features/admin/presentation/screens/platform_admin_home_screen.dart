import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../../../../core/feedback/app_feedback.dart';
import '../../../../services/platform_admin_service.dart';
import '../../../../services/admin_service.dart';
import 'platform_user_detail_screen.dart';
import 'platform_trip_detail_screen.dart';
import 'simple_kyc_preview_screen.dart';
import '../../../home/presentation/screens/union_admin_home_screen.dart';

class PlatformAdminHomeScreen extends StatefulWidget {
  const PlatformAdminHomeScreen({super.key});

  @override
  State<PlatformAdminHomeScreen> createState() => _PlatformAdminHomeScreenState();
}

class _PlatformAdminHomeScreenState extends State<PlatformAdminHomeScreen> {
  int _currentTab = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentTab,
        children: const [
          _DashboardTab(),
          _UsersTab(),
          _TripsTab(),
          _RevenueTab(),
          _MoreTab(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentTab,
        onDestinationSelected: (i) => setState(() => _currentTab = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard), label: 'Dashboard'),
          NavigationDestination(icon: Icon(Icons.people_outline), selectedIcon: Icon(Icons.people), label: 'Users'),
          NavigationDestination(icon: Icon(Icons.directions_car_outlined), selectedIcon: Icon(Icons.directions_car), label: 'Trips'),
          NavigationDestination(icon: Icon(Icons.bar_chart_outlined), selectedIcon: Icon(Icons.bar_chart), label: 'Revenue'),
          NavigationDestination(icon: Icon(Icons.more_horiz_outlined), selectedIcon: Icon(Icons.more_horiz), label: 'More'),
        ],
      ),
    );
  }
}

// =============================================================================
// DASHBOARD TAB
// =============================================================================
class _DashboardTab extends StatefulWidget {
  const _DashboardTab();
  @override
  State<_DashboardTab> createState() => _DashboardTabState();
}

class _DashboardTabState extends State<_DashboardTab> {
  final _service = PlatformAdminService();
  Map<String, dynamic>? _data;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final res = await _service.getDashboard();
    if (!mounted) return;
    setState(() {
      _data = res;
      _loading = false;
    });
  }

  Future<void> _downloadCsv() async {
    AppFeedback.show(context, 'Generating report...', kind: AppFeedbackKind.info);
    final csv = await _service.exportCsv(days: 180);
    if (!mounted) return;
    if (csv == null || csv.isEmpty) {
      AppFeedback.show(context, 'No data to export', kind: AppFeedbackKind.warning);
      return;
    }
    try {
      final bytes = Uint8List.fromList(utf8.encode(csv));
      await Share.shareXFiles(
        [XFile.fromData(
          bytes,
          name: 'luharide-stats.csv',
          mimeType: 'text/csv',
        )],
        subject: 'LuhaRide Stats Report',
      );
    } catch (e) {
      if (mounted) {
        AppFeedback.show(context, 'Export failed: $e', kind: AppFeedbackKind.error);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Platform Admin'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.admin_panel_settings_outlined),
            tooltip: 'KYC & Union Management',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const UnionAdminHomeScreen()),
            ),
          ),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _data?['success'] != true
              ? Center(child: Text(_data?['message'] ?? 'Failed to load'))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _sectionTitle('Users'),
                      const SizedBox(height: 8),
                      _statsRow([
                        _StatItem('Total', _data?['total_users'] ?? 0, Icons.group, Colors.blue),
                        _StatItem('Passengers', _data?['passengers'] ?? 0, Icons.person, Colors.green),
                        _StatItem('Drivers', _data?['drivers'] ?? 0, Icons.directions_car, Colors.orange),
                        _StatItem('Union Admins', _data?['union_admins'] ?? 0, Icons.business, Colors.purple),
                      ]),
                      const SizedBox(height: 20),
                      _sectionTitle('Trips (last ${_data?['days_filter'] ?? 90} days)'),
                      const SizedBox(height: 8),
                      _statsRow([
                        _StatItem('Total', _data?['total_trips'] ?? 0, Icons.route, Colors.blueGrey),
                        _StatItem('Scheduled', _data?['scheduled_trips'] ?? 0, Icons.schedule, Colors.blue),
                        _StatItem('Active', _data?['active_trips'] ?? 0, Icons.play_arrow, Colors.green),
                        _StatItem('Completed', _data?['completed_trips'] ?? 0, Icons.check_circle, Colors.teal),
                      ]),
                      const SizedBox(height: 12),
                      _statsRow([
                        _StatItem('Upcoming', _data?['upcoming_trips'] ?? 0, Icons.upcoming, Colors.orange),
                        _StatItem('Cancelled', _data?['cancelled_trips'] ?? 0, Icons.cancel, Colors.red),
                        _StatItem('Today', _data?['today_trips'] ?? 0, Icons.today, Colors.indigo),
                        _StatItem('Active Drivers', _data?['active_drivers'] ?? 0, Icons.local_taxi, Colors.amber),
                      ]),
                      const SizedBox(height: 12),
                      _statsRow([
                        _StatItem('New (7d)', _data?['new_users_week'] ?? 0, Icons.person_add, Colors.pink),
                      ]),
                      const SizedBox(height: 20),
                      _sectionTitle('Bookings (last ${_data?['days_filter'] ?? 90} days)'),
                      const SizedBox(height: 8),
                      _statsRow([
                        _StatItem('Confirmed', _data?['confirmed_bookings'] ?? 0, Icons.bookmark_added, Colors.green),
                        _StatItem('Pending', _data?['pending_bookings'] ?? 0, Icons.pending_actions, Colors.orange),
                        _StatItem('Cancelled', _data?['cancelled_bookings'] ?? 0, Icons.bookmark_remove, Colors.red),
                      ]),
                      const SizedBox(height: 20),
                      _sectionTitle('KYC & Verification'),
                      const SizedBox(height: 8),
                      _statsRow([
                        _StatItem('Driver KYC', _data?['pending_driver_kyc'] ?? 0, Icons.assignment_ind, Colors.deepOrange),
                        _StatItem('Union Req', _data?['pending_union_requests'] ?? 0, Icons.business_center, Colors.purple),
                        _StatItem('Total Unions', _data?['total_unions'] ?? 0, Icons.groups, Colors.indigo),
                      ]),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _downloadCsv,
                          icon: const Icon(Icons.download),
                          label: const Text('Download 6-month report (CSV)'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            side: const BorderSide(color: Colors.blue),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _sectionTitle(String text) {
    return Text(text, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.black87));
  }

  Widget _statsRow(List<_StatItem> items) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: items.map((item) => Padding(
          padding: const EdgeInsets.only(right: 10),
          child: SizedBox(
            width: 100,
            child: Card(
              elevation: 1,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(item.icon, color: item.color, size: 24),
                    const SizedBox(height: 8),
                    Text('${item.value}', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: item.color)),
                    const SizedBox(height: 4),
                    Text(item.label, style: const TextStyle(fontSize: 11, color: Colors.black54), textAlign: TextAlign.center),
                  ],
                ),
              ),
            ),
          ),
        )).toList(),
      ),
    );
  }
}

class _StatItem {
  final String label;
  final int value;
  final IconData icon;
  final Color color;
  const _StatItem(this.label, this.value, this.icon, this.color);
}

// =============================================================================
// USERS TAB
// =============================================================================
class _UsersTab extends StatefulWidget {
  const _UsersTab();
  @override
  State<_UsersTab> createState() => _UsersTabState();
}

class _UsersTabState extends State<_UsersTab> {
  final _service = PlatformAdminService();
  final _searchCtrl = TextEditingController();
  List<dynamic> _users = [];
  int _total = 0;
  int _page = 1;
  String _roleFilter = '';
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final res = await _service.getUsers(
      search: _searchCtrl.text.trim(),
      role: _roleFilter,
      page: _page,
    );
    if (!mounted) return;
    setState(() {
      _users = res['users'] ?? [];
      _total = res['total'] ?? 0;
      _loading = false;
    });
  }

  void _search() {
    _page = 1;
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Users'), centerTitle: true),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Search by name, phone, email...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () { _searchCtrl.clear(); _search(); },
                ),
              ),
              onSubmitted: (_) => _search(),
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                _filterChip('All', ''),
                _filterChip('Passengers', 'passenger'),
                _filterChip('Drivers', 'driver'),
                _filterChip('Union Admins', 'union_admin'),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('$_total users', style: const TextStyle(fontSize: 13, color: Colors.black54)),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left),
                      onPressed: _page > 1 ? () { _page--; _load(); } : null,
                    ),
                    Text('Page $_page', style: const TextStyle(fontSize: 13)),
                    IconButton(
                      icon: const Icon(Icons.chevron_right),
                      onPressed: _users.length >= 20 ? () { _page++; _load(); } : null,
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _users.isEmpty
                    ? const Center(child: Text('No users found'))
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _users.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (ctx, i) => _buildUserTile(_users[i]),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _filterChip(String label, String value) {
    final selected = _roleFilter == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) {
          setState(() => _roleFilter = value);
          _page = 1;
          _load();
        },
      ),
    );
  }

  Widget _buildUserTile(dynamic user) {
    final name = user['name'] ?? 'Unknown';
    final role = user['role'] ?? '';
    final phone = user['phone'] ?? '';
    final email = user['email'] ?? '';
    final isActive = user['is_active'] ?? true;
    final id = user['id']?.toString() ?? '';

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(vertical: 4),
      leading: CircleAvatar(
        backgroundColor: isActive ? Colors.blue.shade50 : Colors.red.shade50,
        child: Icon(
          role == 'driver' ? Icons.directions_car : role == 'union_admin' ? Icons.business : Icons.person,
          color: isActive ? Colors.blue : Colors.red,
        ),
      ),
      title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
      subtitle: Text(
        '${phone.isNotEmpty ? phone : email} • $role${!isActive ? ' • SUSPENDED' : ''}',
        style: TextStyle(fontSize: 12, color: !isActive ? Colors.red : Colors.black54),
      ),
      trailing: const Icon(Icons.chevron_right, size: 20),
      onTap: () async {
        await Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => PlatformUserDetailScreen(userId: id)),
        );
        _load();
      },
    );
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }
}

// =============================================================================
// TRIPS TAB
// =============================================================================
class _TripsTab extends StatefulWidget {
  const _TripsTab();
  @override
  State<_TripsTab> createState() => _TripsTabState();
}

class _TripsTabState extends State<_TripsTab> {
  final _service = PlatformAdminService();
  final _searchCtrl = TextEditingController();
  List<dynamic> _trips = [];
  int _total = 0;
  int _page = 1;
  String _statusFilter = '';
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final res = await _service.getTrips(
      status: _statusFilter,
      search: _searchCtrl.text.trim(),
      page: _page,
    );
    if (!mounted) return;
    setState(() {
      _trips = res['trips'] ?? [];
      _total = res['total'] ?? 0;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Trips'), centerTitle: true),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Search route or driver...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () { _searchCtrl.clear(); _page = 1; _load(); },
                ),
              ),
              onSubmitted: (_) { _page = 1; _load(); },
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                _filterChip('All', ''),
                _filterChip('Scheduled', 'scheduled'),
                _filterChip('Active', 'in_progress'),
                _filterChip('Completed', 'completed'),
                _filterChip('Cancelled', 'cancelled'),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('$_total trips', style: const TextStyle(fontSize: 13, color: Colors.black54)),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left),
                      onPressed: _page > 1 ? () { _page--; _load(); } : null,
                    ),
                    Text('Page $_page', style: const TextStyle(fontSize: 13)),
                    IconButton(
                      icon: const Icon(Icons.chevron_right),
                      onPressed: _trips.length >= 20 ? () { _page++; _load(); } : null,
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _trips.isEmpty
                    ? const Center(child: Text('No trips found'))
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _trips.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (ctx, i) => _buildTripTile(_trips[i]),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _filterChip(String label, String value) {
    final selected = _statusFilter == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) {
          setState(() => _statusFilter = value);
          _page = 1;
          _load();
        },
      ),
    );
  }

  Widget _buildTripTile(dynamic trip) {
    final from = trip['from_location'] ?? '';
    final to = trip['to_location'] ?? '';
    final status = trip['status'] ?? '';
    final driver = trip['driver_name'] ?? '';
    final fare = trip['fare_per_seat'] ?? 0;
    final id = trip['id']?.toString() ?? '';

    Color statusColor;
    switch (status) {
      case 'scheduled': statusColor = Colors.blue; break;
      case 'in_progress': statusColor = Colors.green; break;
      case 'completed': statusColor = Colors.teal; break;
      case 'cancelled': statusColor = Colors.red; break;
      default: statusColor = Colors.grey;
    }

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(vertical: 4),
      leading: CircleAvatar(
        backgroundColor: statusColor.withValues(alpha: 0.1),
        child: Icon(Icons.directions_car, color: statusColor, size: 20),
      ),
      title: Text('$from → $to', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
      subtitle: Text('$driver • ₹$fare/seat • $status', style: const TextStyle(fontSize: 12, color: Colors.black54)),
      trailing: const Icon(Icons.chevron_right, size: 20),
      onTap: () async {
        await Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => PlatformTripDetailScreen(tripId: id)),
        );
        _load();
      },
    );
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }
}

// =============================================================================
// REVENUE TAB
// =============================================================================
class _RevenueTab extends StatefulWidget {
  const _RevenueTab();
  @override
  State<_RevenueTab> createState() => _RevenueTabState();
}

class _RevenueTabState extends State<_RevenueTab> {
  final _service = PlatformAdminService();
  Map<String, dynamic>? _data;
  String _period = 'month';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final res = await _service.getRevenueOverview(period: _period);
    if (!mounted) return;
    setState(() { _data = res; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Revenue'), centerTitle: true),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _data?['success'] != true
              ? Center(child: Text(_data?['message'] ?? 'Failed'))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Row(
                        children: [
                          _periodChip('Week', 'week'),
                          _periodChip('Month', 'month'),
                          _periodChip('All Time', 'all'),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _summaryCards(),
                      const SizedBox(height: 20),
                      const Text('Top Routes', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      _topRoutesList(),
                      const SizedBox(height: 20),
                      const Text('Top Drivers', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      _topDriversList(),
                    ],
                  ),
                ),
    );
  }

  Widget _periodChip(String label, String value) {
    final selected = _period == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) {
          setState(() => _period = value);
          _load();
        },
      ),
    );
  }

  Widget _summaryCards() {
    final summary = _data?['summary'] ?? {};
    final revenue = _toNum(summary['total_revenue']);
    final bookings = _toInt(summary['total_bookings']);
    final avg = _toNum(summary['avg_booking_amount']);

    return Row(
      children: [
        Expanded(child: _summaryCard('Revenue', '₹${revenue.toStringAsFixed(0)}', Icons.currency_rupee, Colors.green)),
        const SizedBox(width: 10),
        Expanded(child: _summaryCard('Bookings', '$bookings', Icons.bookmark, Colors.blue)),
        const SizedBox(width: 10),
        Expanded(child: _summaryCard('Avg/Trip', '₹${avg.toStringAsFixed(0)}', Icons.analytics, Colors.orange)),
      ],
    );
  }

  Widget _summaryCard(String label, String value, IconData icon, Color color) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 8),
            Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(fontSize: 11, color: Colors.black54)),
          ],
        ),
      ),
    );
  }

  Widget _topRoutesList() {
    final routes = (_data?['topRoutes'] as List?) ?? [];
    if (routes.isEmpty) return const Text('No data yet', style: TextStyle(color: Colors.black45));
    return Column(
      children: routes.take(5).map((r) {
        final from = r['from_location'] ?? '';
        final to = r['to_location'] ?? '';
        final count = _toInt(r['booking_count']);
        final rev = _toNum(r['route_revenue']);
        return ListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.route, size: 20, color: Colors.blueGrey),
          title: Text('$from → $to', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
          trailing: Text('$count trips • ₹${rev.toStringAsFixed(0)}', style: const TextStyle(fontSize: 12, color: Colors.black54)),
        );
      }).toList(),
    );
  }

  Widget _topDriversList() {
    final drivers = (_data?['topDrivers'] as List?) ?? [];
    if (drivers.isEmpty) return const Text('No data yet', style: TextStyle(color: Colors.black45));
    return Column(
      children: drivers.take(5).map((d) {
        final name = d['name'] ?? '';
        final trips = _toInt(d['trip_count']);
        final rating = _toNum(d['avg_rating']);
        return ListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          leading: const CircleAvatar(radius: 16, child: Icon(Icons.person, size: 18)),
          title: Text(name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
          trailing: Text('$trips trips • ★${rating.toStringAsFixed(1)}', style: const TextStyle(fontSize: 12, color: Colors.black54)),
        );
      }).toList(),
    );
  }

  double _toNum(dynamic v) => double.tryParse(v?.toString() ?? '') ?? 0;
  int _toInt(dynamic v) => int.tryParse(v?.toString() ?? '') ?? 0;
}

// =============================================================================
// MORE TAB  (Notifications · Complaints · KYC)
// =============================================================================
class _MoreTab extends StatefulWidget {
  const _MoreTab();
  @override
  State<_MoreTab> createState() => _MoreTabState();
}

class _MoreTabState extends State<_MoreTab> with TickerProviderStateMixin {
  late final TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('More'),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabCtrl,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: const [
            Tab(icon: Icon(Icons.campaign, size: 20), text: 'Notify'),
            Tab(icon: Icon(Icons.notifications_active, size: 20), text: 'Ride FCM'),
            Tab(icon: Icon(Icons.support_agent, size: 20), text: 'Complaints'),
            Tab(icon: Icon(Icons.verified_user, size: 20), text: 'KYC'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabCtrl,
        children: const [
          _NotificationsSection(),
          _UnionFcmSection(),
          _ComplaintsSection(),
          _KycSection(),
        ],
      ),
    );
  }
}

// --------------- Notifications Section ---------------
class _NotificationsSection extends StatefulWidget {
  const _NotificationsSection();
  @override
  State<_NotificationsSection> createState() => _NotificationsSectionState();
}

class _NotificationsSectionState extends State<_NotificationsSection> with AutomaticKeepAliveClientMixin {
  final _service = PlatformAdminService();
  final _titleCtrl = TextEditingController();
  final _bodyCtrl = TextEditingController();
  String _segment = 'all';
  bool _sending = false;
  List<dynamic> _history = [];
  bool _loadingHistory = true;

  static const _segments = <String, String>{
    'all': 'All Users',
    'passenger': 'Passengers',
    'driver': 'Drivers',
    'union_admin': 'Union Admins',
  };

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() => _loadingHistory = true);
    final res = await _service.getBroadcastHistory();
    if (!mounted) return;
    setState(() {
      _history = res['broadcasts'] ?? [];
      _loadingHistory = false;
    });
  }

  Future<void> _send() async {
    final title = _titleCtrl.text.trim();
    final body = _bodyCtrl.text.trim();
    if (title.isEmpty || body.isEmpty) {
      AppFeedback.show(context, 'Title and body are required', kind: AppFeedbackKind.warning);
      return;
    }
    setState(() => _sending = true);
    final res = await _service.sendBulkNotification(segment: _segment, title: title, body: body);
    if (!mounted) return;
    setState(() => _sending = false);
    if (res['success'] == true) {
      AppFeedback.show(context, 'Sent to ${res['sent_count'] ?? 0} users', kind: AppFeedbackKind.success);
      _titleCtrl.clear();
      _bodyCtrl.clear();
      _loadHistory();
    } else {
      AppFeedback.show(context, res['message'] ?? 'Failed', kind: AppFeedbackKind.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('Send Notification', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          value: _segment,
          decoration: const InputDecoration(labelText: 'Audience', border: OutlineInputBorder()),
          items: _segments.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))).toList(),
          onChanged: (v) => setState(() => _segment = v ?? 'all'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _titleCtrl,
          decoration: const InputDecoration(labelText: 'Title', border: OutlineInputBorder()),
          maxLength: 100,
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _bodyCtrl,
          decoration: const InputDecoration(labelText: 'Message', border: OutlineInputBorder()),
          maxLines: 3,
          maxLength: 500,
        ),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: _sending ? null : _send,
            icon: _sending
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.send),
            label: Text(_sending ? 'Sending...' : 'Send Notification'),
          ),
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            const Expanded(child: Text('History', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600))),
            IconButton(icon: const Icon(Icons.refresh, size: 20), onPressed: _loadHistory),
          ],
        ),
        const SizedBox(height: 8),
        if (_loadingHistory)
          const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()))
        else if (_history.isEmpty)
          const Text('No broadcasts sent yet', style: TextStyle(color: Colors.black45))
        else
          ..._history.map(_buildHistoryCard),
      ],
    );
  }

  Widget _buildHistoryCard(dynamic b) {
    final title = b['title'] ?? '';
    final body = b['body'] ?? '';
    final segment = b['segment'] ?? '';
    final count = b['sent_count'] ?? 0;
    final created = b['created_at'] ?? '';
    return Card(
      elevation: 0,
      color: Colors.grey.shade50,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(8)),
                  child: Text(segment, style: const TextStyle(fontSize: 11, color: Colors.blue)),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(body, style: const TextStyle(fontSize: 12, color: Colors.black54), maxLines: 2, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 6),
            Text('Sent to $count users • ${_formatDate(created)}', style: const TextStyle(fontSize: 11, color: Colors.black38)),
          ],
        ),
      ),
    );
  }

  String _formatDate(String? raw) {
    if (raw == null || raw.isEmpty) return '';
    final d = DateTime.tryParse(raw);
    if (d == null) return raw;
    return '${d.day}/${d.month}/${d.year} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _bodyCtrl.dispose();
    super.dispose();
  }
}

// --------------- Union FCM Section ---------------
class _UnionFcmSection extends StatefulWidget {
  const _UnionFcmSection();
  @override
  State<_UnionFcmSection> createState() => _UnionFcmSectionState();
}

class _UnionFcmSectionState extends State<_UnionFcmSection> with AutomaticKeepAliveClientMixin {
  final _service = PlatformAdminService();
  bool _loading = true;
  bool _globalEnabled = true;
  List<dynamic> _unions = [];
  String? _error;
  final Set<String> _toggling = {};

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    final res = await _service.getUnionFcmSettings();
    if (!mounted) return;
    if (res['success'] != true) {
      setState(() { _error = res['message']?.toString() ?? 'Failed to load'; _loading = false; });
      return;
    }
    setState(() {
      _globalEnabled = res['globalEnabled'] == true;
      _unions = res['unions'] ?? [];
      _loading = false;
    });
  }

  Future<void> _toggleGlobal(bool value) async {
    setState(() => _toggling.add('global'));
    final res = await _service.toggleGlobalUnionFcm(value);
    if (!mounted) return;
    setState(() => _toggling.remove('global'));
    if (res['success'] == true) {
      setState(() {
        _globalEnabled = value;
        final updated = res['unions'] as List?;
        if (updated != null) {
          _unions = updated;
        } else {
          for (final u in _unions) {
            u['fcm_enabled'] = value;
          }
        }
      });
      final count = _unions.length;
      AppFeedback.show(
        context,
        value ? 'Global FCM ON — सभी $count unions ON' : 'Global FCM OFF — सभी $count unions OFF',
        kind: AppFeedbackKind.success,
      );
    } else {
      AppFeedback.show(context, res['message'] ?? 'Failed', kind: AppFeedbackKind.error);
    }
  }

  Future<void> _toggleUnion(String unionId, bool value) async {
    setState(() => _toggling.add(unionId));
    final res = await _service.toggleUnionFcm(unionId, value);
    if (!mounted) return;
    setState(() => _toggling.remove(unionId));
    if (res['success'] == true) {
      setState(() {
        final idx = _unions.indexWhere((u) => u['id'] == unionId);
        if (idx >= 0) _unions[idx]['fcm_enabled'] = value;
      });
      AppFeedback.show(context, value ? 'FCM ON' : 'FCM OFF', kind: AppFeedbackKind.success);
    } else {
      AppFeedback.show(context, res['message'] ?? 'Failed', kind: AppFeedbackKind.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_loading) return const Center(child: CircularProgressIndicator());

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 48, color: Colors.red.shade300),
              const SizedBox(height: 12),
              Text(_error!, textAlign: TextAlign.center, style: TextStyle(color: Colors.red.shade700)),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    final enabledCount = _unions.where((u) => u['fcm_enabled'] == true).length;

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            elevation: 0,
            color: _globalEnabled ? Colors.green.shade50 : Colors.red.shade50,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Icon(
                    _globalEnabled ? Icons.notifications_active : Icons.notifications_off,
                    color: _globalEnabled ? Colors.green.shade700 : Colors.red.shade700,
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Global Ride FCM', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                        const SizedBox(height: 2),
                        Text(
                          _globalEnabled
                              ? 'Union ride notifications are ON for all'
                              : 'All union ride notifications are OFF',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),
                  _toggling.contains('global')
                      ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                      : Switch(
                          value: _globalEnabled,
                          onChanged: _toggleGlobal,
                          activeTrackColor: Colors.green.shade200,
                        ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Per-Union FCM Control (${_unions.length})',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ),
              ),
              if (_unions.isNotEmpty)
                Text(
                  '$enabledCount/${_unions.length} ON',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              IconButton(icon: const Icon(Icons.refresh, size: 20), onPressed: _load),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'First ride of each day per union sends FCM to all passengers.',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
          ),
          if (!_globalEnabled) ...[
            const SizedBox(height: 8),
            Text(
              'Global FCM OFF — कोई notification नहीं जाएगा। Individual toggle से सिर्फ preset सेट होगा।',
              style: TextStyle(fontSize: 12, color: Colors.orange.shade700, fontWeight: FontWeight.w500),
            ),
          ],
          const SizedBox(height: 12),
          if (_unions.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Text('No approved unions yet', style: TextStyle(color: Colors.black45)),
            )
          else
            ..._unions.map(_buildUnionRow),
        ],
      ),
    );
  }

  Widget _buildUnionRow(dynamic union) {
    final id = union['id']?.toString() ?? '';
    final name = union['name']?.toString() ?? 'Unknown';
    final enabled = union['fcm_enabled'] == true;
    final isToggling = _toggling.contains(id);

    return Card(
      elevation: 0,
      color: Colors.grey.shade50,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        child: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: enabled ? Colors.green.shade100 : Colors.grey.shade200,
              child: Icon(
                Icons.business,
                size: 18,
                color: enabled ? Colors.green.shade700 : Colors.grey,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(name, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14)),
            ),
            isToggling
                ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                : Switch(
                    value: enabled,
                    onChanged: (v) => _toggleUnion(id, v),
                    activeTrackColor: Colors.green.shade200,
                  ),
          ],
        ),
      ),
    );
  }
}

// --------------- Complaints Section ---------------
class _ComplaintsSection extends StatefulWidget {
  const _ComplaintsSection();
  @override
  State<_ComplaintsSection> createState() => _ComplaintsSectionState();
}

class _ComplaintsSectionState extends State<_ComplaintsSection> with AutomaticKeepAliveClientMixin {
  final _service = PlatformAdminService();
  List<dynamic> _complaints = [];
  int _total = 0;
  int _page = 1;
  String _statusFilter = '';
  bool _loading = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final res = await _service.getComplaints(status: _statusFilter, page: _page);
    if (!mounted) return;
    setState(() {
      _complaints = res['complaints'] ?? [];
      _total = res['total'] ?? 0;
      _loading = false;
    });
  }

  Future<void> _showResolveDialog(dynamic complaint) async {
    final id = complaint['id']?.toString() ?? '';
    if (id.isEmpty) return;
    final noteCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Resolve Complaint'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Subject: ${complaint['subject'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text(complaint['body'] ?? '', style: const TextStyle(fontSize: 13, color: Colors.black54)),
            const SizedBox(height: 12),
            TextField(
              controller: noteCtrl,
              decoration: const InputDecoration(labelText: 'Resolution note', border: OutlineInputBorder()),
              maxLines: 3,
              maxLength: 500,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Resolve')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final note = noteCtrl.text.trim();
    if (note.isEmpty) {
      AppFeedback.show(context, 'Resolution note is required', kind: AppFeedbackKind.warning);
      noteCtrl.dispose();
      return;
    }
    final res = await _service.resolveComplaint(id, note: note);
    noteCtrl.dispose();
    if (!mounted) return;
    if (res['success'] == true) {
      AppFeedback.show(context, 'Complaint resolved', kind: AppFeedbackKind.success);
      _load();
    } else {
      AppFeedback.show(context, res['message'] ?? 'Failed', kind: AppFeedbackKind.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Column(
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Row(
            children: [
              _filterChip('All', ''),
              _filterChip('Open', 'open'),
              _filterChip('Resolved', 'resolved'),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('$_total complaints', style: const TextStyle(fontSize: 13, color: Colors.black54)),
              Row(children: [
                IconButton(icon: const Icon(Icons.chevron_left), onPressed: _page > 1 ? () { _page--; _load(); } : null),
                Text('Page $_page', style: const TextStyle(fontSize: 13)),
                IconButton(icon: const Icon(Icons.chevron_right), onPressed: _complaints.length >= 20 ? () { _page++; _load(); } : null),
              ]),
            ],
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _complaints.isEmpty
                  ? const Center(child: Text('No complaints'))
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _complaints.length,
                        itemBuilder: (ctx, i) => _buildComplaintCard(_complaints[i]),
                      ),
                    ),
        ),
      ],
    );
  }

  Widget _filterChip(String label, String value) {
    final selected = _statusFilter == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) { setState(() => _statusFilter = value); _page = 1; _load(); },
      ),
    );
  }

  Widget _buildComplaintCard(dynamic c) {
    final subject = c['subject'] ?? '';
    final body = c['body'] ?? '';
    final status = c['status'] ?? 'open';
    final userName = c['user_name'] ?? 'Unknown';
    final userPhone = c['user_phone'] ?? '';
    final created = c['created_at'] ?? '';
    final isOpen = status == 'open';

    return Card(
      elevation: 0,
      color: isOpen ? Colors.orange.shade50 : Colors.green.shade50,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: isOpen ? () => _showResolveDialog(c) : null,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: Text(subject, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14))),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: isOpen ? Colors.orange.shade100 : Colors.green.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(status.toUpperCase(), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: isOpen ? Colors.orange.shade800 : Colors.green.shade800)),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(body, style: const TextStyle(fontSize: 12, color: Colors.black54), maxLines: 2, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 6),
              Text('$userName${userPhone.isNotEmpty ? ' • $userPhone' : ''} • ${_formatDate(created)}',
                  style: const TextStyle(fontSize: 11, color: Colors.black38)),
              if (!isOpen && c['resolution_note'] != null) ...[
                const SizedBox(height: 6),
                Text('Resolution: ${c['resolution_note']}', style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: Colors.green.shade700)),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(String? raw) {
    if (raw == null || raw.isEmpty) return '';
    final d = DateTime.tryParse(raw);
    if (d == null) return raw;
    return '${d.day}/${d.month}/${d.year} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }
}


// =============================================================================
// KYC SECTION — Driver & Union verification requests
// =============================================================================
class _KycSection extends StatefulWidget {
  const _KycSection();
  @override
  State<_KycSection> createState() => _KycSectionState();
}

class _KycSectionState extends State<_KycSection> with AutomaticKeepAliveClientMixin {
  final _adminService = AdminService();
  List<dynamic> _driverRequests = [];
  List<dynamic> _unionRequests = [];
  bool _loading = true;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final driverRes = await _adminService.getDriverRequests();
    final unionRes = await _adminService.getUnionRequests();
    if (!mounted) return;
    setState(() {
      _driverRequests = driverRes['requests'] ?? [];
      _unionRequests = unionRes['requests'] ?? [];
      _loading = false;
    });
  }

  Future<void> _approveDriver(String requestId) async {
    final confirmed = await _confirmDialog('Approve Driver', 'Approve this driver verification request?');
    if (confirmed != true || !mounted) return;
    final res = await _adminService.approveDriver(requestId);
    if (!mounted) return;
    if (res['success'] == true) {
      AppFeedback.show(context, 'Driver approved', kind: AppFeedbackKind.success);
      _load();
    } else {
      AppFeedback.show(context, res['message'] ?? 'Failed', kind: AppFeedbackKind.error);
    }
  }

  Future<void> _rejectDriver(String requestId) async {
    final reasonCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reject Driver'),
        content: TextField(
          controller: reasonCtrl,
          decoration: const InputDecoration(labelText: 'Reason', border: OutlineInputBorder()),
          maxLines: 2,
          maxLength: 300,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final res = await _adminService.rejectDriver(requestId, reason: reasonCtrl.text.trim());
    reasonCtrl.dispose();
    if (!mounted) return;
    if (res['success'] == true) {
      AppFeedback.show(context, 'Request rejected', kind: AppFeedbackKind.success);
      _load();
    } else {
      AppFeedback.show(context, res['message'] ?? 'Failed', kind: AppFeedbackKind.error);
    }
  }

  Future<void> _approveUnion(String unionId) async {
    final confirmed = await _confirmDialog('Approve Union', 'Approve this union registration?');
    if (confirmed != true || !mounted) return;
    final res = await _adminService.approveUnion(unionId);
    if (!mounted) return;
    if (res['success'] == true) {
      AppFeedback.show(context, 'Union approved', kind: AppFeedbackKind.success);
      _load();
    } else {
      AppFeedback.show(context, res['message'] ?? 'Failed', kind: AppFeedbackKind.error);
    }
  }

  Future<void> _rejectUnion(String unionId) async {
    final confirmed = await _confirmDialog('Reject Union', 'Reject this union registration request?');
    if (confirmed != true || !mounted) return;
    final res = await _adminService.rejectUnion(unionId);
    if (!mounted) return;
    if (res['success'] == true) {
      AppFeedback.show(context, 'Union rejected', kind: AppFeedbackKind.success);
      _load();
    } else {
      AppFeedback.show(context, res['message'] ?? 'Failed', kind: AppFeedbackKind.error);
    }
  }

  Future<bool?> _confirmDialog(String title, String message) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Confirm')),
        ],
      ),
    );
  }

  void _viewDocument(String url, String label) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SimpleKycPreviewScreen(url: url, label: label, useAdminFileApi: true),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              const Expanded(child: Text('Pending Driver KYC', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600))),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: Colors.deepOrange.shade50, borderRadius: BorderRadius.circular(12)),
                child: Text('${_driverRequests.length}', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.deepOrange.shade700)),
              ),
              const SizedBox(width: 8),
              IconButton(icon: const Icon(Icons.refresh, size: 20), onPressed: _load),
            ],
          ),
          const SizedBox(height: 8),
          if (_driverRequests.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text('No pending driver requests', style: TextStyle(color: Colors.black45)),
            )
          else
            ..._driverRequests.map(_buildDriverCard),
          const SizedBox(height: 24),
          Row(
            children: [
              const Expanded(child: Text('Pending Union Registrations', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600))),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: Colors.purple.shade50, borderRadius: BorderRadius.circular(12)),
                child: Text('${_unionRequests.length}', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.purple.shade700)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_unionRequests.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text('No pending union requests', style: TextStyle(color: Colors.black45)),
            )
          else
            ..._unionRequests.map(_buildUnionCard),
        ],
      ),
    );
  }

  Widget _buildDriverCard(dynamic req) {
    final id = req['id']?.toString() ?? '';
    final name = req['name'] ?? 'Unknown';
    final phone = req['phone'] ?? '';
    final vehicleType = req['vehicle_type'] ?? '';
    final vehicleModel = req['vehicle_model'] ?? '';
    final licenseNum = req['driving_license_number'] ?? '';

    final docUrls = <String, String>{};
    if (_hasUrl(req['aadhaar_document_url'])) docUrls['Aadhaar'] = req['aadhaar_document_url'];
    if (_hasUrl(req['aadhaar_front_url'])) docUrls['Aadhaar Front'] = req['aadhaar_front_url'];
    if (_hasUrl(req['aadhaar_back_url'])) docUrls['Aadhaar Back'] = req['aadhaar_back_url'];
    if (_hasUrl(req['driving_license_url'])) docUrls['DL'] = req['driving_license_url'];
    if (_hasUrl(req['driving_license_front_url'])) docUrls['DL Front'] = req['driving_license_front_url'];
    if (_hasUrl(req['driving_license_back_url'])) docUrls['DL Back'] = req['driving_license_back_url'];
    if (_hasUrl(req['rc_document_url'])) docUrls['RC'] = req['rc_document_url'];
    if (_hasUrl(req['rc_front_url'])) docUrls['RC Front'] = req['rc_front_url'];
    if (_hasUrl(req['rc_back_url'])) docUrls['RC Back'] = req['rc_back_url'];
    if (_hasUrl(req['permit_document_url'])) docUrls['Permit'] = req['permit_document_url'];
    if (_hasUrl(req['insurance_document_url'])) docUrls['Insurance'] = req['insurance_document_url'];

    return Card(
      elevation: 0,
      color: Colors.orange.shade50,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: Colors.orange.shade100,
                  child: const Icon(Icons.person, color: Colors.deepOrange),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                      Text('$phone${vehicleType.isNotEmpty ? ' • $vehicleType' : ''}',
                          style: const TextStyle(fontSize: 12, color: Colors.black54)),
                    ],
                  ),
                ),
              ],
            ),
            if (vehicleModel.isNotEmpty || licenseNum.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                '${vehicleModel.isNotEmpty ? "Vehicle: $vehicleModel" : ""}${licenseNum.isNotEmpty ? " • DL: $licenseNum" : ""}',
                style: const TextStyle(fontSize: 12, color: Colors.black54),
              ),
            ],
            if (docUrls.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: docUrls.entries.map((e) => ActionChip(
                  avatar: const Icon(Icons.visibility, size: 16),
                  label: Text(e.key, style: const TextStyle(fontSize: 11)),
                  onPressed: () => _viewDocument(e.value, e.key),
                  visualDensity: VisualDensity.compact,
                )).toList(),
              ),
            ],
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _rejectDriver(id),
                    style: OutlinedButton.styleFrom(foregroundColor: Colors.red, side: const BorderSide(color: Colors.red)),
                    child: const Text('Reject'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    onPressed: () => _approveDriver(id),
                    style: FilledButton.styleFrom(backgroundColor: Colors.green),
                    child: const Text('Approve'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUnionCard(dynamic req) {
    final id = req['id']?.toString() ?? '';
    final name = req['name'] ?? 'Unknown';
    final registrationNumber = req['registration_number'] ?? '';
    final applicantName = req['applicant_name'] ?? '';
    final applicantPhone = req['applicant_phone'] ?? '';

    final docUrls = <String, String>{};
    if (_hasUrl(req['owner_aadhaar_url'])) docUrls['Aadhaar'] = req['owner_aadhaar_url'];
    if (_hasUrl(req['owner_aadhaar_front_url'])) docUrls['Aadhaar Front'] = req['owner_aadhaar_front_url'];
    if (_hasUrl(req['owner_aadhaar_back_url'])) docUrls['Aadhaar Back'] = req['owner_aadhaar_back_url'];
    if (_hasUrl(req['owner_vehicle_rc_url'])) docUrls['Vehicle RC'] = req['owner_vehicle_rc_url'];
    if (_hasUrl(req['owner_vehicle_rc_front_url'])) docUrls['RC Front'] = req['owner_vehicle_rc_front_url'];
    if (_hasUrl(req['owner_vehicle_rc_back_url'])) docUrls['RC Back'] = req['owner_vehicle_rc_back_url'];
    if (_hasUrl(req['leader_driving_license_front_url'])) docUrls['DL Front'] = req['leader_driving_license_front_url'];
    if (_hasUrl(req['leader_driving_license_back_url'])) docUrls['DL Back'] = req['leader_driving_license_back_url'];
    if (_hasUrl(req['office_photo_url'])) docUrls['Office'] = req['office_photo_url'];
    if (_hasUrl(req['union_photo_url'])) docUrls['Union Photo'] = req['union_photo_url'];
    if (_hasUrl(req['union_driver_list_photo_url'])) docUrls['Driver List'] = req['union_driver_list_photo_url'];

    return Card(
      elevation: 0,
      color: Colors.purple.shade50,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: Colors.purple.shade100,
                  child: const Icon(Icons.business, color: Colors.purple),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                      if (registrationNumber.isNotEmpty)
                        Text('Reg: $registrationNumber', style: const TextStyle(fontSize: 12, color: Colors.black54)),
                    ],
                  ),
                ),
              ],
            ),
            if (applicantName.isNotEmpty || applicantPhone.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                'Applicant: $applicantName${applicantPhone.isNotEmpty ? ' • $applicantPhone' : ''}',
                style: const TextStyle(fontSize: 12, color: Colors.black54),
              ),
            ],
            if (docUrls.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: docUrls.entries.map((e) => ActionChip(
                  avatar: const Icon(Icons.visibility, size: 16),
                  label: Text(e.key, style: const TextStyle(fontSize: 11)),
                  onPressed: () => _viewDocument(e.value, e.key),
                  visualDensity: VisualDensity.compact,
                )).toList(),
              ),
            ],
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _rejectUnion(id),
                    style: OutlinedButton.styleFrom(foregroundColor: Colors.red, side: const BorderSide(color: Colors.red)),
                    child: const Text('Reject'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    onPressed: () => _approveUnion(id),
                    style: FilledButton.styleFrom(backgroundColor: Colors.green),
                    child: const Text('Approve'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  bool _hasUrl(dynamic url) => url != null && url.toString().trim().isNotEmpty;
}

// =============================================================================
// CREATE RIDE SECTION — links to existing union & independent driver ride features
