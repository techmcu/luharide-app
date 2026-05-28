import 'package:flutter/material.dart';
import '../../../../core/feedback/app_feedback.dart';
import '../../../../services/platform_admin_service.dart';

class PlatformTripDetailScreen extends StatefulWidget {
  final String tripId;
  const PlatformTripDetailScreen({super.key, required this.tripId});

  @override
  State<PlatformTripDetailScreen> createState() => _PlatformTripDetailScreenState();
}

class _PlatformTripDetailScreenState extends State<PlatformTripDetailScreen> {
  final _service = PlatformAdminService();
  Map<String, dynamic>? _trip;
  List<dynamic> _bookings = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final res = await _service.getTripDetail(widget.tripId);
    if (!mounted) return;
    if (res['success'] == true) {
      setState(() {
        _trip = res['trip'] is Map ? Map<String, dynamic>.from(res['trip']) : null;
        _bookings = res['bookings'] is List ? res['bookings'] : [];
        _loading = false;
      });
    } else {
      setState(() => _loading = false);
      if (mounted) AppFeedback.show(context, res['message'] ?? 'Failed', kind: AppFeedbackKind.error);
    }
  }

  Future<void> _cancelTrip() async {
    if (_trip == null) return;
    final status = _trip!['status'] ?? '';
    if (status == 'cancelled' || status == 'completed') {
      AppFeedback.show(context, 'Trip is already $status', kind: AppFeedbackKind.warning);
      return;
    }

    final reasonCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel Trip?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('All passengers will be notified. This cannot be undone.'),
            const SizedBox(height: 12),
            TextField(
              controller: reasonCtrl,
              decoration: const InputDecoration(hintText: 'Reason (optional)'),
              maxLines: 2,
              maxLength: 300,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Back')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Cancel Trip'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final res = await _service.cancelTrip(widget.tripId, reason: reasonCtrl.text.trim());
    reasonCtrl.dispose();
    if (!mounted) return;
    if (res['success'] == true) {
      AppFeedback.show(context, 'Trip cancelled', kind: AppFeedbackKind.success);
      _load();
    } else {
      AppFeedback.show(context, res['message'] ?? 'Failed', kind: AppFeedbackKind.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Trip Detail'), centerTitle: true),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _trip == null
              ? const Center(child: Text('Trip not found'))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _tripInfoCard(),
                      const SizedBox(height: 16),
                      _driverCard(),
                      const SizedBox(height: 16),
                      Text('Bookings (${_bookings.length})', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      if (_bookings.isEmpty)
                        const Text('No bookings yet', style: TextStyle(color: Colors.black45))
                      else
                        ..._bookings.map(_buildBookingCard),
                    ],
                  ),
                ),
    );
  }

  Widget _tripInfoCard() {
    final from = _trip!['from_location'] ?? '';
    final to = _trip!['to_location'] ?? '';
    final status = _trip!['status'] ?? '';
    final fare = _trip!['fare_per_seat'] ?? 0;
    final available = _trip!['available_seats'] ?? 0;
    final total = _trip!['total_capacity'] ?? 0;
    final vehicle = _trip!['vehicle_number'] ?? 'N/A';
    final departure = _trip!['departure_time'] ?? '';
    final canCancel = status != 'cancelled' && status != 'completed';

    Color statusColor;
    switch (status) {
      case 'scheduled': statusColor = Colors.blue; break;
      case 'in_progress': statusColor = Colors.green; break;
      case 'completed': statusColor = Colors.teal; break;
      case 'cancelled': statusColor = Colors.red; break;
      default: statusColor = Colors.grey;
    }

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
                Expanded(
                  child: Text('$from → $to', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(status.toUpperCase(), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: statusColor)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _infoRow(Icons.schedule, 'Departure: ${_formatDateTime(departure)}'),
            _infoRow(Icons.currency_rupee, 'Fare: ₹$fare per seat'),
            _infoRow(Icons.event_seat, 'Seats: $available available / $total total'),
            _infoRow(Icons.directions_car, 'Vehicle: $vehicle'),
            if (canCancel) ...[
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _cancelTrip,
                  icon: const Icon(Icons.cancel),
                  label: const Text('Cancel Trip'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _driverCard() {
    final name = _trip!['driver_name'] ?? 'Unknown';
    final phone = _trip!['driver_phone'] ?? '';
    final email = _trip!['driver_email'] ?? '';

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Driver', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black54)),
            const SizedBox(height: 8),
            _infoRow(Icons.person, name),
            if (phone.isNotEmpty) _infoRow(Icons.phone, phone),
            if (email.isNotEmpty) _infoRow(Icons.email, email),
          ],
        ),
      ),
    );
  }

  Widget _buildBookingCard(dynamic booking) {
    final name = booking['passenger_name'] ?? 'Unknown';
    final phone = booking['passenger_phone'] ?? '';
    final status = booking['status'] ?? '';
    final seats = booking['seat_numbers'] ?? [];
    final amount = booking['total_amount'] ?? 0;

    Color statusColor;
    switch (status) {
      case 'confirmed': statusColor = Colors.green; break;
      case 'pending': statusColor = Colors.orange; break;
      case 'cancelled': statusColor = Colors.red; break;
      default: statusColor = Colors.grey;
    }

    return Card(
      elevation: 0,
      color: Colors.grey.shade50,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: statusColor.withOpacity(0.1),
              child: Icon(Icons.person, size: 18, color: statusColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  Text(
                    '${phone.isNotEmpty ? phone : "No phone"} • Seats: $seats • ₹$amount',
                    style: const TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(status, style: TextStyle(fontSize: 11, color: statusColor, fontWeight: FontWeight.w500)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.black45),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }

  String _formatDateTime(String? raw) {
    if (raw == null || raw.isEmpty) return 'N/A';
    final d = DateTime.tryParse(raw);
    if (d == null) return raw;
    final hour = d.hour.toString().padLeft(2, '0');
    final min = d.minute.toString().padLeft(2, '0');
    return '${d.day}/${d.month}/${d.year} $hour:$min';
  }
}
