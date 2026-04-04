import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/config/env_config.dart';
import '../../core/localization/app_localizations.dart';
import '../../providers/app_language_provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/admin_service.dart';
import '../../core/app_navigator.dart';
import '../landing/landing_screen.dart';
import '../../widgets/brand_app_bar_title.dart';

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
    final loc = AppLocalizations.of(context);
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) {
        final c = TextEditingController();
        return AlertDialog(
          title: Text(loc.t('admin.reject.driver_title')),
          content: TextField(
            controller: c,
            decoration: InputDecoration(hintText: loc.t('admin.reject.reason_hint')),
            maxLines: 2,
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(loc.t('app.cancel'))),
            TextButton(onPressed: () => Navigator.pop(ctx, c.text), child: Text(loc.t('admin.action.reject'))),
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
    context.watch<AppLanguageProvider>();
    final loc = AppLocalizations.of(context);
    final authProvider = context.watch<AuthProvider>();

    return Scaffold(
      appBar: AppBar(
        centerTitle: false,
        title: BrandAppBarTitle(
          onColoredBar: true,
          title: Text(loc.t('admin.panel.title')),
        ),
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
                        child: _buildStatCard(loc.t('admin.stat.trips'), _totalTrips, Icons.directions_car, Colors.blue),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildStatCard(loc.t('admin.stat.bookings'), _totalBookings, Icons.book_online, Colors.green),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildStatCard(loc.t('admin.stat.drivers'), _driversVerified, Icons.verified_user, Colors.orange),
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
                                  loc.t('admin.empty'),
                                  style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  loc.t('admin.empty.hint'),
                                  style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          )
                        else ...[
                          if (_unionRequests.isNotEmpty) ...[
                            Text(
                              loc.t('admin.section.union'),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            ..._unionRequests.map((r) => _buildUnionRequestCard(loc, r as Map<String, dynamic>)),
                            const SizedBox(height: 16),
                          ],
                          if (_driverRequests.isNotEmpty) ...[
                            Text(
                              loc.t('admin.section.driver'),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            ..._driverRequests.map((r) => _buildRequestCard(loc, r as Map<String, dynamic>)),
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

  String? _urlStr(Map<String, dynamic> r, String key) {
    final v = r[key];
    if (v == null) return null;
    final s = v.toString().trim();
    return s.isEmpty ? null : s;
  }

  List<Widget> _driverKycLinks(AppLocalizations loc, Map<String, dynamic> r) {
    void add(List<Widget> list, String labelKey, String? url) {
      if (url != null) list.add(_linkRow(loc, labelKey, url));
    }

    final out = <Widget>[];
    final aPdf = _urlStr(r, 'aadhaar_document_url');
    final aFront = _urlStr(r, 'aadhaar_front_url');
    final aBack = _urlStr(r, 'aadhaar_back_url');
    if (aFront != null || aBack != null) {
      add(out, 'admin.kyc.aadhaar_front', aFront);
      add(out, 'admin.kyc.aadhaar_back', aBack);
      if (aPdf != null && aPdf != aFront && aPdf != aBack) {
        add(out, 'admin.kyc.aadhaar_legacy', aPdf);
      }
    } else if (aPdf != null) {
      if (aPdf.toLowerCase().endsWith('.pdf')) {
        add(out, 'admin.kyc.aadhaar_combined', aPdf);
      } else {
        add(out, 'admin.kyc.aadhaar_legacy', aPdf);
      }
    }

    final dlPdf = _urlStr(r, 'driving_license_url');
    final dlFront = _urlStr(r, 'driving_license_front_url');
    final dlBack = _urlStr(r, 'driving_license_back_url');
    if (dlFront != null || dlBack != null) {
      add(out, 'admin.kyc.dl_front', dlFront);
      add(out, 'admin.kyc.dl_back', dlBack);
      if (dlPdf != null && dlPdf != dlFront && dlPdf != dlBack) {
        add(out, 'admin.kyc.dl_legacy', dlPdf);
      }
    } else if (dlPdf != null) {
      if (dlPdf.toLowerCase().endsWith('.pdf')) {
        add(out, 'admin.kyc.dl_combined', dlPdf);
      } else {
        add(out, 'admin.kyc.dl_legacy', dlPdf);
      }
    }

    add(out, 'admin.kyc.rc_front', _urlStr(r, 'rc_front_url'));
    add(out, 'admin.kyc.rc_back', _urlStr(r, 'rc_back_url'));
    add(out, 'admin.kyc.rc', _urlStr(r, 'rc_document_url'));
    add(out, 'admin.kyc.permit', _urlStr(r, 'permit_document_url'));
    add(out, 'admin.kyc.insurance', _urlStr(r, 'insurance_document_url'));
    return out;
  }

  List<Widget> _unionKycLinks(AppLocalizations loc, Map<String, dynamic> r) {
    void add(List<Widget> list, String labelKey, String? url) {
      if (url != null) list.add(_linkRow(loc, labelKey, url));
    }

    final out = <Widget>[];
    final oa = _urlStr(r, 'owner_aadhaar_url');
    final oaf = _urlStr(r, 'owner_aadhaar_front_url');
    final oab = _urlStr(r, 'owner_aadhaar_back_url');
    if (oaf != null || oab != null) {
      add(out, 'admin.kyc.union_aadhaar_front', oaf);
      add(out, 'admin.kyc.union_aadhaar_back', oab);
      if (oa != null && oa != oaf && oa != oab) {
        add(out, 'admin.kyc.union_leader_aadhaar', oa);
      }
    } else if (oa != null) {
      if (oa.toLowerCase().endsWith('.pdf')) {
        add(out, 'admin.kyc.union_aadhaar_combined', oa);
      } else {
        add(out, 'admin.kyc.union_leader_aadhaar', oa);
      }
    }

    final ldf = _urlStr(r, 'leader_driving_license_front_url');
    final ldb = _urlStr(r, 'leader_driving_license_back_url');
    if (ldf != null || ldb != null) {
      if (ldf != null) {
        if (ldb == null && ldf.toLowerCase().endsWith('.pdf')) {
          add(out, 'admin.kyc.union_leader_dl_combined', ldf);
        } else {
          add(out, 'admin.kyc.union_leader_dl_front', ldf);
        }
      }
      add(out, 'admin.kyc.union_leader_dl_back', ldb);
    }
    add(out, 'admin.kyc.office_photo', _urlStr(r, 'office_photo_url'));
    add(out, 'admin.kyc.union_photo', _urlStr(r, 'union_photo_url'));
    add(out, 'admin.kyc.union_driver_list_photo', _urlStr(r, 'union_driver_list_photo_url'));
    add(out, 'admin.kyc.union_rc_front', _urlStr(r, 'owner_vehicle_rc_front_url'));
    add(out, 'admin.kyc.union_rc_back', _urlStr(r, 'owner_vehicle_rc_back_url'));
    add(out, 'admin.kyc.union_rc', _urlStr(r, 'owner_vehicle_rc_url'));
    return out;
  }

  Widget _buildRequestCard(AppLocalizations loc, Map<String, dynamic> r) {
    final id = r['id']?.toString() ?? '';
    final name = r['name'] ?? 'Unknown';
    final email = r['email'] ?? '';
    final phone = r['phone'] ?? '';
    final vehicleReg = (r['vehicle_registration'] ?? '').toString().trim();
    final vehicleType = (r['vehicle_type'] ?? '').toString().trim();
    final vehicleModel = (r['vehicle_model'] ?? '').toString().trim();
    final cPhone = (r['contact_phone'] ?? '').toString().trim();
    final cEmail = (r['contact_email'] ?? '').toString().trim();

    String vehicleLine = '';
    if (vehicleReg.isNotEmpty) {
      vehicleLine = vehicleReg;
      if (vehicleType.isNotEmpty) vehicleLine += ' ($vehicleType)';
      if (vehicleModel.isNotEmpty) vehicleLine += ' — $vehicleModel';
    }

    final docLinks = _driverKycLinks(loc, r);

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
                    (name.toString().isNotEmpty ? name.toString()[0] : '?').toUpperCase(),
                    style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange[800]),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name.toString(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      if (email.toString().isNotEmpty)
                        Text(email.toString(), style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                      if (phone != null && phone.toString().trim().isNotEmpty)
                        Text(phone.toString(), style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                    ],
                  ),
                ),
              ],
            ),
            if (cPhone.isNotEmpty || cEmail.isNotEmpty) ...[
              const Divider(height: 24),
              Text(loc.t('admin.kyc.contact'), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
              const SizedBox(height: 8),
              if (cPhone.isNotEmpty) _docRow(loc.t('admin.kyc.phone'), cPhone),
              if (cEmail.isNotEmpty) _docRow(loc.t('admin.kyc.email'), cEmail),
            ],
            const Divider(height: 24),
            Text(loc.t('admin.kyc.documents'), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
            const SizedBox(height: 8),
            if (vehicleLine.isNotEmpty) _docRow(loc.t('admin.kyc.vehicle'), vehicleLine),
            ...docLinks,
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton(
                  onPressed: () => _reject(id),
                  style: OutlinedButton.styleFrom(foregroundColor: Colors.red, side: const BorderSide(color: Colors.red)),
                  child: Text(loc.t('admin.action.reject')),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: () => _approve(id),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                  child: Text(loc.t('admin.action.approve')),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUnionRequestCard(AppLocalizations loc, Map<String, dynamic> r) {
    final id = r['id']?.toString() ?? '';
    final name = (r['name'] ?? '').toString();
    final location = (r['address'] ?? '').toString();
    final unionHeadName = (r['owner_name'] ?? '').toString();
    final applicantName = (r['applicant_name'] ?? '').toString();
    final applicantEmail = (r['applicant_email'] ?? '').toString();
    final applicantPhone = (r['applicant_phone'] ?? '').toString();
    final leadPhone = (r['contact_phone'] ?? '').toString().trim();
    final leadEmail = (r['contact_email'] ?? '').toString().trim();

    final docLinks = _unionKycLinks(loc, r);

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
                        name.isNotEmpty ? name : loc.t('admin.kyc.fallback_union_name'),
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
            Text(
              loc.t('admin.kyc.union.section_leader'),
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
            const SizedBox(height: 4),
            if (unionHeadName.isNotEmpty)
              Text(
                unionHeadName,
                style: const TextStyle(fontSize: 13),
              ),
            if (leadPhone.isNotEmpty || leadEmail.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(loc.t('admin.kyc.union.contact_lead'), style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.grey[800])),
              const SizedBox(height: 4),
              if (leadPhone.isNotEmpty) _docRow(loc.t('admin.kyc.phone'), leadPhone),
              if (leadEmail.isNotEmpty) _docRow(loc.t('admin.kyc.email'), leadEmail),
            ],
            if (applicantName.isNotEmpty || applicantEmail.isNotEmpty || applicantPhone.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                loc.t('admin.kyc.union.section_applicant'),
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
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
            Text(loc.t('admin.kyc.documents'), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
            const SizedBox(height: 8),
            ...docLinks,
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
                  child: Text(loc.t('admin.action.reject')),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: () => _approveUnion(id),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                  child: Text(loc.t('admin.action.approve')),
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

  Widget _linkRow(AppLocalizations loc, String labelKey, String url) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: InkWell(
        onTap: () async {
          final resolved = _resolveDocUrl(url);
          final uri = Uri.tryParse(resolved);
          if (uri != null && await canLaunchUrl(uri)) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          } else if (mounted) {
            final snackLoc = AppLocalizations.of(context);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(snackLoc.t('admin.snack.cannot_open')),
                backgroundColor: Colors.red,
              ),
            );
          }
        },
        child: Row(
          children: [
            Icon(Icons.link, size: 16, color: Colors.blue[700]),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                '${loc.t('admin.kyc.view_prefix')}: ${loc.t(labelKey)}',
                style: TextStyle(fontSize: 13, color: Colors.blue[700], decoration: TextDecoration.underline),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _resolveDocUrl(String url) {
    final raw = url.trim();
    if (raw.isEmpty) return raw;
    if (raw.startsWith('http://') || raw.startsWith('https://')) return raw;
    if (raw.startsWith('/')) return '${EnvConfig.publicFileBaseUrl}$raw';
    return '${EnvConfig.publicFileBaseUrl}/$raw';
  }

  void _showLogoutDialog(BuildContext context, AuthProvider authProvider) {
    final loc = AppLocalizations.of(context);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => AlertDialog(
        title: Text(loc.t('admin.logout.title')),
        content: Text(loc.t('admin.logout.body')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: Text(loc.t('app.cancel')),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogCtx);
              await authProvider.logout();
              if (navigatorKey.currentState != null) {
                navigatorKey.currentState!.pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const LandingScreen()),
                  (route) => false,
                );
              }
            },
            child: Text(loc.t('admin.logout.title')),
          ),
        ],
      ),
    );
  }
}
