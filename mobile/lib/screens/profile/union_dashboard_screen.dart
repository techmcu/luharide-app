import 'package:flutter/material.dart';
import '../../services/union_service.dart';

class UnionDashboardScreen extends StatefulWidget {
  const UnionDashboardScreen({super.key});

  @override
  State<UnionDashboardScreen> createState() => _UnionDashboardScreenState();
}

class _UnionDashboardScreenState extends State<UnionDashboardScreen> {
  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _stats;

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
    final result = await UnionService().getDashboard();
    if (!mounted) return;
    if (result['success'] == true) {
      setState(() {
        _stats = result['data'] as Map<String, dynamic>?;
        _loading = false;
      });
    } else {
      setState(() {
        _error = result['message']?.toString() ?? 'Failed to load';
        _loading = false;
      });
    }
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
                      const Text(
                        'Next features coming soon:',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        '• Daily schedule / poster maker\n'
                        '• Union driver list & ratings\n'
                        '• Pending union join requests',
                      ),
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
}

