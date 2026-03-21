import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/config/env_config.dart';
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
  List<dynamic> _driverRequests = [];
  List<dynamic> _unionRequests = [];
  bool _loading = true;
  int _totalTrips = 0;
  int _totalBookings = 0;
  int _driversVerified = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final statsResult = await _adminService.getUnionDashboardStats();
    final driverResult = await _adminService.getDriverRequests();
    final unionResult = await _adminService.getUnionRequests();

    if (!mounted) return;

    setState(() {
      _loading = false;
      _driverRequests = driverResult['requests'] ?? [];
      _unionRequests = unionResult['requests'] ?? [];
      if (statsResult['success'] == true) {
        _totalTrips = statsResult['total_trips'] ?? 0;
        _totalBookings = statsResult['total_bookings'] ?? 0;
        _driversVerified = statsResult['drivers_verified'] ?? 0;
      }
    });

    if (driverResult['success'] != true && driverResult['message'] != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(driverResult['message'] ?? 'Failed to load driver requests'),
          backgroundColor: Colors.red,
        ),
      );
    }
    if (unionResult['success'] != true && unionResult['message'] != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(unionResult['message'] ?? 'Failed to load union requests'),
          backgroundColor: Colors.red,
        ),
      );
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

  Future<void> _approveUnion(String id) async {
    final result = await _adminService.approveUnion(id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result['message'] ?? ''),
        backgroundColor: result['success'] == true ? Colors.green : Colors.red,
      ),
    );
    if (result['success'] == true) _load();
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

  Future<void> _rejectUnion(String id) async {
    final result = await _adminService.rejectUnion(id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result['message'] ?? ''),
        backgroundColor: result['success'] == true ? Colors.orange : Colors.red,
      ),
    );
    if (result['success'] == true) _load();
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
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Dashboard stats
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Expanded(
                        child: _buildStatCard('Trips', _totalTrips, Icons.directions_car, Colors.blue),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildStatCard('Bookings', _totalBookings, Icons.book_online, Colors.green),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildStatCard('Drivers', _driversVerified, Icons.verified_user, Colors.orange),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _load,
                    child: ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        if (_unionRequests.isEmpty && _driverRequests.isEmpty)
                          Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.check_circle_outline, size: 64, color: Colors.grey[400]),
                                const SizedBox(height: 16),
                                Text(
                                  'No pending requests',
                                  style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Union registrations and driver requests will appear here',
                                  style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          )
                        else ...[
                          if (_unionRequests.isNotEmpty) ...[
                            const Text(
                              'Pending union registrations',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            ..._unionRequests
                                .map((r) => _buildUnionRequestCard(r as Map<String, dynamic>))
                                .toList(),
                            const SizedBox(height: 16),
                          ],
                          if (_driverRequests.isNotEmpty) ...[
                            const Text(
                              'Pending driver requests',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            ..._driverRequests
                                .map((r) => _buildRequestCard(r as Map<String, dynamic>))
                                .toList(),
                          ],
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
      );
  }

  Widget _buildStatCard(String label, int value, IconData icon, MaterialColor color) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        child: Column(
          children: [
            Icon(icon, size: 28, color: color),
            const SizedBox(height: 8),
            Text(
              value.toString(),
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color[800]),
            ),
            Text(
              label,
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
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

  Widget _buildUnionRequestCard(Map<String, dynamic> r) {
    final id = r['id']?.toString() ?? '';
    final name = (r['name'] ?? '').toString();
    final location = (r['address'] ?? '').toString();
    final unionHeadName = (r['owner_name'] ?? '').toString();
    final applicantName = (r['applicant_name'] ?? '').toString();
    final applicantEmail = (r['applicant_email'] ?? '').toString();
    final applicantPhone = (r['applicant_phone'] ?? '').toString();

    final ownerAadhaarUrl = r['owner_aadhaar_url']?.toString();
    final officePhotoUrl = r['office_photo_url']?.toString();
    final ownerVehicleRcUrl = r['owner_vehicle_rc_url']?.toString();

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
                  backgroundColor: Colors.blue[100],
                  child: const Icon(Icons.apartment, color: Colors.blue),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name.isNotEmpty ? name : 'Taxi union',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      if (location.isNotEmpty)
                        Text(
                          location,
                          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              'Owner',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
            const SizedBox(height: 4),
            if (unionHeadName.isNotEmpty)
              Text(
                unionHeadName,
                style: const TextStyle(fontSize: 13),
              ),
            if (applicantName.isNotEmpty || applicantEmail.isNotEmpty || applicantPhone.isNotEmpty) ...[
              const SizedBox(height: 8),
              const Text(
                'Applicant (account)',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
              const SizedBox(height: 4),
              if (applicantName.isNotEmpty) Text(applicantName, style: const TextStyle(fontSize: 13)),
            ],
            if (applicantEmail.isNotEmpty)
              Text(
                applicantEmail,
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            if (applicantPhone.isNotEmpty)
              Text(
                applicantPhone,
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            const Divider(height: 24),
            const Text('Documents', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
            const SizedBox(height: 8),
            if (ownerAadhaarUrl != null && ownerAadhaarUrl.isNotEmpty) _linkRow('Owner Aadhaar doc', ownerAadhaarUrl),
            if (officePhotoUrl != null && officePhotoUrl.isNotEmpty) _linkRow('Office photo', officePhotoUrl),
            if (ownerVehicleRcUrl != null && ownerVehicleRcUrl.isNotEmpty) _linkRow('Owner vehicle RC doc', ownerVehicleRcUrl),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton(
                  onPressed: () => _rejectUnion(id),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                  ),
                  child: const Text('Reject'),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: () => _approveUnion(id),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
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
          final resolved = _resolveDocUrl(url);
          final uri = Uri.tryParse(resolved);
          if (uri != null && await canLaunchUrl(uri)) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          } else if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Unable to open: $resolved'),
                backgroundColor: Colors.red,
              ),
            );
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

  String _resolveDocUrl(String url) {
    final raw = url.trim();
    if (raw.isEmpty) return raw;
    if (raw.startsWith('http://') || raw.startsWith('https://')) return raw;
    if (raw.startsWith('/')) return '${EnvConfig.socketUrl}$raw';
    return '${EnvConfig.socketUrl}/$raw';
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
