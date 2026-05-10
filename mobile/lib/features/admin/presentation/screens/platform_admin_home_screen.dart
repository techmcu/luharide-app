import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/feedback/app_feedback.dart';
import '../../../../services/platform_admin_service.dart';
import '../../../../utils/launch_whatsapp.dart';
import 'platform_user_detail_screen.dart';
import 'platform_trip_detail_screen.dart';
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Platform Admin'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.admin_panel_settings_outlined),
            tooltip: 'Union Admin View',
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
                      _sectionTitle('Trips'),
                      const SizedBox(height: 8),
                      _statsRow([
                        _StatItem('Total', _data?['total_trips'] ?? 0, Icons.route, Colors.blueGrey),
                        _StatItem('Scheduled', _data?['scheduled_trips'] ?? 0, Icons.schedule, Colors.blue),
                        _StatItem('Active', _data?['active_trips'] ?? 0, Icons.play_arrow, Colors.green),
                        _StatItem('Completed', _data?['completed_trips'] ?? 0, Icons.check_circle, Colors.teal),
                      ]),
                      const SizedBox(height: 12),
                      _statsRow([
                        _StatItem('Cancelled', _data?['cancelled_trips'] ?? 0, Icons.cancel, Colors.red),
                        _StatItem('Today', _data?['today_trips'] ?? 0, Icons.today, Colors.indigo),
                        _StatItem('Active Drivers', _data?['active_drivers'] ?? 0, Icons.local_taxi, Colors.amber),
                        _StatItem('New (7d)', _data?['new_users_week'] ?? 0, Icons.person_add, Colors.pink),
                      ]),
                      const SizedBox(height: 20),
                      _sectionTitle('Bookings'),
                      const SizedBox(height: 8),
                      _statsRow([
                        _StatItem('Confirmed', _data?['confirmed_bookings'] ?? 0, Icons.bookmark_added, Colors.green),
                        _StatItem('Pending', _data?['pending_bookings'] ?? 0, Icons.pending_actions, Colors.orange),
                        _StatItem('Cancelled', _data?['cancelled_bookings'] ?? 0, Icons.bookmark_remove, Colors.red),
                      ]),
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
// MORE TAB  (Notifications · Complaints · App Config)
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
            Tab(icon: Icon(Icons.support_agent, size: 20), text: 'Complaints'),
            Tab(icon: Icon(Icons.settings, size: 20), text: 'Config'),
            Tab(icon: Icon(Icons.image_search, size: 20), text: 'Quick Ride'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabCtrl,
        children: const [
          _NotificationsSection(),
          _ComplaintsSection(),
          _ConfigSection(),
          _PosterRideSection(),
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
          initialValue: _segment,
          decoration: const InputDecoration(labelText: 'Audience', border: OutlineInputBorder()),
          items: _segments.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))).toList(),
          onChanged: (v) => setState(() => _segment = v ?? 'all'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _titleCtrl,
          decoration: const InputDecoration(labelText: 'Title', border: OutlineInputBorder()),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _bodyCtrl,
          decoration: const InputDecoration(labelText: 'Message', border: OutlineInputBorder()),
          maxLines: 3,
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

// --------------- Config Section ---------------
class _ConfigSection extends StatefulWidget {
  const _ConfigSection();
  @override
  State<_ConfigSection> createState() => _ConfigSectionState();
}

class _ConfigSectionState extends State<_ConfigSection> with AutomaticKeepAliveClientMixin {
  final _service = PlatformAdminService();
  bool _loading = true;
  bool _saving = false;
  bool _maintenanceMode = false;
  final _maintenanceMsgCtrl = TextEditingController();
  final _minVersionCtrl = TextEditingController();

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final res = await _service.getAppConfig();
    if (!mounted) return;
    final config = res['config'];
    if (config is Map) {
      _maintenanceMode = config['maintenance_mode'] == 'true' || config['maintenance_mode'] == true;
      _maintenanceMsgCtrl.text = config['maintenance_message']?.toString() ?? '';
      _minVersionCtrl.text = config['force_update_min_version']?.toString() ?? '';
    }
    setState(() => _loading = false);
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final res = await _service.updateAppConfig({
      'maintenance_mode': _maintenanceMode.toString(),
      'maintenance_message': _maintenanceMsgCtrl.text.trim(),
      'force_update_min_version': _minVersionCtrl.text.trim(),
    });
    if (!mounted) return;
    setState(() => _saving = false);
    if (res['success'] == true) {
      AppFeedback.show(context, 'Config saved', kind: AppFeedbackKind.success);
    } else {
      AppFeedback.show(context, res['message'] ?? 'Failed', kind: AppFeedbackKind.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_loading) return const Center(child: CircularProgressIndicator());
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('App Configuration', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        const SizedBox(height: 16),
        SwitchListTile(
          title: const Text('Maintenance Mode'),
          subtitle: const Text('Blocks app access for all users'),
          value: _maintenanceMode,
          onChanged: (v) => setState(() => _maintenanceMode = v),
          contentPadding: EdgeInsets.zero,
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _maintenanceMsgCtrl,
          decoration: const InputDecoration(labelText: 'Maintenance Message', border: OutlineInputBorder(), hintText: 'e.g. We are upgrading. Back soon!'),
          maxLines: 2,
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _minVersionCtrl,
          decoration: const InputDecoration(labelText: 'Min App Version (force update)', border: OutlineInputBorder(), hintText: 'e.g. 2.0.0'),
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.save),
            label: Text(_saving ? 'Saving...' : 'Save Config'),
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _maintenanceMsgCtrl.dispose();
    _minVersionCtrl.dispose();
    super.dispose();
  }
}

// =============================================================================
// POSTER-TO-RIDE SECTION  (upload poster → OCR → editable table → save to DB)
// =============================================================================
class _PosterRideSection extends StatefulWidget {
  const _PosterRideSection();
  @override
  State<_PosterRideSection> createState() => _PosterRideSectionState();
}

class _PosterRideSectionState extends State<_PosterRideSection> with AutomaticKeepAliveClientMixin {
  final _service = PlatformAdminService();
  final _picker = ImagePicker();

  final _notesCtrl = TextEditingController();

  DateTime? _departureDate;
  TimeOfDay? _departureTime;

  bool _parsing = false;
  bool _creating = false;
  List<String> _warnings = [];
  String _rawText = '';
  List<Map<String, dynamic>> _parsedRides = [];
  List<dynamic> _adminRides = [];
  bool _loadingRides = true;
  bool _showForm = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadRides();
  }

  Future<void> _loadRides() async {
    setState(() => _loadingRides = true);
    final res = await _service.getAdminRides();
    if (!mounted) return;
    setState(() { _adminRides = res['rides'] ?? []; _loadingRides = false; });
  }

  void _resetForm() {
    _notesCtrl.clear();
    _departureDate = null; _departureTime = null;
    _warnings = []; _rawText = ''; _parsedRides = [];
  }

  Map<String, dynamic> _emptyRide() => {
    'driver_name': '',
    'contact_number': '',
    'from_location': '',
    'to_location': '',
    'vehicle_type': '',
  };

  Future<void> _pickAndParse() async {
    final source = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
        ListTile(leading: const Icon(Icons.camera_alt), title: const Text('Camera'), onTap: () => Navigator.pop(ctx, 'camera')),
        ListTile(leading: const Icon(Icons.photo_library), title: const Text('Gallery'), onTap: () => Navigator.pop(ctx, 'gallery')),
      ])),
    );
    if (source == null || !mounted) return;

    final xFile = await _picker.pickImage(
      source: source == 'camera' ? ImageSource.camera : ImageSource.gallery,
      imageQuality: 80, maxWidth: 1600, maxHeight: 2000,
    );
    if (xFile == null) return;

    setState(() { _parsing = true; _warnings = []; _parsedRides = []; });
    final bytes = await xFile.readAsBytes();
    final res = await _service.parsePoster(bytes, xFile.name);
    if (!mounted) return;

    if (res['success'] == true) {
      final shared = res['shared'];
      if (shared is Map) {
        final dateStr = shared['departure_date']?.toString() ?? '';
        if (dateStr.isNotEmpty) _departureDate = DateTime.tryParse(dateStr);
        final timeStr = shared['departure_time']?.toString() ?? '';
        if (timeStr.contains(':')) {
          final tp = timeStr.split(':');
          _departureTime = TimeOfDay(hour: int.tryParse(tp[0]) ?? 8, minute: int.tryParse(tp[1]) ?? 0);
        }

        if (shared['date_is_past'] == true && mounted) {
          AppFeedback.show(context, 'Poster date is old — review before saving', kind: AppFeedbackKind.warning);
        }
      }

      final rides = res['rides'];
      if (rides is List && rides.isNotEmpty) {
        _parsedRides = rides.map<Map<String, dynamic>>((r) => {
          'driver_name': r['driver_name']?.toString() ?? '',
          'contact_number': r['contact_number']?.toString() ?? '',
          'from_location': r['from_location']?.toString() ?? '',
          'to_location': r['to_location']?.toString() ?? '',
          'vehicle_type': r['vehicle_type']?.toString() ?? '',
        }).toList();
      }

      _rawText = res['raw_text']?.toString() ?? '';
      final w = res['warnings'];
      if (w is List) _warnings = w.map((e) => e.toString()).toList();

      setState(() { _parsing = false; _showForm = _parsedRides.isNotEmpty; });
      if (_parsedRides.isEmpty && mounted) {
        AppFeedback.show(context, 'No ride entries found in poster', kind: AppFeedbackKind.warning);
      }
    } else {
      setState(() => _parsing = false);
      if (mounted) AppFeedback.show(context, res['message'] ?? 'Parse failed', kind: AppFeedbackKind.error);
    }
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _departureDate ?? DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (d != null) setState(() => _departureDate = d);
  }

  Future<void> _pickTime() async {
    final t = await showTimePicker(context: context, initialTime: _departureTime ?? const TimeOfDay(hour: 8, minute: 0));
    if (t != null) setState(() => _departureTime = t);
  }

  Future<void> _saveAllRides() async {
    if (_departureDate == null || _departureTime == null) {
      AppFeedback.show(context, 'Select date and time', kind: AppFeedbackKind.warning);
      return;
    }
    final depDt = DateTime(_departureDate!.year, _departureDate!.month, _departureDate!.day, _departureTime!.hour, _departureTime!.minute);
    final isPastDate = depDt.isBefore(DateTime.now());
    if (isPastDate) {
      final proceed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Date is in the past'),
          content: const Text('The departure date is before today. Are you sure you want to upload these rides?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Upload Anyway')),
          ],
        ),
      );
      if (proceed != true || !mounted) return;
    }
    if (_parsedRides.isEmpty) {
      AppFeedback.show(context, 'No rides to save', kind: AppFeedbackKind.warning);
      return;
    }
    for (int i = 0; i < _parsedRides.length; i++) {
      final r = _parsedRides[i];
      final from = (r['from_location'] ?? '').toString().trim();
      final to = (r['to_location'] ?? '').toString().trim();
      final c = (r['contact_number'] ?? '').toString().trim();
      if (from.isEmpty || to.isEmpty) {
        AppFeedback.show(context, 'Ride #${i + 1} is missing From or To', kind: AppFeedbackKind.warning);
        return;
      }
      if (c.isEmpty) {
        AppFeedback.show(context, 'Ride #${i + 1} is missing contact number', kind: AppFeedbackKind.warning);
        return;
      }
    }

    setState(() => _creating = true);
    final res = await _service.createAdminRide({
      'departure_time': depDt.toIso8601String(),
      'rides': _parsedRides.map((r) => {
        'driver_name': (r['driver_name'] ?? '').toString().trim(),
        'contact_number': (r['contact_number'] ?? '').toString().trim(),
        'from_location': (r['from_location'] ?? '').toString().trim(),
        'to_location': (r['to_location'] ?? '').toString().trim(),
        'vehicle_type': (r['vehicle_type'] ?? '').toString().trim(),
        'admin_notes': _notesCtrl.text.trim(),
      }).toList(),
    });
    if (!mounted) return;
    setState(() => _creating = false);

    if (res['success'] == true) {
      final count = res['created_count'] ?? _parsedRides.length;
      AppFeedback.show(context, '$count rides saved to database', kind: AppFeedbackKind.success);
      _resetForm();
      setState(() => _showForm = false);
      _loadRides();
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
        Row(children: [
          Expanded(child: FilledButton.icon(
            onPressed: _parsing ? null : _pickAndParse,
            icon: _parsing
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.image_search),
            label: Text(_parsing ? 'Reading...' : 'Upload Poster'),
          )),
          const SizedBox(width: 10),
          OutlinedButton.icon(
            onPressed: () {
              _resetForm();
              _parsedRides = List.generate(3, (_) => _emptyRide());
              setState(() => _showForm = true);
            },
            icon: const Icon(Icons.edit_note),
            label: const Text('Manual'),
          ),
        ]),

        if (_parsing) ...[
          const SizedBox(height: 16),
          const Center(child: Column(children: [
            CircularProgressIndicator(),
            SizedBox(height: 8),
            Text('Reading poster (OCR)...', style: TextStyle(fontSize: 13, color: Colors.black54)),
          ])),
        ],

        if (_warnings.isNotEmpty) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: Colors.amber.shade50, borderRadius: BorderRadius.circular(8)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: _warnings.map((w) => Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Icon(Icons.warning_amber, size: 15, color: Colors.orange.shade700),
                  const SizedBox(width: 6),
                  Expanded(child: Text(w, style: TextStyle(fontSize: 12, color: Colors.orange.shade900))),
                ]),
              )).toList(),
            ),
          ),
        ],

        if (_showForm) ...[
          const SizedBox(height: 16),
          Card(
            elevation: 1,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Date & Time', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text('Common for all ${_parsedRides.length} rides', style: const TextStyle(fontSize: 12, color: Colors.black45)),
                const Divider(),
                Row(children: [
                  const Icon(Icons.calendar_today, size: 16, color: Colors.black45),
                  const SizedBox(width: 8),
                  const Text('Date & Time', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Colors.black54)),
                  const Spacer(),
                  TextButton(
                    onPressed: _pickDate,
                    child: Text(_departureDate != null
                        ? '${_departureDate!.day}/${_departureDate!.month}/${_departureDate!.year}'
                        : 'Select Date', style: const TextStyle(fontSize: 13)),
                  ),
                  TextButton(
                    onPressed: _pickTime,
                    child: Text(_departureTime != null
                        ? '${_departureTime!.hour.toString().padLeft(2, '0')}:${_departureTime!.minute.toString().padLeft(2, '0')}'
                        : 'Select Time', style: const TextStyle(fontSize: 13)),
                  ),
                ]),
                const Divider(),
                TextField(
                  controller: _notesCtrl,
                  decoration: const InputDecoration(
                    hintText: 'Extra notes (optional)',
                    border: InputBorder.none, isDense: true,
                    contentPadding: EdgeInsets.symmetric(vertical: 6),
                  ),
                  maxLines: 2, style: const TextStyle(fontSize: 13),
                ),
              ]),
            ),
          ),

          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: Row(children: [
              const Text('Rides', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: Colors.indigo.shade100, borderRadius: BorderRadius.circular(10)),
                child: Text('${_parsedRides.length}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.indigo)),
              ),
            ])),
            if (_parsedRides.length < 20)
              IconButton(
                icon: const Icon(Icons.add_circle_outline, size: 22),
                tooltip: 'Add ride',
                onPressed: () => setState(() => _parsedRides.add(_emptyRide())),
              ),
          ]),
          const SizedBox(height: 8),

          ...List.generate(_parsedRides.length, (i) => _buildEditableRideCard(i)),

          if (_rawText.isNotEmpty) ...[
            const SizedBox(height: 4),
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: const Text('Raw OCR Text', style: TextStyle(fontSize: 12, color: Colors.black45)),
              children: [Container(
                width: double.infinity, padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8)),
                child: Text(_rawText, style: const TextStyle(fontSize: 11, fontFamily: 'monospace')),
              )],
            ),
          ],

          const SizedBox(height: 14),
          SizedBox(width: double.infinity, child: FilledButton.icon(
            onPressed: _creating ? null : _saveAllRides,
            icon: _creating
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.save),
            label: Text(_creating ? 'Saving...' : 'Save ${_parsedRides.length} Rides to Database'),
            style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
          )),
        ],

        const SizedBox(height: 24),
        Row(children: [
          const Expanded(child: Text('Admin Rides', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600))),
          IconButton(icon: const Icon(Icons.refresh, size: 20), onPressed: _loadRides),
        ]),
        const SizedBox(height: 8),
        if (_loadingRides)
          const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()))
        else if (_adminRides.isEmpty)
          const Text('No rides created yet', style: TextStyle(color: Colors.black45))
        else
          ..._adminRides.map(_buildRideCard),
      ],
    );
  }

  Widget _buildEditableRideCard(int index) {
    return Card(
      elevation: 0,
      color: Colors.grey.shade50,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              width: 24, height: 24,
              decoration: BoxDecoration(color: Colors.indigo.shade100, shape: BoxShape.circle),
              alignment: Alignment.center,
              child: Text('${index + 1}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.indigo)),
            ),
            const SizedBox(width: 8),
            Text('Ride #${index + 1}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            const Spacer(),
            if (_parsedRides.length > 1)
              IconButton(
                icon: Icon(Icons.close, size: 18, color: Colors.red.shade400),
                tooltip: 'Remove ride',
                onPressed: () => setState(() => _parsedRides.removeAt(index)),
                padding: EdgeInsets.zero, constraints: const BoxConstraints(),
              ),
          ]),
          const SizedBox(height: 6),
          _rideField(index, 'from_location', 'From', Icons.location_on),
          _rideField(index, 'to_location', 'To', Icons.flag),
          _rideField(index, 'driver_name', 'Driver', Icons.person),
          _rideField(index, 'contact_number', 'Contact', Icons.phone, keyboard: TextInputType.phone),
          _rideField(index, 'vehicle_type', 'Vehicle', Icons.directions_car),
        ]),
      ),
    );
  }

  Widget _rideField(int index, String key, String label, IconData icon, {TextInputType? keyboard}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(children: [
        Icon(icon, size: 14, color: Colors.black38),
        const SizedBox(width: 8),
        SizedBox(width: 75, child: Text(label, style: const TextStyle(fontSize: 12, color: Colors.black54))),
        Expanded(child: TextFormField(
          initialValue: _parsedRides[index][key]?.toString() ?? '',
          keyboardType: keyboard,
          decoration: const InputDecoration(
            border: InputBorder.none, isDense: true,
            contentPadding: EdgeInsets.symmetric(vertical: 4, horizontal: 6),
          ),
          style: const TextStyle(fontSize: 13),
          onChanged: (v) => _parsedRides[index][key] = v,
        )),
      ]),
    );
  }

  Widget _buildRideCard(dynamic ride) {
    final from = ride['from_location'] ?? '';
    final to = ride['to_location'] ?? '';
    final status = ride['status'] ?? '';
    final driverName = ride['poster_driver_name'] ?? '';
    final contact = (ride['poster_contact'] ?? '').toString();
    final vehicle = ride['vehicle_number'] ?? '';
    final created = ride['created_at'] ?? '';

    Color statusColor;
    switch (status) {
      case 'scheduled': statusColor = Colors.blue; break;
      case 'in_progress': statusColor = Colors.green; break;
      case 'completed': statusColor = Colors.teal; break;
      case 'cancelled': statusColor = Colors.red; break;
      default: statusColor = Colors.grey;
    }

    return Card(
      elevation: 0,
      color: Colors.indigo.shade50,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text('$from → $to', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14))),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
              child: Text(status.toUpperCase(), style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: statusColor)),
            ),
          ]),
          const SizedBox(height: 6),
          _rideInfoRow(Icons.person, driverName),
          if (vehicle.isNotEmpty) _rideInfoRow(Icons.directions_car, vehicle),
          const SizedBox(height: 8),
          if (contact.isNotEmpty) Row(children: [
            Expanded(child: OutlinedButton.icon(
              onPressed: () async {
                try { await launchUrl(Uri.parse('tel:$contact')); } catch (_) {}
              },
              icon: const Icon(Icons.call, size: 16),
              label: const Text('Call', style: TextStyle(fontSize: 12)),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.green.shade700,
                side: BorderSide(color: Colors.green.shade300),
                padding: const EdgeInsets.symmetric(vertical: 6),
              ),
            )),
            const SizedBox(width: 8),
            Expanded(child: OutlinedButton.icon(
              onPressed: () async {
                try { await launchWhatsApp(contact); } catch (_) {}
              },
              icon: const Icon(Icons.chat, size: 16),
              label: const Text('WhatsApp', style: TextStyle(fontSize: 12)),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.teal.shade700,
                side: BorderSide(color: Colors.teal.shade300),
                padding: const EdgeInsets.symmetric(vertical: 6),
              ),
            )),
          ]),
          const SizedBox(height: 6),
          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(color: Colors.indigo.shade100, borderRadius: BorderRadius.circular(6)),
              child: const Text('By Admin', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.indigo)),
            ),
            const Spacer(),
            Text(_fmtDate(created), style: const TextStyle(fontSize: 11, color: Colors.black38)),
          ]),
        ]),
      ),
    );
  }

  Widget _rideInfoRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Row(children: [
        Icon(icon, size: 14, color: Colors.black38),
        const SizedBox(width: 8),
        Text(text, style: const TextStyle(fontSize: 12, color: Colors.black54)),
      ]),
    );
  }

  String _fmtDate(String? raw) {
    if (raw == null || raw.isEmpty) return '';
    final d = DateTime.tryParse(raw);
    if (d == null) return raw;
    return '${d.day}/${d.month}/${d.year} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _notesCtrl.dispose();
    super.dispose();
  }
}
