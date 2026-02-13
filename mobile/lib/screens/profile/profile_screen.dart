import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../core/app_navigator.dart';
import '../trips/passenger_my_rides_screen.dart';
import '../trips/my_rides_screen.dart';
import '../trips/create_trip_screen.dart';
import 'edit_profile_screen.dart';
import 'ratings_screen.dart';
import 'driver_verification_form_screen.dart';
import 'change_password_screen.dart';
import 'help_screen.dart';
import 'terms_screen.dart';

/// User Profile - BlaBlaCar style, simple & easy
class ProfileScreen extends StatelessWidget {
  final String? userRole;

  const ProfileScreen({super.key, this.userRole});

  ImageProvider? _buildProfileImage(user, bool isDriver) {
    final String? url = user?.profileImage;
    if (url == null || url.isEmpty) return null;
    if (url.startsWith('data:image')) {
      try {
        final base64Str = url.substring(url.indexOf(',') + 1);
        final Uint8List bytes = base64Decode(base64Str);
        return MemoryImage(bytes);
      } catch (_) {
        return null;
      }
    }
    return NetworkImage(url);
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final user = authProvider.user;
    final role = userRole ?? user?.role ?? 'passenger';
    final isDriver = role == 'driver' || user?.isDriverVerified == true;
    final driverStatus = user?.driverVerificationStatus ?? 'none';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        backgroundColor: isDriver ? Colors.green : Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Profile header - name, rating, email
          Center(
            child: Column(
              children: [
                CircleAvatar(
                  radius: 36,
                  backgroundColor: isDriver ? Colors.green[100] : Colors.blue[100],
                  backgroundImage: _buildProfileImage(user, isDriver),
                  child: (user?.profileImage == null || (user!.profileImage?.isEmpty ?? true))
                      ? Text(
                          (user?.name ?? 'U')[0].toUpperCase(),
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: isDriver ? Colors.green[800] : Colors.blue[800],
                          ),
                        )
                      : null,
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Hello, ${user?.name?.split(' ').first ?? "User"}!',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (user?.isDriverVerified == true) ...[
                      const SizedBox(width: 6),
                      Icon(Icons.verified, color: Colors.blue[700], size: 20),
                    ],
                  ],
                ),
                const SizedBox(height: 8),
                // Rating - TODO: Real rating after ride complete. Pending: email 5 min after ride.
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.star_outline, color: Colors.grey[600], size: 18),
                      const SizedBox(width: 6),
                      Text(
                        'No ratings yet',
                        style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  user?.email ?? '',
                  style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Share your ride - compact button
          _buildShareRideButton(context, authProvider),

          const SizedBox(height: 24),

          // Become a Driver (only if not yet approved)
          if (driverStatus != 'approved')
            _buildMenuItem(
              context,
              icon: Icons.drive_eta,
              title: driverStatus == 'pending' ? 'Driver Verification Pending' : 'Become a Driver',
              subtitle: driverStatus == 'pending'
                  ? 'Admin is reviewing your documents'
                  : 'Submit documents to create rides',
              onTap: driverStatus == 'pending'
                  ? null
                  : () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const DriverVerificationFormScreen()),
                      ).then((_) => authProvider.refreshUser());
                    },
            ),
          _buildMenuItem(
            context,
            icon: Icons.person_outline,
            title: 'Edit Profile',
            subtitle: 'Name, email, profile pic',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const EditProfileScreen()),
              );
            },
          ),
          _buildMenuItem(
            context,
            icon: Icons.confirmation_number_outlined,
            title: isDriver ? 'My Rides' : 'My Bookings',
            subtitle: isDriver ? 'Rides you created' : 'Rides you booked',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => isDriver
                      ? const MyRidesScreen()
                      : const PassengerMyRidesScreen(),
                ),
              );
            },
          ),
          _buildMenuItem(
            context,
            icon: Icons.star_outline,
            title: 'My Ratings',
            subtitle: 'See all ratings from users',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => RatingsScreen(userRole: role),
                ),
              );
            },
          ),
          _buildMenuItem(
            context,
            icon: Icons.lock_outline,
            title: 'Change Password',
            subtitle: 'Update your password',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ChangePasswordScreen()),
              );
            },
          ),
          _buildMenuItem(
            context,
            icon: Icons.help_outline,
            title: 'Help',
            subtitle: 'FAQs, contact',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const HelpScreen()),
              );
            },
          ),
          _buildMenuItem(
            context,
            icon: Icons.description_outlined,
            title: 'Terms & Conditions',
            subtitle: 'Please read carefully',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const TermsScreen()),
              );
            },
          ),
          const SizedBox(height: 24),
          _buildMenuItem(
            context,
            icon: Icons.logout,
            title: 'Logout',
            subtitle: 'Sign out',
            color: Colors.red,
            onTap: () => _showLogoutDialog(context, authProvider),
          ),
        ],
      ),
    );
  }

  void _onShareRideTap(BuildContext context, AuthProvider authProvider) {
    final user = authProvider.user;
    final status = user?.driverVerificationStatus ?? 'none';
    if (status == 'approved') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const CreateTripScreen()),
      ).then((_) => authProvider.refreshUser());
    } else if (status == 'pending') {
      _showVerifyDialog(context, authProvider, 'Your driver verification is pending. Admin will review shortly.');
    } else {
      _showVerifyDialog(context, authProvider, 'Please verify your documents first to create rides.');
    }
  }

  void _showVerifyDialog(BuildContext context, AuthProvider authProvider, String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.verified_user_outlined, color: Colors.orange[700], size: 28),
            const SizedBox(width: 10),
            const Text('Verify First', style: TextStyle(fontSize: 18)),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const DriverVerificationFormScreen()),
              ).then((_) => authProvider.refreshUser());
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
            child: const Text('Verify Documents'),
          ),
        ],
      ),
    );
  }

  Widget _buildShareRideButton(BuildContext context, AuthProvider authProvider) {
    final user = authProvider.user;
    final status = user?.driverVerificationStatus ?? 'none';
    return InkWell(
      onTap: () => _onShareRideTap(context, authProvider),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.green[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.green[200]!),
        ),
        child: Row(
          children: [
            Icon(Icons.add_road, color: Colors.green[700], size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Share your ride', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.green[800])),
                  Text(
                    status == 'approved' ? 'Create a new trip' : (status == 'pending' ? 'Verification pending' : 'Verify to create rides'),
                    style: TextStyle(fontSize: 12, color: Colors.green[700]),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.green[700], size: 22),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    VoidCallback? onTap,
    Color? color,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey[200]!),
      ),
      child: ListTile(
        leading: Icon(icon, color: color ?? Colors.grey[700]),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
        trailing: onTap != null ? const Icon(Icons.chevron_right, color: Colors.grey) : null,
        onTap: onTap,
      ),
    );
  }

  void _showLogoutDialog(BuildContext context, AuthProvider authProvider) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Do you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              // Pop all routes to root so Consumer can show WelcomeScreen
              navigatorKey.currentState?.popUntil((route) => route.isFirst);
              await authProvider.logout();
            },
            child: const Text('Logout', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
