import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/feedback/app_feedback.dart';
import '../../../../providers/app_language_provider.dart';
import '../../../../services/trip_service.dart';
import '../../../../utils/phone_call_helper.dart';

DateTime? _safeParseDt(dynamic v) {
  if (v == null) return null;
  final s = v.toString().trim();
  if (s.isEmpty) return null;
  final withZ = (s.endsWith('Z') || s.contains('+')) ? s : '${s}Z';
  return DateTime.tryParse(withZ)?.toLocal();
}

Map<String, dynamic>? _safeMap(dynamic v) {
  if (v is Map<String, dynamic>) return v;
  if (v is Map) return Map<String, dynamic>.from(v);
  return null;
}

class PassengerMyRidesScreen extends StatefulWidget {
  const PassengerMyRidesScreen({super.key});

  @override
  State<PassengerMyRidesScreen> createState() => _PassengerMyRidesScreenState();
}

class _PassengerMyRidesScreenState extends State<PassengerMyRidesScreen> {
  final _tripService = TripService();
  List<dynamic> _bookings = [];
  bool _isLoading = true;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _loadBookings();
  }

  /// Single API call — no polling. Use pull-to-refresh to check for status updates.
  Future<void> _loadBookings() async {
    setState(() {
      _isLoading = _bookings.isEmpty;
      _loadError = null;
    });
    final result = await _tripService.getMyBookings();
    if (!mounted) return;
    final loc = AppLocalizations.of(context);
    final newBookings = result['bookings'] ?? [];
    setState(() {
      _isLoading = false;
      _bookings = newBookings;
      _loadError = result['success'] == false
          ? (result['message']?.toString() ?? loc.t('my_rides.load_failed'))
          : null;
    });
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'confirmed':
        return Colors.green;
      case 'completed':
        return Colors.teal;
      case 'pending':
        return Colors.orange;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _statusText(AppLocalizations loc, String status) {
    switch (status) {
      case 'confirmed':
        return loc.t('my_rides.status.confirmed');
      case 'completed':
        return loc.t('my_rides.status.completed');
      case 'pending':
        return loc.t('my_rides.status.pending');
      case 'cancelled':
        return loc.t('my_rides.status.cancelled');
      default:
        return status;
    }
  }

  bool _canCancelBooking(Map<String, dynamic> b) {
    final dep = b['departure_time'];
    if (dep == null) return true;
    final depTime = DateTime.tryParse(dep.toString());
    if (depTime == null) return true;
    return DateTime.now().isBefore(depTime);
  }

  @override
  Widget build(BuildContext context) {
    context.watch<AppLanguageProvider>();
    final loc = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(loc.t('my_rides.title')),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: _isLoading && _bookings.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : _loadError != null && _bookings.isEmpty
              ? _buildErrorState(loc)
              : _bookings.isEmpty
                  ? _buildEmpty(loc)
                  : RefreshIndicator(
                      onRefresh: _loadBookings,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _bookings.length,
                        itemBuilder: (context, i) => _buildBookingCard(loc, _bookings[i]),
                      ),
                    ),
    );
  }

  Widget _buildErrorState(AppLocalizations loc) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
            const SizedBox(height: 16),
            Text(
              _loadError ?? loc.t('my_rides.load_failed'),
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.grey[700]),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadBookings,
              icon: const Icon(Icons.refresh),
              label: Text(loc.t('my_rides.retry')),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty(AppLocalizations loc) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.confirmation_number_outlined, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            loc.t('my_rides.empty.title'),
            style: TextStyle(fontSize: 18, color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          Text(
            loc.t('my_rides.empty.subtitle'),
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  Widget _buildBookingCard(AppLocalizations loc, Map<String, dynamic> b) {
    final status = b['status']?.toString() ?? 'pending';
    final isApproved = status == 'confirmed' || status == 'completed';
    final statusColor = _statusColor(status);

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _statusText(loc, status),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: statusColor,
                    ),
                  ),
                ),
                Text(
                  '₹${(double.tryParse((b['total_amount'] ?? 0).toString()) ?? 0).toStringAsFixed(0)}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.trip_origin, color: Colors.green, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    b['from_location']?.toString() ?? '',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const Padding(
              padding: EdgeInsets.only(left: 8, top: 4, bottom: 4),
              child: Icon(Icons.arrow_downward, size: 16, color: Colors.grey),
            ),
            Row(
              children: [
                const Icon(Icons.location_on, color: Colors.red, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    b['to_location']?.toString() ?? '',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.access_time, size: 18, color: Colors.grey),
                const SizedBox(width: 4),
                Text(
                  _safeParseDt(b['departure_time']) != null
                      ? DateFormat('dd MMM, hh:mm a')
                          .format(_safeParseDt(b['departure_time'])!)
                      : '-',
                  style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                ),
              ],
            ),
            if (isApproved && _safeMap(b['driver']) != null) ...[
              const SizedBox(height: 12),
              Builder(builder: (_) {
                final driver = _safeMap(b['driver'])!;
                final driverName = driver['name']?.toString() ?? loc.t('my_rides.driver_default');
                final driverPhone = (driver['phone'] ?? '').toString().trim();
                final driverWhatsapp = (driver['whatsapp_number'] ?? '').toString().trim();
                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 18,
                            backgroundColor: Colors.blue,
                            child: Text(
                              driverName.isNotEmpty ? driverName[0].toUpperCase() : 'D',
                              style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  driverName,
                                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                                ),
                                if ((b['vehicle_number'] ?? '').toString().isNotEmpty)
                                  Text(
                                    b['vehicle_number'].toString(),
                                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          if (driverPhone.isNotEmpty)
                            Expanded(
                              child: InkWell(
                                onTap: () => launchPhoneCall(context, driverPhone),
                                borderRadius: BorderRadius.circular(8),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF16A34A).withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.call_rounded, size: 18, color: Color(0xFF16A34A)),
                                      SizedBox(width: 6),
                                      Text('Call', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF16A34A))),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          if (driverWhatsapp.isNotEmpty) ...[
                            const SizedBox(width: 8),
                            Expanded(
                              child: InkWell(
                                onTap: () => _openChatWithDriver(loc, driver),
                                borderRadius: BorderRadius.circular(8),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF25D366).withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.chat_rounded, size: 18, color: Color(0xFF25D366)),
                                      SizedBox(width: 6),
                                      Text('WhatsApp', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF25D366))),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                );
              }),
            ] else if (status == 'pending')
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      loc.t('my_rides.pending_message'),
                      style: TextStyle(fontSize: 13, color: Colors.orange[700], fontStyle: FontStyle.italic),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      loc.t('my_rides.pull_refresh'),
                      style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        OutlinedButton.icon(
                          onPressed: () => _showAskQuestionDialog(loc),
                          icon: const Icon(Icons.help_outline, size: 18),
                          label: Text(loc.t('my_rides.ask_question')),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.blue[700],
                            side: BorderSide(color: Colors.blue[300]!),
                          ),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton.icon(
                          onPressed: () => _showCancelBookingDialog(loc, b),
                          icon: const Icon(Icons.cancel_outlined, size: 18),
                          label: Text(loc.t('my_rides.cancel_booking')),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red[700],
                            side: BorderSide(color: Colors.red[300]!),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            if (status != 'cancelled' && status != 'completed') ...[
              const SizedBox(height: 12),
              if (_canCancelBooking(b))
                OutlinedButton.icon(
                  onPressed: () => _showCancelBookingDialog(loc, b),
                  icon: const Icon(Icons.cancel_outlined, size: 18),
                  label: Text(loc.t('my_rides.cancel_booking')),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red[700],
                    side: BorderSide(color: Colors.red[300]!),
                  ),
                )
              else
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    loc.t('my_rides.cancel_blocked'),
                    style: TextStyle(fontSize: 12, color: Colors.grey[600], fontStyle: FontStyle.italic),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _openChatWithDriver(AppLocalizations loc, Map<String, dynamic> driver) async {
    final whatsapp = driver['whatsapp_number']?.toString().trim();
    final phone = driver['phone']?.toString() ?? '';
    final numberToUse = (whatsapp != null && whatsapp.isNotEmpty) ? whatsapp : phone;
    if (numberToUse.isEmpty) {
      if (!mounted) return;
      AppFeedback.show(
        context,
        loc.t('my_rides.contact_unavailable'),
        kind: AppFeedbackKind.warning,
      );
      return;
    }
    final cleanPhone = numberToUse.replaceAll(RegExp(r'[^\d+]'), '');
    final waNumber = cleanPhone.startsWith('91') ? cleanPhone : '91$cleanPhone';
    final uri = Uri.parse('https://wa.me/$waNumber');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else if (mounted) {
        await launchPhoneCall(context, numberToUse);
      }
    } catch (_) {
      if (!mounted) return;
      AppFeedback.show(
        context,
        loc.t('my_rides.open_chat_failed'),
        kind: AppFeedbackKind.error,
      );
    }
  }

  void _showCancelBookingDialog(AppLocalizations loc, Map<String, dynamic> booking) {
    final bookingId = booking['id']?.toString();
    final status = booking['status']?.toString() ?? '';
    if (bookingId == null || bookingId.isEmpty) return;
    final reasonController = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              loc.t('my_rides.cancel_confirm_title'),
              style: Theme.of(ctx).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            if (status == 'confirmed')
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  loc.t('my_rides.cancel_policy'),
                  style: TextStyle(fontSize: 12, color: Colors.orange[700]),
                ),
              ),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              decoration: InputDecoration(
                labelText: loc.t('my_rides.reason_label'),
                hintText: loc.t('my_rides.reason_hint'),
                border: const OutlineInputBorder(),
              ),
              maxLines: 2,
              maxLength: 300,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: Text(loc.t('my_rides.keep_booking')),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () async {
                      Navigator.pop(ctx);
                      final result = await _tripService.cancelBooking(
                        bookingId,
                        reason: reasonController.text.trim().isEmpty ? null : reasonController.text.trim(),
                      );
                      if (!mounted) return;
                      if (result['success'] == true) {
                        AppFeedback.show(
                          context,
                          result['message']?.toString() ??
                              loc.t('my_rides.booking_cancelled_fallback'),
                          kind: AppFeedbackKind.success,
                        );
                        _loadBookings();
                      } else {
                        AppFeedback.show(
                          context,
                          result['message']?.toString() ??
                              loc.t('my_rides.cancel_failed_fallback'),
                          kind: AppFeedbackKind.error,
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                    child: Text(loc.t('my_rides.cancel_booking')),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showAskQuestionDialog(AppLocalizations loc) {
    final controller = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              loc.t('my_rides.question_title'),
              style: Theme.of(ctx).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              loc.t('my_rides.question_body'),
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              decoration: InputDecoration(
                hintText: loc.t('my_rides.question_field_hint'),
                border: const OutlineInputBorder(),
              ),
              maxLines: 3,
              maxLength: 500,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                if (!mounted) return;
                final empty = controller.text.trim().isEmpty;
                AppFeedback.show(
                  context,
                  empty
                      ? loc.t('my_rides.question_snackbar_empty')
                      : loc.t('my_rides.question_snackbar_note'),
                  kind: AppFeedbackKind.info,
                );
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
              child: Text(loc.t('my_rides.question_send')),
            ),
          ],
        ),
      ),
    );
  }
}
