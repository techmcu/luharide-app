import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/feedback/app_feedback.dart';
import '../../../../models/notification_model.dart';
import '../../../../providers/app_language_provider.dart';
import '../../../../services/notification_service.dart';
import '../../../../widgets/rate_ride_dialog.dart';

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
    context.watch<AppLanguageProvider>();
    final loc = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(loc.t('notifications.title')),
        actions: [
          IconButton(
            icon: const Icon(Icons.done_all),
            tooltip: loc.t('notifications.mark_all_tooltip'),
            onPressed: () async {
              final ok = await _notificationService.markAllAsRead();
              if (!context.mounted) return;
              if (ok) {
                AppFeedback.show(
                  context,
                  loc.t('notifications.mark_all_read'),
                  kind: AppFeedbackKind.success,
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
                loc.t('notifications.load_failed'),
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
                        Text(loc.t('notifications.empty.title'),
                            style: TextStyle(fontSize: 16, color: Colors.grey[600])),
                        const SizedBox(height: 4),
                        Text(
                          loc.t('notifications.empty.subtitle'),
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
                return _buildNotificationTile(loc, n);
              },
            ),
          );
        },
      ),
    );
  }

  String _localizedTitle(AppLocalizations loc, NotificationModel n) {
    final key = 'notif.${n.type}.title';
    final localized = loc.t(key);
    return localized != key ? localized : n.title;
  }

  String _localizedBody(AppLocalizations loc, NotificationModel n) {
    final key = 'notif.${n.type}.body';
    final localized = loc.t(key);
    return localized != key ? localized : (n.message ?? '');
  }

  Widget _buildNotificationTile(AppLocalizations loc, NotificationModel n) {
    final subtitle = _localizedBody(loc, n);
    final created = n.createdAt;
    final timeText =
        created != null ? loc.notificationRelativeTime(created) : '';

    return Card(
      elevation: n.isRead ? 0 : 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: _leadingIconForType(n.type),
        title: Text(
          _localizedTitle(loc, n),
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
            if (!mounted) return;
            _refresh();
          }
          if (n.type == 'rate_ride' && n.bookingId != null && n.bookingId!.isNotEmpty) {
            if (!mounted) return;
            final data = n.data;
            final targetName = data?['target_name']?.toString();
            final rawSeats = data?['seat_numbers'];
            final seatNumbers = rawSeats is List
                ? rawSeats.map<int>((e) => (e is num) ? e.toInt() : int.tryParse(e.toString()) ?? 0).toList()
                : <int>[];
            final tripRoute = data?['trip_route']?.toString();
            final submitted = await showDialog<bool>(
              context: context,
              barrierDismissible: false,
              builder: (_) => RateRideDialog(
                bookingId: n.bookingId!,
                title: n.title,
                targetName: targetName,
                seatNumbers: seatNumbers.isNotEmpty ? seatNumbers : null,
                tripRoute: tripRoute,
              ),
            );
            if (submitted == true && mounted) _refresh();
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
      case 'trip_completed':
        icon = Icons.check_circle;
        color = Colors.green;
        break;
      case 'booking_status':
        icon = Icons.directions_car;
        color = Colors.blue;
        break;
      case 'rate_ride':
        icon = Icons.star;
        color = Colors.amber;
        break;
      case 'kyc_reverify_required':
        icon = Icons.assignment_late_outlined;
        color = Colors.deepPurple;
        break;
      case 'union_documents_approved':
        icon = Icons.verified_outlined;
        color = Colors.teal;
        break;
      default:
        icon = Icons.notifications;
        color = Colors.orange;
    }

    return CircleAvatar(
      backgroundColor: color.withValues(alpha: 0.12),
      child: Icon(icon, color: color, size: 20),
    );
  }
}

