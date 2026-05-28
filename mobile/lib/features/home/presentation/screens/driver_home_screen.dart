import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../providers/app_language_provider.dart';
import '../../../../providers/auth_provider.dart';
import '../../../../services/notification_service.dart';
import '../../../notifications/presentation/screens/notifications_screen.dart';
import '../../../trips/presentation/screens/create_trip_screen.dart';
import '../../../trips/presentation/screens/my_rides_screen.dart';
import '../../../profile/presentation/screens/profile_screen.dart';
import '../../../../widgets/brand_app_bar_title.dart';

class DriverHomeScreen extends StatefulWidget {
  const DriverHomeScreen({super.key});

  @override
  State<DriverHomeScreen> createState() => _DriverHomeScreenState();
}

class _DriverHomeScreenState extends State<DriverHomeScreen> {
  final _notificationService = NotificationService();
  int _unreadNotificationCount = 0;
  bool _isNavigating = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadUnreadNotifications());
  }

  Future<void> _loadUnreadNotifications() async {
    final result = await _notificationService.getNotifications();
    if (!result['success'] || !mounted) return;
    final list = result['notifications'] as List? ?? [];
    final unread = list.where((n) =>
        n is Map && (n['is_read'] != true)).length;
    if (!mounted) return;
    setState(() {
      _unreadNotificationCount = unread;
    });
  }

  @override
  Widget build(BuildContext context) {
    context.watch<AppLanguageProvider>();
    final loc = AppLocalizations.of(context);
    final authProvider = context.watch<AuthProvider>();
    final user = authProvider.user;
    final helloName = () {
      final first = user?.name.split(' ').first;
      if (first != null && first.isNotEmpty) return first;
      return user?.role == 'driver'
          ? loc.t('driver.home.fallback_driver')
          : loc.t('driver.home.fallback_passenger');
    }();

    return Scaffold(
      appBar: AppBar(
        centerTitle: false,
        title: BrandAppBarTitle(title: Text(loc.t('driver.home.title'))),
        actions: [
          IconButton(
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(Icons.notifications_outlined),
                if (_unreadNotificationCount > 0)
                  Positioned(
                    right: -2,
                    top: -2,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 14,
                        minHeight: 14,
                      ),
                      child: Text(
                        _unreadNotificationCount > 9
                            ? '9+'
                            : '$_unreadNotificationCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
            onPressed: _isNavigating ? null : () async {
              setState(() => _isNavigating = true);
              try {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const NotificationsScreen(),
                  ),
                );
                if (!mounted) return;
                _loadUnreadNotifications();
              } finally {
                if (mounted) setState(() => _isNavigating = false);
              }
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Driver Header - professional, compact
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.green[700]!, Colors.green[600]!],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: Colors.white,
                    child: Text(
                      (user != null && user.name.isNotEmpty ? user.name.substring(0, 1).toUpperCase() : 'D'),
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.green[700],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          loc.tReplace('driver.home.hello', {'name': helloName}),
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                            letterSpacing: 0.2,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Icon(Icons.star_outline, color: Colors.white.withValues(alpha: 0.9), size: 12),
                            const SizedBox(width: 4),
                            Text(
                              loc.t('driver.home.get_rated'),
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.95),
                                fontSize: 11,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              width: 5,
                              height: 5,
                              decoration: const BoxDecoration(
                                color: Colors.white70,
                                shape: BoxShape.circle,
                              ),
                            ),
                              const SizedBox(width: 6),
                            Text(
                              loc.t('driver.home.online'),
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.9),
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      loc.t('driver.home.online'),
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 10),
                    ),
                  ),
                ],
              ),
            ),

            // Create Trip - centered, prominent
            Padding(
              padding: const EdgeInsets.all(20),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 320),
                  child: SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton.icon(
                      onPressed: _isNavigating ? null : () async {
                        setState(() => _isNavigating = true);
                        try {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const CreateTripScreen(),
                            ),
                          );
                        } finally {
                          if (mounted) setState(() => _isNavigating = false);
                        }
                      },
                      icon: const Icon(Icons.add_road, size: 26),
                      label: Text(
                        loc.t('driver.home.create_trip'),
                        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green[700],
                        foregroundColor: Colors.white,
                        elevation: 4,
                        shadowColor: Colors.green.withValues(alpha: 0.4),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // My Rides button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 320),
                  child: SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const MyRidesScreen(),
                          ),
                        );
                      },
                      icon: const Icon(Icons.list_alt, size: 20),
                      label: Text(loc.t('my_rides.title')),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.green[700],
                        side: BorderSide(color: Colors.green[400]!),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(height: 24 + MediaQuery.viewPaddingOf(context).bottom),
          ],
        ),
      ),
      bottomNavigationBar: _buildFooter(context, loc),
    );
  }

  Widget _buildFooter(BuildContext context, AppLocalizations loc) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: _buildFooterItem(
                context,
                icon: Icons.route,
                label: loc.t('my_rides.title'),
                iconColor: Colors.green[700]!,
                bgColor: Colors.green[50]!,
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MyRidesScreen())),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildFooterItem(
                context,
                icon: Icons.add_road,
                label: loc.t('driver.footer.create'),
                iconColor: Colors.orange[700]!,
                bgColor: Colors.orange[50]!,
                isHighlight: true,
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateTripScreen())),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildFooterItem(
                context,
                icon: Icons.person,
                label: loc.t('driver.footer.profile'),
                iconColor: Colors.green[700]!,
                bgColor: Colors.green[50]!,
                isHighlight: true,
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProfileScreen(userRole: 'driver'))),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFooterItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color iconColor,
    required Color bgColor,
    required VoidCallback onTap,
    bool isHighlight = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isHighlight ? bgColor : null,
          border: Border.all(color: Colors.grey[300]!),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 20, color: iconColor),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
