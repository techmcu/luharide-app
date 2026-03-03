import 'package:flutter/material.dart';
import '../../services/union_service.dart';
import 'union_manage_drivers_screen.dart';
import 'union_create_rides_screen.dart';

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

    // Load dashboard stats
    final dashboardResult = await service.getDashboard();
    Map<String, dynamic>? stats;
    String? error;
    if (dashboardResult['success'] == true) {
      stats = dashboardResult['data'] as Map<String, dynamic>?;
    } else {
      error = dashboardResult['message']?.toString() ?? 'Failed to load dashboard';
    }

    // Load basic read-only driver list (only if dashboard succeeded)
    List<dynamic> drivers = const [];
    if (error == null) {
      final driversResult = await service.getDrivers();
      if (driversResult['success'] == true) {
        final raw = driversResult['drivers'];
        if (raw is List) {
          drivers = raw;
        }
      } else {
        error = driversResult['message']?.toString() ?? 'Failed to load drivers';
      }
    }

    if (!mounted) return;
    setState(() {
      _stats = stats;
      _drivers = drivers;
      _error = error;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Union Dashboard'),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _error!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.red),
                        ),
                        const SizedBox(height: 12),
                        ElevatedButton(
                          onPressed: _load,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      const Text(
                        'Today\'s Overview',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildStatCard(
                        title: 'Total Trips',
                        value: _stats?['total_trips']?.toString() ?? '0',
                        color: Colors.blue[50],
                      ),
                      const SizedBox(height: 12),
                      _buildStatCard(
                        title: 'Active Bookings',
                        value: _stats?['total_bookings']?.toString() ?? '0',
                        color: Colors.green[50],
                      ),
                      const SizedBox(height: 12),
                      _buildStatCard(
                        title: 'Verified Drivers (overall)',
                        value: _stats?['drivers_verified']?.toString() ?? '0',
                        color: Colors.purple[50],
                      ),
                      const SizedBox(height: 24),
                      Card(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ListTile(
                              leading: const Icon(Icons.directions_car),
                              title: const Text('Union drivers'),
                              subtitle: const Text(
                                'Add / see all drivers in your union list',
                                style: TextStyle(fontSize: 12),
                              ),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        const UnionManageDriversScreen(),
                                  ),
                                ).then((_) => _load());
                              },
                            ),
                            const Divider(height: 1),
                            ListTile(
                              leading: const Icon(Icons.event_note),
                              title: const Text('Create rides & posters'),
                              subtitle: const Text(
                                'Select drivers, set route and time, auto make schedule',
                                style: TextStyle(fontSize: 12),
                              ),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        const UnionCreateRidesScreen(),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'Next features coming soon:',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        '• Daily schedule / poster maker\n'
                        '• Advanced driver ratings & analytics\n'
                        '• Pending union join requests',
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'Drivers in this union (read-only)',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (_drivers.isEmpty)
                        const Text(
                          'No drivers added yet. This list will show drivers managed by your union.',
                          style: TextStyle(fontSize: 13),
                        )
                      else
                        ..._drivers
                            .map((d) => _buildDriverCard(d as Map<String, dynamic>))
                            .toList(),
                    ],
                  ),
                ),
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    Color? color,
  }) {
    return Card(
      color: color ?? Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              value,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
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

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            const CircleAvatar(
              radius: 20,
              child: Icon(Icons.person, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name.isNotEmpty ? name : 'Driver',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (vehicleNumber.isNotEmpty)
                    Text(
                      'Gadi: $vehicleNumber',
                      style: const TextStyle(fontSize: 13),
                    ),
                  if (phone.isNotEmpty || whatsapp.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        [
                          if (phone.isNotEmpty) 'Phone: $phone',
                          if (whatsapp.isNotEmpty) 'WhatsApp: $whatsapp',
                        ].join('  •  '),
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.black54,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

