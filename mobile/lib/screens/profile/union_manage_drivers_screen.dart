import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/union_service.dart';

class UnionManageDriversScreen extends StatefulWidget {
  const UnionManageDriversScreen({super.key});

  @override
  State<UnionManageDriversScreen> createState() =>
      _UnionManageDriversScreenState();
}

class _UnionManageDriversScreenState extends State<UnionManageDriversScreen> {
  final _service = UnionService();
  bool _loading = true;
  String? _error;
  List<dynamic> _drivers = const [];

  static const _orange = Color(0xFFFF6B00);
  static const _green  = Color(0xFF43A047);

  // Avatar color palette — cycles through drivers
  static const _avatarColors = [
    Color(0xFFFF6B00), Color(0xFF1E88E5), Color(0xFF8E24AA),
    Color(0xFF00897B), Color(0xFFE53935), Color(0xFF3949AB),
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    final result = await _service.getDrivers();
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (result['success'] == true) {
        _drivers = result['drivers'] as List<dynamic>? ?? const [];
      } else {
        _error = result['message']?.toString() ?? 'Failed to load drivers';
      }
    });
  }

  Future<void> _call(String phone) async {
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  Future<void> _whatsapp(String number) async {
    final clean = number.replaceAll(RegExp(r'\D'), '');
    final uri = Uri.parse('https://wa.me/91$clean');
    if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _showAddDriverSheet() async {
    final nameCtrl     = TextEditingController();
    final vehicleCtrl  = TextEditingController();
    final phoneCtrl    = TextEditingController();
    final whatsappCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _AddDriverSheet(
        formKey: formKey,
        nameCtrl: nameCtrl,
        vehicleCtrl: vehicleCtrl,
        phoneCtrl: phoneCtrl,
        whatsappCtrl: whatsappCtrl,
        onSave: (submitting) async {
          if (!formKey.currentState!.validate()) return;
          final messenger = ScaffoldMessenger.of(context);
          submitting(true);
          final result = await _service.addDriver(
            name: nameCtrl.text.trim(),
            vehicleNumber: vehicleCtrl.text.trim(),
            phone: phoneCtrl.text.trim(),
            whatsappNumber: whatsappCtrl.text.trim(),
          );
          submitting(false);
          if (!context.mounted) return;
          if (result['success'] == true) {
            Navigator.pop(ctx);
            messenger.showSnackBar(
              SnackBar(
                content: const Row(children: [
                  Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
                  SizedBox(width: 8),
                  Text('Driver added successfully'),
                ]),
                backgroundColor: _green,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            );
            _load();
          } else {
            messenger.showSnackBar(
              SnackBar(
                content: Text(result['message']?.toString() ?? 'Failed to add driver'),
                backgroundColor: Colors.red,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
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
        title: const Text('Union Drivers', style: TextStyle(fontWeight: FontWeight.bold)),
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
        onPressed: _showAddDriverSheet,
        backgroundColor: _orange,
        foregroundColor: Colors.white,
        elevation: 3,
        icon: const Icon(Icons.person_add_alt_1_rounded),
        label: const Text('Add Driver', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _orange))
          : _error != null
              ? _buildError()
              : _drivers.isEmpty
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
                              itemCount: _drivers.length,
                              itemBuilder: (context, index) {
                                final d = _drivers[index] as Map<String, dynamic>? ?? {};
                                return _buildDriverCard(d, index);
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
            const Icon(Icons.people_alt_rounded, color: Colors.white, size: 22),
            const SizedBox(width: 10),
            Text(
              '${_drivers.length} driver${_drivers.length == 1 ? '' : 's'} in your union',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDriverCard(Map<String, dynamic> driver, int index) {
    final name    = (driver['name'] ?? '').toString();
    final vehicle = (driver['vehicle_number'] ?? '').toString();
    final phone   = (driver['phone'] ?? '').toString();
    final wa      = (driver['whatsapp_number'] ?? '').toString();
    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'D';
    final color   = _avatarColors[index % _avatarColors.length];

    return Container(
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
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            // Avatar
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                shape: BoxShape.circle,
                border: Border.all(color: color.withValues(alpha: 0.3), width: 2),
              ),
              child: Center(
                child: Text(
                  initial,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name.isNotEmpty ? name : 'Driver',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  if (vehicle.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Row(
                        children: [
                          Icon(Icons.directions_car_rounded, size: 14, color: Colors.grey.shade500),
                          const SizedBox(width: 5),
                          Text(
                            vehicle,
                            style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                          ),
                        ],
                      ),
                    ),
                  if (phone.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: Row(
                        children: [
                          Icon(Icons.phone_rounded, size: 14, color: Colors.grey.shade500),
                          const SizedBox(width: 5),
                          Text(
                            phone,
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            // Action buttons
            if (phone.isNotEmpty || wa.isNotEmpty)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (phone.isNotEmpty)
                    _actionBtn(
                      icon: Icons.call_rounded,
                      color: _green,
                      onTap: () => _call(phone),
                      tooltip: 'Call',
                    ),
                  if (wa.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    _actionBtn(
                      icon: Icons.chat_rounded,
                      color: const Color(0xFF25D366),
                      onTap: () => _whatsapp(wa),
                      tooltip: 'WhatsApp',
                    ),
                  ],
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _actionBtn({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    required String tooltip,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 19),
        ),
      ),
    );
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
                color: _orange.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.people_outline_rounded, size: 52, color: _orange),
            ),
            const SizedBox(height: 20),
            const Text(
              'No drivers yet',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Add your union drivers to start creating\nrides and schedules for them.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _showAddDriverSheet,
              icon: const Icon(Icons.person_add_alt_1_rounded),
              label: const Text('Add First Driver'),
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

// ── Add Driver Bottom Sheet ────────────────────────────────────────────────────

class _AddDriverSheet extends StatefulWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController nameCtrl, vehicleCtrl, phoneCtrl, whatsappCtrl;
  final void Function(Future<void> Function(bool)) onSave;

  const _AddDriverSheet({
    required this.formKey,
    required this.nameCtrl,
    required this.vehicleCtrl,
    required this.phoneCtrl,
    required this.whatsappCtrl,
    required this.onSave,
  });

  @override
  State<_AddDriverSheet> createState() => _AddDriverSheetState();
}

class _AddDriverSheetState extends State<_AddDriverSheet> {
  bool _submitting = false;
  static const _orange = Color(0xFFFF6B00);

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
                  child: const Icon(Icons.person_add_alt_1_rounded, color: _orange, size: 22),
                ),
                const SizedBox(width: 12),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Add Driver',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    Text('Fill in driver details below',
                        style: TextStyle(fontSize: 12, color: Colors.black54)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),
            _field(
              controller: widget.nameCtrl,
              label: 'Driver Full Name',
              icon: Icons.person_rounded,
              validator: (v) {
                if ((v?.trim() ?? '').isEmpty) return 'Enter driver name';
                if ((v?.trim() ?? '').length < 2) return 'Name too short';
                return null;
              },
            ),
            const SizedBox(height: 14),
            _field(
              controller: widget.vehicleCtrl,
              label: 'Vehicle Number (e.g. UK07-AB-1234)',
              icon: Icons.directions_car_rounded,
              validator: (v) {
                if ((v?.trim() ?? '').isEmpty) return 'Enter vehicle number';
                return null;
              },
            ),
            const SizedBox(height: 14),
            _field(
              controller: widget.phoneCtrl,
              label: 'Phone Number',
              icon: Icons.phone_rounded,
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 14),
            _field(
              controller: widget.whatsappCtrl,
              label: 'WhatsApp Number (optional)',
              icon: Icons.chat_rounded,
              keyboardType: TextInputType.phone,
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
                        'Save Driver',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 20, color: Colors.grey.shade500),
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
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      ),
    );
  }
}
