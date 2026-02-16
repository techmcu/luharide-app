import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/trip_service.dart';

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
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _loadBookings();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadBookings() async {
    setState(() {
      _isLoading = _bookings.isEmpty;
      _loadError = null;
    });
    final result = await _tripService.getMyBookings();
    if (!mounted) return;
    final newBookings = result['bookings'] ?? [];
    final hasPending = newBookings.any((b) => (b['status']?.toString() ?? '') == 'pending');
    setState(() {
      _isLoading = false;
      _bookings = newBookings;
      _loadError = result['success'] == false ? (result['message'] ?? 'Failed to load') : null;
    });
    // Auto-refresh every 10s when there are pending bookings (approval status updates)
    _refreshTimer?.cancel();
    if (hasPending) {
      _refreshTimer = Timer.periodic(const Duration(seconds: 10), (_) => _loadBookings());
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'confirmed':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _statusText(String status) {
    switch (status) {
      case 'confirmed':
        return 'Approved';
      case 'pending':
        return 'Pending';
      case 'cancelled':
        return 'Cancelled';
      default:
        return status;
    }
  }

  /// Cancel allowed only until 2 min before departure; after ride start = not allowed (matches backend).
  bool _canCancelBooking(Map<String, dynamic> b) {
    if (b['status'] != 'confirmed') return true;
    final dep = b['departure_time'];
    if (dep == null) return true;
    final depTime = DateTime.tryParse(dep.toString());
    if (depTime == null) return true;
    final now = DateTime.now();
    if (!now.isBefore(depTime)) return false;
    if (depTime.difference(now).inMinutes < 2) return false;
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Rides'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: _isLoading && _bookings.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : _loadError != null && _bookings.isEmpty
              ? _buildErrorState()
              : _bookings.isEmpty
                  ? _buildEmpty()
                  : RefreshIndicator(
                  onRefresh: _loadBookings,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _bookings.length,
                    itemBuilder: (context, i) => _buildBookingCard(_bookings[i]),
                  ),
                ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
            const SizedBox(height: 16),
            Text(
              _loadError ?? 'Failed to load',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.grey[700]),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadBookings,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.confirmation_number_outlined, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            'No rides yet',
            style: TextStyle(fontSize: 18, color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          Text(
            'Book a ride to see it here',
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  Widget _buildBookingCard(Map<String, dynamic> b) {
    final status = b['status']?.toString() ?? 'pending';
    final isApproved = status == 'confirmed';

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
                    color: _statusColor(status).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _statusText(status),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: _statusColor(status),
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
                  b['departure_time'] != null
                      ? DateFormat('dd MMM, hh:mm a').format(DateTime.parse(b['departure_time'] as String).toLocal())
                      : '-',
                  style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                ),
              ],
            ),
            if (isApproved && b['driver'] != null) ...[
              const SizedBox(height: 12),
              InkWell(
                onTap: () => _openChatWithDriver(b['driver']),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue[200]!),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: Colors.blue,
                        child: Text(
                          (b['driver']['name'] ?? 'D')[0].toUpperCase(),
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              b['driver']['name'] ?? 'Driver',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Tap to chat on WhatsApp',
                              style: TextStyle(fontSize: 11, color: Colors.blue[700], fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.chat_bubble_outline, color: Colors.blue[700], size: 24),
                    ],
                  ),
                ),
              ),
            ] else if (status == 'pending')
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Waiting for driver approval. You\'ll see driver details once approved.',
                      style: TextStyle(fontSize: 13, color: Colors.orange[700], fontStyle: FontStyle.italic),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Pull down to refresh for latest status',
                      style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        OutlinedButton.icon(
                          onPressed: () => _showAskQuestionDialog(context, b),
                          icon: const Icon(Icons.help_outline, size: 18),
                          label: const Text('Ask a question'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.blue[700],
                            side: BorderSide(color: Colors.blue[300]!),
                          ),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton.icon(
                          onPressed: () => _showCancelBookingDialog(b),
                          icon: const Icon(Icons.cancel_outlined, size: 18),
                          label: const Text('Cancel booking'),
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
            if (status != 'cancelled' && status != 'pending') ...[
              const SizedBox(height: 12),
              if (_canCancelBooking(b))
                OutlinedButton.icon(
                  onPressed: () => _showCancelBookingDialog(b),
                  icon: const Icon(Icons.cancel_outlined, size: 18),
                  label: const Text('Cancel booking'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red[700],
                    side: BorderSide(color: Colors.red[300]!),
                  ),
                )
              else
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    'Cancel not allowed (within 2 min of departure or ride started)',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600], fontStyle: FontStyle.italic),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _openChatWithDriver(Map<String, dynamic> driver) async {
    // Prefer WhatsApp number for direct chat
    final whatsapp = driver['whatsapp_number']?.toString().trim();
    final phone = driver['phone']?.toString() ?? '';
    final numberToUse = (whatsapp != null && whatsapp.isNotEmpty) ? whatsapp : phone;
    if (numberToUse.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Driver contact not available. Ask driver to add WhatsApp in profile.')),
        );
      }
      return;
    }
    final cleanPhone = numberToUse.replaceAll(RegExp(r'[^\d+]'), '');
    final waNumber = cleanPhone.startsWith('91') ? cleanPhone : '91$cleanPhone';
    final uri = Uri.parse('https://wa.me/$waNumber');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        final telUri = Uri.parse('tel:$numberToUse');
        if (await canLaunchUrl(telUri)) {
          await launchUrl(telUri, mode: LaunchMode.externalApplication);
        }
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open chat')),
        );
      }
    }
  }

  void _showCancelBookingDialog(Map<String, dynamic> booking) {
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
              'Cancel booking?',
              style: Theme.of(ctx).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            if (status == 'confirmed')
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Cancellation is allowed until 2 minutes before departure (for testing).',
                  style: TextStyle(fontSize: 12, color: Colors.orange[700]),
                ),
              ),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: 'Reason (optional)',
                hintText: 'E.g. plan changed',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Keep booking'),
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
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(result['message'] ?? 'Booking cancelled'), backgroundColor: Colors.green),
                        );
                        _loadBookings();
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(result['message'] ?? 'Could not cancel'), backgroundColor: Colors.red),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                    child: const Text('Cancel booking'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showAskQuestionDialog(BuildContext context, Map<String, dynamic> booking) {
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
              'Ask a question',
              style: Theme.of(ctx).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Your question will be sent to the driver. (Coming soon: backend)',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                hintText: 'E.g. pickup point, luggage space...',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(controller.text.trim().isEmpty
                        ? 'Question feature coming soon'
                        : 'Question sent! (Demo - backend coming soon)'),
                    backgroundColor: Colors.green,
                  ),
                );
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
              child: const Text('Send'),
            ),
          ],
        ),
      ),
    );
  }
}
