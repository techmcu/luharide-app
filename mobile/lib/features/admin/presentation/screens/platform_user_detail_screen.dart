import 'package:flutter/material.dart';
import '../../../../core/feedback/app_feedback.dart';
import '../../../../services/platform_admin_service.dart';

class PlatformUserDetailScreen extends StatefulWidget {
  final String userId;
  const PlatformUserDetailScreen({super.key, required this.userId});

  @override
  State<PlatformUserDetailScreen> createState() => _PlatformUserDetailScreenState();
}

class _PlatformUserDetailScreenState extends State<PlatformUserDetailScreen> {
  final _service = PlatformAdminService();
  Map<String, dynamic>? _user;
  List<dynamic> _trips = [];
  List<dynamic> _bookings = [];
  Map<String, dynamic> _ratings = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final res = await _service.getUserDetail(widget.userId);
    if (!mounted) return;
    if (res['success'] == true) {
      setState(() {
        _user = res['user'] is Map ? Map<String, dynamic>.from(res['user']) : null;
        _trips = res['trips'] is List ? res['trips'] : [];
        _bookings = res['bookings'] is List ? res['bookings'] : [];
        _ratings = res['ratings'] is Map ? Map<String, dynamic>.from(res['ratings']) : {};
        _loading = false;
      });
    } else {
      setState(() => _loading = false);
      if (mounted) AppFeedback.show(context, res['message'] ?? 'Failed', kind: AppFeedbackKind.error);
    }
  }

  Future<void> _toggleActive() async {
    if (_user == null) return;
    final isActive = _user!['is_active'] ?? true;
    final action = isActive ? 'Suspend' : 'Activate';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('$action User?'),
        content: Text(isActive
            ? 'This will prevent the user from logging in or making bookings.'
            : 'This will restore the user\'s access.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: isActive ? Colors.red : Colors.green),
            child: Text(action),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final res = await _service.toggleUserActive(widget.userId, !isActive);
    if (!mounted) return;
    if (res['success'] == true) {
      AppFeedback.show(context, 'User ${!isActive ? "activated" : "suspended"}', kind: AppFeedbackKind.success);
      _load();
    } else {
      AppFeedback.show(context, res['message'] ?? 'Failed', kind: AppFeedbackKind.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('User Detail'), centerTitle: true),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _user == null
              ? const Center(child: Text('User not found'))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _profileCard(),
                      const SizedBox(height: 16),
                      _ratingsCard(),
                      if (_trips.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        const Text('Driver Trips', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 8),
                        ..._trips.take(10).map(_buildTripRow),
                      ],
                      if (_bookings.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        const Text('Passenger Bookings', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 8),
                        ..._bookings.take(10).map(_buildBookingRow),
                      ],
                    ],
                  ),
                ),
    );
  }

  Widget _profileCard() {
    final name = _user!['name'] ?? '';
    final phone = _user!['phone'] ?? '';
    final email = _user!['email'] ?? '';
    final role = _user!['role'] ?? '';
    final isActive = _user!['is_active'] ?? true;
    final isVerified = _user!['is_verified'] ?? false;
    final driverStatus = _user!['driver_verification_status'] ?? 'none';
    final createdAt = _user!['created_at'] ?? '';

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: isActive ? Colors.blue.shade50 : Colors.red.shade50,
                  child: Icon(Icons.person, size: 28, color: isActive ? Colors.blue : Colors.red),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 2),
                      Text(role.toUpperCase(), style: TextStyle(fontSize: 12, color: Colors.blue.shade700, fontWeight: FontWeight.w500)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _infoRow(Icons.phone, phone.isNotEmpty ? phone : 'N/A'),
            _infoRow(Icons.email, email.isNotEmpty ? email : 'N/A'),
            _infoRow(Icons.verified, 'Phone verified: ${isVerified ? "Yes" : "No"}'),
            if (role == 'driver') _infoRow(Icons.badge, 'Driver KYC: $driverStatus'),
            _infoRow(Icons.calendar_today, 'Joined: ${_formatDate(createdAt)}'),
            _infoRow(Icons.circle, 'Status: ${isActive ? "Active" : "SUSPENDED"}',
                color: isActive ? Colors.green : Colors.red),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _toggleActive,
                icon: Icon(isActive ? Icons.block : Icons.check_circle_outline),
                label: Text(isActive ? 'Suspend User' : 'Activate User'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: isActive ? Colors.red : Colors.green,
                  side: BorderSide(color: isActive ? Colors.red : Colors.green),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String text, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color ?? Colors.black45),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: TextStyle(fontSize: 13, color: color ?? Colors.black87))),
        ],
      ),
    );
  }

  Widget _ratingsCard() {
    final total = int.tryParse(_ratings['total_ratings']?.toString() ?? '') ?? 0;
    final avg = double.tryParse(_ratings['avg_rating']?.toString() ?? '') ?? 0;
    final good = int.tryParse(_ratings['good_ratings']?.toString() ?? '') ?? 0;

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _ratingCol('Avg Rating', avg > 0 ? '★ ${avg.toStringAsFixed(1)}' : '—', Colors.amber),
            _ratingCol('Total', '$total', Colors.blue),
            _ratingCol('Good (4+)', '$good', Colors.green),
          ],
        ),
      ),
    );
  }

  Widget _ratingCol(String label, String value, Color color) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.black54)),
      ],
    );
  }

  Widget _buildTripRow(dynamic trip) {
    final from = trip['from_location'] ?? '';
    final to = trip['to_location'] ?? '';
    final status = trip['status'] ?? '';
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: Icon(Icons.route, size: 20, color: status == 'completed' ? Colors.teal : Colors.blueGrey),
      title: Text('$from → $to', style: const TextStyle(fontSize: 13)),
      trailing: _statusChip(status),
    );
  }

  Widget _buildBookingRow(dynamic booking) {
    final from = booking['from_location'] ?? '';
    final to = booking['to_location'] ?? '';
    final status = booking['status'] ?? '';
    final amount = booking['total_amount'] ?? 0;
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.bookmark, size: 20, color: Colors.blueGrey),
      title: Text('$from → $to', style: const TextStyle(fontSize: 13)),
      subtitle: Text('₹$amount', style: const TextStyle(fontSize: 12)),
      trailing: _statusChip(status),
    );
  }

  Widget _statusChip(String status) {
    Color color;
    switch (status) {
      case 'confirmed': color = Colors.green; break;
      case 'completed': color = Colors.teal; break;
      case 'scheduled': color = Colors.blue; break;
      case 'in_progress': color = Colors.green; break;
      case 'pending': color = Colors.orange; break;
      case 'cancelled': color = Colors.red; break;
      default: color = Colors.grey;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(status, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w500)),
    );
  }

  String _formatDate(String? raw) {
    if (raw == null || raw.isEmpty) return 'N/A';
    final d = DateTime.tryParse(raw);
    if (d == null) return raw;
    return '${d.day}/${d.month}/${d.year}';
  }
}
