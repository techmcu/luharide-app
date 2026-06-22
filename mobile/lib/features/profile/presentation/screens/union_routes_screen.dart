import 'package:flutter/material.dart';
import '../../../../core/feedback/app_feedback.dart';
import '../../../../core/constants/input_limits.dart';
import '../../../../services/union_service.dart';
import '../../../../services/trip_service.dart';
import '../../../../models/picked_location.dart';
import '../../../../widgets/location_picker_screen.dart';

class UnionRoutesScreen extends StatefulWidget {
  const UnionRoutesScreen({super.key});

  @override
  State<UnionRoutesScreen> createState() => _UnionRoutesScreenState();
}

class _UnionRoutesScreenState extends State<UnionRoutesScreen> {
  final _service = UnionService();
  bool _loading = true;
  String? _error;
  List<dynamic> _routes = const [];

  static const _orange = Color(0xFFFF6B00);
  static const _blue   = Color(0xFF1E88E5);

  // Color pairs for route cards — cycles
  static const _cardSchemes = [
    [Color(0xFFFF6B00), Color(0xFF1E88E5)],
    [Color(0xFF8E24AA), Color(0xFF00897B)],
    [Color(0xFFE53935), Color(0xFF3949AB)],
    [Color(0xFF00897B), Color(0xFF8E24AA)],
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    final result = await _service.getRoutes();
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (result['success'] == true) {
        _routes = result['routes'] as List<dynamic>? ?? const [];
      } else {
        _error = result['message']?.toString() ?? 'Failed to load routes';
      }
    });
  }

  Future<void> _showAddRouteSheet() async {
    final fromCtrl = TextEditingController();
    final toCtrl   = TextEditingController();
    final formKey  = GlobalKey<FormState>();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _AddRouteSheet(
        formKey: formKey,
        fromCtrl: fromCtrl,
        toCtrl: toCtrl,
        onSave: (submitting) async {
          if (!formKey.currentState!.validate()) return;
          submitting(true);
          final res = await _service.addRoute(
            fromLocation: fromCtrl.text.trim(),
            toLocation: toCtrl.text.trim(),
          );
          submitting(false);
          if (!context.mounted) return;
          if (res['success'] == true) {
            Navigator.pop(ctx);
            AppFeedback.show(
              context,
              'Route saved',
              kind: AppFeedbackKind.success,
              icon: Icons.check_circle_rounded,
            );
            _load();
          } else {
            AppFeedback.show(
              context,
              res['message']?.toString() ?? 'Failed to add route',
              kind: AppFeedbackKind.error,
            );
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('Preset Routes', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: _orange,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddRouteSheet,
        backgroundColor: _orange,
        foregroundColor: Colors.white,
        elevation: 3,
        icon: const Icon(Icons.add_road_rounded),
        label: const Text('Add Route', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _orange))
          : _error != null
              ? _buildError()
              : _routes.isEmpty
                  ? _buildEmpty()
                  : RefreshIndicator(
                      color: _orange,
                      onRefresh: _load,
                      child: Column(
                        children: [
                          _buildHeader(),
                          Expanded(
                            child: ListView.builder(
                              padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                              itemCount: _routes.length,
                              itemBuilder: (context, index) {
                                final r = _routes[index] as Map<String, dynamic>? ?? {};
                                return _buildRouteCard(r, index);
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      color: _orange,
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            const Icon(Icons.alt_route_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Text(
              '${_routes.length} saved route${_routes.length == 1 ? '' : 's'}',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
            const Spacer(),
            Text(
              'Use these when creating rides',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.8),
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDeleteRoute(Map<String, dynamic> route) async {
    final from = route['from_location']?.toString() ?? '';
    final to = route['to_location']?.toString() ?? '';
    final routeId = route['id']?.toString();
    if (routeId == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove Route'),
        content: Text('Remove route "$from → $to" from your union?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final result = await _service.deleteRoute(routeId);
    if (!mounted) return;
    if (result['success'] == true) {
      AppFeedback.show(context, 'Route removed', kind: AppFeedbackKind.success);
      _load();
    } else {
      AppFeedback.show(context, result['message'] ?? 'Failed to remove route', kind: AppFeedbackKind.error);
    }
  }

  Widget _buildRouteCard(Map<String, dynamic> route, int index) {
    final from = route['from_location']?.toString() ?? '';
    final to   = route['to_location']?.toString() ?? '';
    final scheme = _cardSchemes[index % _cardSchemes.length];
    final fromColor = scheme[0];
    final toColor   = scheme[1];

    return GestureDetector(
      onLongPress: () => _confirmDeleteRoute(route),
      child: Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Route visual — FROM dot, line, TO dot
            Column(
              children: [
                Container(
                  width: 14, height: 14,
                  decoration: BoxDecoration(color: fromColor, shape: BoxShape.circle),
                ),
                Container(
                  width: 2, height: 26,
                  color: Colors.grey.shade300,
                  margin: const EdgeInsets.symmetric(vertical: 3),
                ),
                Container(
                  width: 14, height: 14,
                  decoration: BoxDecoration(
                    color: toColor,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.location_on_rounded, size: 10, color: Colors.white),
                ),
              ],
            ),
            const SizedBox(width: 14),
            // Labels
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: fromColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'FROM',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: fromColor,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    from.isNotEmpty ? from : '—',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: toColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'TO',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: toColor,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    to.isNotEmpty ? to : '—',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ],
              ),
            ),
            // Route number badge
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [fromColor.withValues(alpha: 0.8), toColor.withValues(alpha: 0.8)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Text(
                  '${index + 1}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ));
  }

  Widget _buildEmpty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: _blue.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.alt_route_rounded, size: 52, color: _blue),
            ),
            const SizedBox(height: 20),
            const Text('No routes yet',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(
              'Save common routes like "Purola → Dehradun"\nso you can quickly pick them when creating rides.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _showAddRouteSheet,
              icon: const Icon(Icons.add_road_rounded),
              label: const Text('Add First Route'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _orange,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 13),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
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
            Icon(Icons.wifi_off_rounded, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(_error!, textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.black54)),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try Again'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _orange, foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Add Route Bottom Sheet ─────────────────────────────────────────────────────

class _AddRouteSheet extends StatefulWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController fromCtrl, toCtrl;
  final void Function(Future<void> Function(bool)) onSave;

  const _AddRouteSheet({
    required this.formKey,
    required this.fromCtrl,
    required this.toCtrl,
    required this.onSave,
  });

  @override
  State<_AddRouteSheet> createState() => _AddRouteSheetState();
}

class _AddRouteSheetState extends State<_AddRouteSheet> {
  bool _submitting = false;
  final _tripService = TripService();
  static const _orange = Color(0xFFFF6B00);
  static const _blue   = Color(0xFF1E88E5);

  /// Open the Ola-backed location picker and fill the field with the chosen name.
  Future<void> _pickRoutePoint(TextEditingController controller, String label) async {
    final result = await Navigator.push<PickedLocation>(
      context,
      MaterialPageRoute(
        builder: (_) => LocationPickerScreen(
          title: label,
          initialValue: controller.text,
          tripService: _tripService,
        ),
      ),
    );
    if (result != null) setState(() => controller.text = result.name);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        top: 8,
        left: 20,
        right: 20,
      ),
      child: Form(
        key: widget.formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
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
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: _orange.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.add_road_rounded, color: _orange, size: 22),
                ),
                const SizedBox(width: 12),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Add Route',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    Text('Enter the from and to locations',
                        style: TextStyle(fontSize: 12, color: Colors.black54)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),
            // FROM field — opens Ola location picker
            TextFormField(
              controller: widget.fromCtrl,
              readOnly: true,
              onTap: () => _pickRoutePoint(widget.fromCtrl, 'From (e.g. Purola)'),
              textCapitalization: TextCapitalization.words,
              maxLength: InputLimits.unionLocation,
              decoration: InputDecoration(
                counterText: '',
                labelText: 'From (e.g. Purola)',
                prefixIcon: Container(
                  margin: const EdgeInsets.all(10),
                  width: 10, height: 10,
                  decoration: const BoxDecoration(color: _orange, shape: BoxShape.circle),
                ),
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
                  borderSide: const BorderSide(color: _orange, width: 1.5),
                ),
              ),
              validator: (v) =>
                  (v?.trim() ?? '').isEmpty ? 'Enter departure location' : null,
            ),
            // Arrow visual
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.arrow_downward_rounded, size: 16, color: Colors.grey),
                        SizedBox(width: 4),
                        Text('to', style: TextStyle(color: Colors.grey, fontSize: 12)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // TO field — opens Ola location picker
            TextFormField(
              controller: widget.toCtrl,
              readOnly: true,
              onTap: () => _pickRoutePoint(widget.toCtrl, 'To (e.g. Dehradun)'),
              textCapitalization: TextCapitalization.words,
              maxLength: InputLimits.unionLocation,
              decoration: InputDecoration(
                counterText: '',
                labelText: 'To (e.g. Dehradun)',
                prefixIcon: Container(
                  margin: const EdgeInsets.all(10),
                  width: 10, height: 10,
                  decoration: const BoxDecoration(color: _blue, shape: BoxShape.circle),
                ),
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
                  borderSide: const BorderSide(color: _blue, width: 1.5),
                ),
              ),
              validator: (v) =>
                  (v?.trim() ?? '').isEmpty ? 'Enter destination location' : null,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _submitting
                    ? null
                    : () {
                        widget.onSave((val) async {
                          if (mounted) setState(() => _submitting = val);
                        });
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: _orange,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: _orange.withValues(alpha: 0.6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                child: _submitting
                    ? const SizedBox(
                        width: 22, height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Text(
                        'Save Route',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
