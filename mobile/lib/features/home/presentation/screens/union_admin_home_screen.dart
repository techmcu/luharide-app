import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/config/env_config.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../providers/app_language_provider.dart';
import '../../../../providers/auth_provider.dart';
import '../../../../services/admin_service.dart';
import '../../../../core/app_navigator.dart';
import '../../../landing/presentation/screens/landing_screen.dart';
import '../../../../widgets/brand_app_bar_title.dart';
import '../../../../core/feedback/app_feedback.dart';
import '../../../admin/presentation/screens/kyc_document_viewer_screen.dart';

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
  /// Approved unions with documents_status = pending (re-upload submitted).
  List<dynamic> _unionDocRequests = [];
  bool _loading = true;

  final List<Map<String, dynamic>> _directoryDrivers = [];
  final List<Map<String, dynamic>> _directoryUnions = [];
  int _directoryDriversTotal = 0;
  int _directoryUnionsTotal = 0;
  bool _directoryDriversLoaded = false;
  bool _directoryUnionsLoaded = false;
  bool _directoryDriversLoading = false;
  bool _directoryUnionsLoading = false;

  static const double _directoryListHeight = 300;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _invalidateDirectory() {
    _directoryDriversLoaded = false;
    _directoryUnionsLoaded = false;
    _directoryDrivers.clear();
    _directoryUnions.clear();
    _directoryDriversTotal = 0;
    _directoryUnionsTotal = 0;
  }

  Future<void> _fetchDirectoryDrivers() async {
    if (_directoryDriversLoading) return;
    setState(() => _directoryDriversLoading = true);
    final r = await _adminService.getIndependentDriversDirectory(limit: 500, offset: 0);
    if (!mounted) return;
    setState(() {
      _directoryDriversLoading = false;
      if (r['success'] == true) {
        _directoryDriversLoaded = true;
        _directoryDriversTotal = _asInt(r['total']);
        _directoryDrivers
          ..clear()
          ..addAll(_mapList(r['drivers']));
      } else {
        AppFeedback.show(
          context,
          r['message']?.toString() ?? 'Failed',
          kind: AppFeedbackKind.error,
        );
      }
    });
  }

  Future<void> _fetchDirectoryUnions() async {
    if (_directoryUnionsLoading) return;
    setState(() => _directoryUnionsLoading = true);
    final r = await _adminService.getUnionsDirectory(limit: 500, offset: 0);
    if (!mounted) return;
    setState(() {
      _directoryUnionsLoading = false;
      if (r['success'] == true) {
        _directoryUnionsLoaded = true;
        _directoryUnionsTotal = _asInt(r['total']);
        _directoryUnions
          ..clear()
          ..addAll(_mapList(r['unions']));
      } else {
        AppFeedback.show(
          context,
          r['message']?.toString() ?? 'Failed',
          kind: AppFeedbackKind.error,
        );
      }
    });
  }

  int _asInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v?.toString() ?? '') ?? 0;
  }

  List<Map<String, dynamic>> _mapList(dynamic raw) {
    if (raw is! List) return [];
    return raw
        .map((e) => e is Map<String, dynamic> ? e : Map<String, dynamic>.from(e as Map))
        .toList();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final driverResult = await _adminService.getDriverRequests();
    final unionResult = await _adminService.getUnionRequests();
    final unionDocResult = await _adminService.getUnionDocUpdateRequests();

    if (!mounted) return;

    setState(() {
      _loading = false;
      _invalidateDirectory();
      _driverRequests = coerceAdminRequestList(driverResult['requests']);
      _unionRequests = coerceAdminRequestList(unionResult['requests']);
      _unionDocRequests = coerceAdminRequestList(unionDocResult['requests']);
    });

    final driverFail =
        driverResult['success'] != true && driverResult['message'] != null;
    final unionFail =
        unionResult['success'] != true && unionResult['message'] != null;
    final unionDocFail =
        unionDocResult['success'] != true && unionDocResult['message'] != null;
    if (driverFail && unionFail && unionDocFail) {
      AppFeedback.show(
        context,
        '${_adminPanelLoadErrLine(driverResult['message'], 'Driver requests')}\n'
        '${_adminPanelLoadErrLine(unionResult['message'], 'Union requests')}\n'
        '${_adminPanelLoadErrLine(unionDocResult['message'], 'Union doc updates')}',
        kind: AppFeedbackKind.error,
        duration: const Duration(seconds: 7),
      );
    } else {
      if (driverFail) {
        AppFeedback.show(
          context,
          driverResult['message'] ?? 'Failed to load driver requests',
          kind: AppFeedbackKind.error,
        );
      }
      if (unionFail) {
        AppFeedback.show(
          context,
          unionResult['message'] ?? 'Failed to load union requests',
          kind: AppFeedbackKind.error,
        );
      }
      if (unionDocFail) {
        AppFeedback.show(
          context,
          unionDocResult['message'] ?? 'Failed to load union document updates',
          kind: AppFeedbackKind.error,
        );
      }
    }
  }

  Future<void> _approve(String id) async {
    final result = await _adminService.approveDriver(id);
    if (mounted) {
      AppFeedback.show(
        context,
        result['message'] ?? '',
        kind: result['success'] == true
            ? AppFeedbackKind.success
            : AppFeedbackKind.error,
      );
      if (result['success'] == true) _load();
    }
  }

  Future<void> _approveUnion(String id) async {
    final result = await _adminService.approveUnion(id);
    if (!mounted) return;
    AppFeedback.show(
      context,
      result['message'] ?? '',
      kind: result['success'] == true
          ? AppFeedbackKind.success
          : AppFeedbackKind.error,
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
      AppFeedback.show(
        context,
        result['message'] ?? '',
        kind: result['success'] == true
            ? AppFeedbackKind.warning
            : AppFeedbackKind.error,
      );
      if (result['success'] == true) _load();
    }
  }

  Future<void> _rejectUnion(String id) async {
    final result = await _adminService.rejectUnion(id);
    if (!mounted) return;
    AppFeedback.show(
      context,
      result['message'] ?? '',
      kind: result['success'] == true
          ? AppFeedbackKind.warning
          : AppFeedbackKind.error,
    );
    if (result['success'] == true) _load();
  }

  Future<void> _approveUnionDocUpdate(String unionId) async {
    final result = await _adminService.approveUnionDocUpdate(unionId);
    if (!mounted) return;
    AppFeedback.show(
      context,
      result['message'] ?? '',
      kind: result['success'] == true
          ? AppFeedbackKind.success
          : AppFeedbackKind.error,
    );
    if (result['success'] == true) _load();
  }

  Future<void> _rejectUnionDocUpdate(String unionId) async {
    final loc = AppLocalizations.of(context);
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) {
        final c = TextEditingController();
        return AlertDialog(
          title: Text(loc.t('admin.reject.union_doc_title')),
          content: TextField(
            controller: c,
            decoration: InputDecoration(hintText: loc.t('admin.reject.reason_hint')),
            maxLines: 2,
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(loc.t('app.cancel'))),
            TextButton(
              onPressed: () => Navigator.pop(ctx, c.text),
              child: Text(loc.t('admin.action.reject')),
            ),
          ],
        );
      },
    );
    if (reason == null) return;
    final result = await _adminService.rejectUnionDocUpdate(
      unionId,
      reason: reason.isEmpty ? null : reason,
    );
    if (!mounted) return;
    AppFeedback.show(
      context,
      result['message'] ?? '',
      kind: result['success'] == true
          ? AppFeedbackKind.warning
          : AppFeedbackKind.error,
    );
    if (result['success'] == true) _load();
  }

  static final RegExp _uuidRe = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$',
  );

  bool _isUuid(String s) => _uuidRe.hasMatch(s.trim());

  Future<void> _showReverifyDialog(AppLocalizations loc) async {
    final idCtrl = TextEditingController();
    final msgCtrl = TextEditingController();
    final daysCtrl = TextEditingController(text: '7');
    var isDriver = true;

    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSt) {
            return AlertDialog(
              title: Text(loc.t('admin.reverify.dialog_title')),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      loc.t('admin.reverify.dialog_body'),
                      style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        FilterChip(
                          label: Text(loc.t('admin.reverify.mode_driver')),
                          selected: isDriver,
                          onSelected: (_) => setSt(() => isDriver = true),
                        ),
                        FilterChip(
                          label: Text(loc.t('admin.reverify.mode_union')),
                          selected: !isDriver,
                          onSelected: (_) => setSt(() => isDriver = false),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: idCtrl,
                      decoration: InputDecoration(
                        labelText:
                            isDriver ? loc.t('admin.reverify.id_driver') : loc.t('admin.reverify.id_union'),
                        border: const OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.text,
                      autocorrect: false,
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: msgCtrl,
                      decoration: InputDecoration(
                        labelText: loc.t('admin.reverify.optional_message'),
                        border: const OutlineInputBorder(),
                      ),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: daysCtrl,
                      decoration: InputDecoration(
                        labelText: loc.t('admin.reverify.days'),
                        border: const OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: Text(loc.t('app.cancel'))),
                FilledButton(
                  onPressed: () async {
                    final id = idCtrl.text.trim();
                    if (!_isUuid(id)) {
                      if (ctx.mounted) {
                        AppFeedback.show(
                          ctx,
                          loc.t('admin.reverify.invalid_uuid'),
                          kind: AppFeedbackKind.warning,
                        );
                      }
                      return;
                    }
                    final msg = msgCtrl.text.trim();
                    final days = int.tryParse(daysCtrl.text.trim());
                    Navigator.pop(ctx);
                    final result = isDriver
                        ? await _adminService.grantDriverKycReverify(
                            id,
                            message: msg.isEmpty ? null : msg,
                            days: days,
                          )
                        : await _adminService.grantUnionKycReverify(
                            id,
                            message: msg.isEmpty ? null : msg,
                            days: days,
                          );
                    if (!mounted) return;
                    AppFeedback.show(
                      context,
                      result['message']?.toString() ?? '',
                      kind: result['success'] == true
                          ? AppFeedbackKind.success
                          : AppFeedbackKind.error,
                    );
                  },
                  child: Text(loc.t('admin.reverify.send')),
                ),
              ],
            );
          },
        );
      },
    );
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
          IconButton(
            tooltip: loc.t('admin.reverify.tooltip'),
            icon: const Icon(Icons.manage_accounts_outlined),
            onPressed: _loading ? null : () => _showReverifyDialog(loc),
          ),
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
                // Dashboard stats (horizontal scroll: 4 cols on small screens)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        SizedBox(
                          width: 128,
                          child: _buildStatCard(
                            loc.t('admin.stat.pending_unions'),
                            _unionRequests.length,
                            Icons.apartment,
                            Colors.blue,
                          ),
                        ),
                        const SizedBox(width: 10),
                        SizedBox(
                          width: 128,
                          child: _buildStatCard(
                            loc.t('admin.stat.pending_drivers'),
                            _driverRequests.length,
                            Icons.badge,
                            Colors.green,
                          ),
                        ),
                        const SizedBox(width: 10),
                        SizedBox(
                          width: 128,
                          child: _buildStatCard(
                            loc.t('admin.stat.pending_union_docs'),
                            _unionDocRequests.length,
                            Icons.folder_special_outlined,
                            Colors.deepPurple,
                          ),
                        ),
                        const SizedBox(width: 10),
                        SizedBox(
                          width: 128,
                          child: _buildStatCard(
                            loc.t('admin.stat.pending_total'),
                            _unionRequests.length +
                                _driverRequests.length +
                                _unionDocRequests.length,
                            Icons.pending_actions,
                            Colors.orange,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _load,
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(16),
                      children: [
                        _directoryDriversSection(loc),
                        _directoryUnionsSection(loc),
                        _pendingRegistrationsSection(loc),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
              ],
            ),
      );
  }

  Widget _directoryDriversSection(AppLocalizations loc) {
    return Card(
      clipBehavior: Clip.antiAlias,
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        leading: Icon(Icons.directions_car_filled_outlined, color: Colors.green[700]),
        title: Text(loc.t('admin.directory.drivers_tile')),
        subtitle: Text(
          _directoryDriversLoaded
              ? loc.tReplace('admin.directory.count_known', {'n': '$_directoryDriversTotal'})
              : loc.t('admin.directory.tap_to_expand'),
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        ),
        onExpansionChanged: (open) {
          if (open && !_directoryDriversLoaded) _fetchDirectoryDrivers();
        },
        children: [
          if (_directoryDriversLoading)
            const Padding(
              padding: EdgeInsets.all(20),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_directoryDrivers.isEmpty && _directoryDriversLoaded)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Text(loc.t('admin.directory.empty'), style: TextStyle(color: Colors.grey[600])),
            )
          else
            SizedBox(
              height: _directoryListHeight,
              child: Scrollbar(
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
                  itemCount: _directoryDrivers.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (ctx, i) => _buildDirectoryDriverRow(loc, _directoryDrivers[i]),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _directoryUnionsSection(AppLocalizations loc) {
    return Card(
      clipBehavior: Clip.antiAlias,
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        leading: Icon(Icons.apartment_rounded, color: Colors.blue[700]),
        title: Text(loc.t('admin.directory.unions_tile')),
        subtitle: Text(
          _directoryUnionsLoaded
              ? loc.tReplace('admin.directory.count_known', {'n': '$_directoryUnionsTotal'})
              : loc.t('admin.directory.tap_to_expand'),
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        ),
        onExpansionChanged: (open) {
          if (open && !_directoryUnionsLoaded) _fetchDirectoryUnions();
        },
        children: [
          if (_directoryUnionsLoading)
            const Padding(
              padding: EdgeInsets.all(20),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_directoryUnions.isEmpty && _directoryUnionsLoaded)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Text(loc.t('admin.directory.empty'), style: TextStyle(color: Colors.grey[600])),
            )
          else
            SizedBox(
              height: _directoryListHeight,
              child: Scrollbar(
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
                  itemCount: _directoryUnions.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (ctx, i) => _buildDirectoryUnionRow(loc, _directoryUnions[i]),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _pendingRegistrationsSection(AppLocalizations loc) {
    final pu = _unionRequests.length;
    final pd = _driverRequests.length;
    final pDoc = _unionDocRequests.length;
    final any = pu + pd + pDoc > 0;
    return Card(
      clipBehavior: Clip.antiAlias,
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        initiallyExpanded: any,
        leading: Icon(Icons.pending_actions_outlined, color: Colors.orange[800]),
        title: Text(loc.t('admin.directory.pending_tile')),
        subtitle: Text(
          loc.tReplace('admin.directory.pending_sub', {
            'unions': '$pu',
            'drivers': '$pd',
            'udocs': '$pDoc',
          }),
          style: TextStyle(fontSize: 11, color: Colors.grey[600]),
        ),
        children: [
          if (!any)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Text(loc.t('admin.directory.no_pending'), style: TextStyle(color: Colors.grey[600])),
            )
          else ...[
            if (pDoc > 0) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: Text(
                  loc.t('admin.section.union_doc_updates'),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              ..._unionDocRequests.map(
                (r) => _buildUnionDocUpdateCard(loc, r as Map<String, dynamic>),
              ),
            ],
            if (pu > 0) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Text(loc.t('admin.section.union'), style: const TextStyle(fontWeight: FontWeight.w600)),
              ),
              ..._unionRequests.map((r) => _buildUnionRequestCard(loc, r as Map<String, dynamic>)),
            ],
            if (pd > 0) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Text(loc.t('admin.section.driver'), style: const TextStyle(fontWeight: FontWeight.w600)),
              ),
              ..._driverRequests.map((r) => _buildRequestCard(loc, r as Map<String, dynamic>)),
            ],
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }

  Color _kycStatusColor(String s) {
    switch (s) {
      case 'approved':
        return Colors.green.shade700;
      case 'pending':
        return Colors.orange.shade800;
      case 'rejected':
        return Colors.red.shade700;
      case 'needs_reverify':
        return Colors.deepPurple.shade700;
      default:
        return Colors.blueGrey.shade700;
    }
  }

  Widget _buildDirectoryDriverRow(AppLocalizations loc, Map<String, dynamic> m) {
    final name = (m['name'] ?? '').toString();
    final email = (m['email'] ?? '').toString().trim();
    final phone = (m['phone'] ?? '').toString().trim();
    final id = (m['id'] ?? '').toString();
    final kyc = (m['driver_verification_status'] ?? m['driverVerificationStatus'] ?? '').toString();
    final sub = <String>[if (email.isNotEmpty) email, if (phone.isNotEmpty) phone].join(' · ');
    final c = _kycStatusColor(kyc);
    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      title: Text(
        name.isEmpty ? '—' : name,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (sub.isNotEmpty)
            Text(sub, style: TextStyle(fontSize: 12, color: Colors.grey[800])),
          if (id.isNotEmpty)
            SelectableText(
              '${loc.t('admin.kyc.user_id')}: $id',
              style: TextStyle(fontSize: 11, color: Colors.grey[600]),
            ),
        ],
      ),
      trailing: kyc.isEmpty
          ? null
          : Chip(
              label: Text(kyc, style: const TextStyle(fontSize: 10)),
              visualDensity: VisualDensity.compact,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              backgroundColor: c.withValues(alpha: 0.12),
              labelStyle: TextStyle(color: c, fontWeight: FontWeight.w600),
            ),
    );
  }

  Widget _buildDirectoryUnionRow(AppLocalizations loc, Map<String, dynamic> m) {
    final name = (m['name'] ?? '').toString();
    final email = (m['contact_email'] ?? m['contactEmail'] ?? '').toString().trim();
    final phone = (m['contact_phone'] ?? m['contactPhone'] ?? '').toString().trim();
    final id = (m['id'] ?? '').toString();
    final reg = (m['status'] ?? '').toString();
    final docs = (m['documents_status'] ?? m['documentsStatus'] ?? '').toString();
    final sub = <String>[if (email.isNotEmpty) email, if (phone.isNotEmpty) phone].join(' · ');
    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      title: Text(
        name.isEmpty ? '—' : name,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (sub.isNotEmpty)
            Text(sub, style: TextStyle(fontSize: 12, color: Colors.grey[800])),
          if (id.isNotEmpty)
            SelectableText(
              '${loc.t('admin.kyc.union_id')}: $id',
              style: TextStyle(fontSize: 11, color: Colors.grey[600]),
            ),
        ],
      ),
      isThreeLine: sub.isNotEmpty || id.isNotEmpty,
      trailing: (reg.isEmpty && docs.isEmpty)
          ? null
          : ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 120),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (reg.isNotEmpty)
                    Chip(
                      label: Text(reg, style: const TextStyle(fontSize: 9)),
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      padding: EdgeInsets.zero,
                      labelPadding: const EdgeInsets.symmetric(horizontal: 6),
                      backgroundColor: Colors.blue.shade50,
                    ),
                  if (docs.isNotEmpty)
                    Chip(
                      label: Text(docs, style: const TextStyle(fontSize: 9)),
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      padding: EdgeInsets.zero,
                      labelPadding: const EdgeInsets.symmetric(horizontal: 6),
                      backgroundColor: Colors.teal.shade50,
                    ),
                ],
              ),
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

  /// API may send snake_case or camelCase keys.
  String? _adminDocUrl(Map<String, dynamic> r, String snakeKey) {
    return _urlStr(r, snakeKey) ?? _urlStr(r, _snakeToLowerCamel(snakeKey));
  }

  String _snakeToLowerCamel(String snake) {
    final parts = snake.split('_').where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return snake;
    final head = parts.first;
    final tail = parts.skip(1).map((w) => w[0].toUpperCase() + w.substring(1)).join();
    return '$head$tail';
  }

  String _resolvePublicFileUrl(String url) {
    final raw = url.trim();
    if (raw.isEmpty) return raw;
    if (raw.startsWith('http://') || raw.startsWith('https://')) return raw;
    if (raw.startsWith('/')) return '${EnvConfig.publicFileBaseUrl}$raw';
    return '${EnvConfig.publicFileBaseUrl}/$raw';
  }

  Future<void> _openAdminDocumentUrl(String storageUrl) async {
    final resolved = _resolvePublicFileUrl(storageUrl);
    final uri = Uri.tryParse(resolved);
    if (uri == null) return;
    if (kIsWeb) {
      await launchUrl(uri, webOnlyWindowName: '_blank');
    } else {
      if (!mounted) return;
      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => KycDocumentViewerScreen(storageUrl: storageUrl),
        ),
      );
    }
  }

  List<Widget> _driverKycLinks(AppLocalizations loc, Map<String, dynamic> r) {
    void add(List<Widget> list, String labelKey, String? url) {
      if (url != null) list.add(_linkRow(loc, labelKey, url));
    }

    final out = <Widget>[];
    final aPdf = _adminDocUrl(r, 'aadhaar_document_url');
    final aFront = _adminDocUrl(r, 'aadhaar_front_url');
    final aBack = _adminDocUrl(r, 'aadhaar_back_url');
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

    final dlPdf = _adminDocUrl(r, 'driving_license_url');
    final dlFront = _adminDocUrl(r, 'driving_license_front_url');
    final dlBack = _adminDocUrl(r, 'driving_license_back_url');
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

    add(out, 'admin.kyc.rc_front', _adminDocUrl(r, 'rc_front_url'));
    add(out, 'admin.kyc.rc_back', _adminDocUrl(r, 'rc_back_url'));
    add(out, 'admin.kyc.rc', _adminDocUrl(r, 'rc_document_url'));
    add(out, 'admin.kyc.permit', _adminDocUrl(r, 'permit_document_url'));
    add(out, 'admin.kyc.insurance', _adminDocUrl(r, 'insurance_document_url'));
    return out;
  }

  List<Widget> _unionKycLinks(AppLocalizations loc, Map<String, dynamic> r) {
    void add(List<Widget> list, String labelKey, String? url) {
      if (url != null) list.add(_linkRow(loc, labelKey, url));
    }

    final out = <Widget>[];
    final oa = _adminDocUrl(r, 'owner_aadhaar_url');
    final oaf = _adminDocUrl(r, 'owner_aadhaar_front_url');
    final oab = _adminDocUrl(r, 'owner_aadhaar_back_url');
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

    final ldf = _adminDocUrl(r, 'leader_driving_license_front_url');
    final ldb = _adminDocUrl(r, 'leader_driving_license_back_url');
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
    add(out, 'admin.kyc.office_photo', _adminDocUrl(r, 'office_photo_url'));
    add(out, 'admin.kyc.union_photo', _adminDocUrl(r, 'union_photo_url'));
    add(out, 'admin.kyc.union_driver_list_photo', _adminDocUrl(r, 'union_driver_list_photo_url'));
    add(out, 'admin.kyc.union_rc_front', _adminDocUrl(r, 'owner_vehicle_rc_front_url'));
    add(out, 'admin.kyc.union_rc_back', _adminDocUrl(r, 'owner_vehicle_rc_back_url'));
    add(out, 'admin.kyc.union_rc', _adminDocUrl(r, 'owner_vehicle_rc_url'));
    return out;
  }

  Widget _buildRequestCard(AppLocalizations loc, Map<String, dynamic> r) {
    final id = r['id']?.toString() ?? '';
    final userId = (r['user_id'] ?? r['userId'])?.toString().trim() ?? '';
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
                      if (userId.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        SelectableText(
                          '${loc.t('admin.kyc.user_id')}: $userId',
                          style: TextStyle(fontSize: 11, color: Colors.grey[700]),
                        ),
                      ],
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
            if (docLinks.isEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  loc.t('admin.kyc.no_document_links'),
                  style: TextStyle(fontSize: 13, color: Colors.orange[900]),
                ),
              )
            else
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
                      if (id.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        SelectableText(
                          '${loc.t('admin.kyc.union_id')}: $id',
                          style: TextStyle(fontSize: 11, color: Colors.grey[700]),
                        ),
                      ],
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
            if (docLinks.isEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  loc.t('admin.kyc.no_document_links'),
                  style: TextStyle(fontSize: 13, color: Colors.orange[900]),
                ),
              )
            else
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

  /// Approved union re-submitted KYC documents; uses /admin/union-doc-requests/* (not new union registration).
  Widget _buildUnionDocUpdateCard(AppLocalizations loc, Map<String, dynamic> r) {
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
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.deepPurple.shade200, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Chip(
                avatar: Icon(Icons.folder_special_outlined, size: 18, color: Colors.deepPurple[800]),
                label: Text(
                  loc.t('admin.union_doc.badge'),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.deepPurple[900],
                  ),
                ),
                backgroundColor: Colors.deepPurple.shade50,
                visualDensity: VisualDensity.compact,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.deepPurple[100],
                  child: Icon(Icons.apartment, color: Colors.deepPurple[800]),
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
                      if (id.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        SelectableText(
                          '${loc.t('admin.kyc.union_id')}: $id',
                          style: TextStyle(fontSize: 11, color: Colors.grey[700]),
                        ),
                      ],
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
            if (docLinks.isEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  loc.t('admin.kyc.no_document_links'),
                  style: TextStyle(fontSize: 13, color: Colors.orange[900]),
                ),
              )
            else
              ...docLinks,
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton(
                  onPressed: () => _rejectUnionDocUpdate(id),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                  ),
                  child: Text(loc.t('admin.action.reject_docs')),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: () => _approveUnionDocUpdate(id),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                  child: Text(loc.t('admin.action.approve_docs')),
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
    final label = '${loc.t('admin.kyc.view_prefix')}: ${loc.t(labelKey)}';
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Material(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(8),
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () => _openAdminDocumentUrl(url),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  Icon(Icons.visibility_outlined, size: 20, color: Colors.grey.shade800),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade900,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, color: Colors.grey.shade600),
                ],
              ),
            ),
          ),
        ),
      ),
    );
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

String _adminPanelLoadErrLine(Object? msg, String shortLabel) {
  final s = msg?.toString().trim() ?? '';
  if (s.isEmpty) return '$shortLabel: load failed';
  return s;
}
