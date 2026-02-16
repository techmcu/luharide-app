import 'package:flutter/material.dart';
import '../../models/notification_model.dart';
import '../../services/notification_service.dart';
import '../../widgets/rate_ride_dialog.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final _notificationService = NotificationService();
  late Future<List<NotificationModel>> _future;

  @override
  void initState() {
    super.initState();
    _future = _notificationService.fetchNotificationModels();
  }

  Future<void> _refresh() async {
    setState(() {
      _future = _notificationService.fetchNotificationModels();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          IconButton(
            icon: const Icon(Icons.done_all),
            tooltip: 'Mark all as read',
            onPressed: () async {
              final ok = await _notificationService.markAllAsRead();
              if (ok && mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('All notifications marked as read')),
                );
                _refresh();
              }
            },
          ),
        ],
      ),
      body: FutureBuilder<List<NotificationModel>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Failed to load notifications',
                style: TextStyle(color: Colors.red[400]),
              ),
            );
          }

          final items = snapshot.data ?? [];
          if (items.isEmpty) {
            return RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  const SizedBox(height: 120),
                  Center(
                    child: Column(
                      children: [
                        Icon(Icons.notifications_none, size: 64, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        Text('No notifications yet', style: TextStyle(fontSize: 16, color: Colors.grey[600])),
                        const SizedBox(height: 4),
                        Text(
                          'You\'ll see updates about verification, bookings and more here.',
                          style: TextStyle(fontSize: 13, color: Colors.grey[500]),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: items.length,
              itemBuilder: (context, index) {
                final n = items[index];
                return _buildNotificationTile(n);
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildNotificationTile(NotificationModel n) {
    final subtitle = n.message ?? '';
    final created = n.createdAt;
    String timeText = '';
    if (created != null) {
      final now = DateTime.now();
      final diff = now.difference(created);
      if (diff.inMinutes < 1) {
        timeText = 'Just now';
      } else if (diff.inMinutes < 60) {
        timeText = '${diff.inMinutes} min ago';
      } else if (diff.inHours < 24) {
        timeText = '${diff.inHours} h ago';
      } else {
        timeText = '${diff.inDays} d ago';
      }
    }

    return Card(
      elevation: n.isRead ? 0 : 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: _leadingIconForType(n.type),
        title: Text(
          n.title,
          style: TextStyle(
            fontWeight: n.isRead ? FontWeight.w400 : FontWeight.w600,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (subtitle.isNotEmpty)
              Text(
                subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            if (timeText.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  timeText,
                  style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                ),
              ),
          ],
        ),
        onTap: () async {
          if (!n.isRead) {
            await _notificationService.markAsRead(n.id);
            _refresh();
          }
          if (n.type == 'rate_ride' && n.bookingId != null && n.bookingId!.isNotEmpty) {
            final submitted = await showDialog<bool>(
              context: context,
              barrierDismissible: false,
              builder: (_) => RateRideDialog(
                bookingId: n.bookingId!,
                title: n.title,
              ),
            );
            if (submitted == true) _refresh();
          }
        },
      ),
    );
  }

  Widget _leadingIconForType(String type) {
    IconData icon;
    Color color;

    switch (type) {
      case 'verification_approved':
        icon = Icons.verified_user;
        color = Colors.green;
        break;
      case 'verification_rejected':
        icon = Icons.error_outline;
        color = Colors.redAccent;
        break;
      case 'booking_status':
        icon = Icons.directions_car;
        color = Colors.blue;
        break;
      case 'rate_ride':
        icon = Icons.star;
        color = Colors.amber;
        break;
      default:
        icon = Icons.notifications;
        color = Colors.orange;
    }

    return CircleAvatar(
      backgroundColor: color.withOpacity(0.12),
      child: Icon(icon, color: color, size: 20),
    );
  }
}

