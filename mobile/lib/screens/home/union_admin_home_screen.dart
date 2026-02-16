import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../providers/auth_provider.dart';
import '../../services/admin_service.dart';
import '../../core/app_navigator.dart';
import '../landing/landing_screen.dart';

/// Admin Panel - Simple: Driver verification requests only. No search bar.
class UnionAdminHomeScreen extends StatefulWidget {
  const UnionAdminHomeScreen({super.key});

  @override
  State<UnionAdminHomeScreen> createState() => _UnionAdminHomeScreenState();
}

class _UnionAdminHomeScreenState extends State<UnionAdminHomeScreen> {
  final _adminService = AdminService();
  List<dynamic> _requests = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final result = await _adminService.getDriverRequests();
    if (mounted) {
      setState(() {
        _loading = false;
        _requests = result['requests'] ?? [];
      });
      if (result['success'] != true && result['message'] != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Failed to load requests'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _approve(String id) async {
    final result = await _adminService.approveDriver(id);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message'] ?? ''),
          backgroundColor: result['success'] == true ? Colors.green : Colors.red,
        ),
      );
      if (result['success'] == true) _load();
    }
  }

  Future<void> _reject(String id) async {
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) {
        final c = TextEditingController();
        return AlertDialog(
          title: const Text('Reject Driver'),
          content: TextField(
            controller: c,
            decoration: const InputDecoration(hintText: 'Reason (optional)'),
            maxLines: 2,
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            TextButton(onPressed: () => Navigator.pop(ctx, c.text), child: const Text('Reject')),
          ],
        );
      },
    );
    if (reason == null) return;
    final result = await _adminService.rejectDriver(id, reason: reason.isEmpty ? null : reason);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message'] ?? ''),
          backgroundColor: result['success'] == true ? Colors.orange : Colors.red,
        ),
      );
      if (result['success'] == true) _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Panel'),
        backgroundColor: Colors.purple[700],
        foregroundColor: Colors.white,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loading ? null : _load),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => _showLogoutDialog(context, authProvider),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _requests.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check_circle_outline, size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text(
                        'No pending driver requests',
                        style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Driver verification requests will appear here',
                        style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _requests.length,
                    itemBuilder: (context, i) {
                      final r = _requests[i] as Map<String, dynamic>;
                      return _buildRequestCard(r);
                    },
                  ),
                ),
    );
  }

  Widget _buildRequestCard(Map<String, dynamic> r) {
    final id = r['id']?.toString() ?? '';
    final name = r['name'] ?? 'Unknown';
    final email = r['email'] ?? '';
    final phone = r['phone'] ?? '';
    final license = r['driving_license_number'] ?? '-';
    final vehicleReg = r['vehicle_registration'] ?? '-';
    final vehicleType = r['vehicle_type'] ?? '-';
    final vehicleModel = r['vehicle_model'] ?? '';
    final licenseUrl = r['driving_license_url']?.toString();
    final rcUrl = r['rc_document_url']?.toString();
    final permitUrl = r['permit_document_url']?.toString();

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.orange[100],
                  child: Text(
                    (name.toString().isNotEmpty ? name[0] : '?').toUpperCase(),
                    style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange[800]),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      if (email.isNotEmpty) Text(email, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                      if (phone != null && phone.toString().trim().isNotEmpty)
                        Text(phone.toString(), style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            const Text('Documents', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
            const SizedBox(height: 8),
            _docRow('License', license),
            if (vehicleReg != '-') _docRow('Vehicle', '$vehicleReg${vehicleType != '-' ? ' ($vehicleType)' : ''}${vehicleModel != '' ? ' - $vehicleModel' : ''}'),
            if (licenseUrl != null && licenseUrl.isNotEmpty) _linkRow('License doc', licenseUrl),
            if (rcUrl != null && rcUrl.isNotEmpty) _linkRow('RC doc', rcUrl),
            if (permitUrl != null && permitUrl.isNotEmpty) _linkRow('Permit doc', permitUrl),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton(
                  onPressed: () => _reject(id),
                  style: OutlinedButton.styleFrom(foregroundColor: Colors.red, side: const BorderSide(color: Colors.red)),
                  child: const Text('Reject'),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: () => _approve(id),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                  child: const Text('Approve'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _docRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 90, child: Text('$label:', style: TextStyle(fontSize: 13, color: Colors.grey[700]))),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }

  Widget _linkRow(String label, String url) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: InkWell(
        onTap: () async {
          final uri = Uri.tryParse(url);
          if (uri != null && await canLaunchUrl(uri)) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          }
        },
        child: Row(
          children: [
            Icon(Icons.link, size: 16, color: Colors.blue[700]),
            const SizedBox(width: 6),
            Text('View $label', style: TextStyle(fontSize: 13, color: Colors.blue[700], decoration: TextDecoration.underline)),
          ],
        ),
      ),
    );
  }

  void _showLogoutDialog(BuildContext context, AuthProvider authProvider) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Do you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx), 
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              // Close dialog first
              Navigator.pop(dialogCtx);
              
              // Logout immediately - clear auth state
              await authProvider.logout();
              
              // Force navigation to landing screen - clear entire stack
              if (navigatorKey.currentState != null) {
                navigatorKey.currentState!.pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const LandingScreen()),
                  (route) => false, // Remove all previous routes
                );
              }
            },
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }
}
