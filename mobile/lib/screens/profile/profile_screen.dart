import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';
import '../../providers/auth_provider.dart';
import '../../providers/app_language_provider.dart';
import '../../core/app_navigator.dart';
import '../../core/localization/app_localizations.dart';
import '../landing/landing_screen.dart';
import '../trips/passenger_my_rides_screen.dart';
import '../trips/my_rides_screen.dart';
import '../trips/create_trip_screen.dart';
import 'edit_profile_screen.dart';
import 'ratings_screen.dart';
import 'driver_verification_form_screen.dart';
import 'change_password_screen.dart';
import 'help_screen.dart';
import 'terms_screen.dart';
import 'union_registration_screen.dart';
import 'union_dashboard_screen.dart';
import '../../services/union_service.dart';
import '../../services/review_service.dart';
import '../../core/role_exclusivity.dart';

/// User Profile - BlaBlaCar style, simple & easy
class ProfileScreen extends StatefulWidget {
  final String? userRole;

  const ProfileScreen({super.key, this.userRole});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String _unionStatus = 'none'; // none | pending | approved | rejected
  bool _unionStatusLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadUnionStatus();
  }

  Future<void> _loadUnionStatus() async {
    try {
      final r = await UnionService().getMyUnion();
      if (!mounted) return;
      final st = (r['status'] ?? 'none').toString();
      setState(() {
        _unionStatus = st;
        _unionStatusLoaded = true;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _unionStatus = 'none';
          _unionStatusLoaded = true;
        });
      }
    }
  }

  bool _blocksIndependent(AuthProvider auth) {
    final u = auth.user;
    if (u == null) return false;
    return RoleExclusivity.blocksIndependentDriver(
      user: u,
      unionStatusFromApi: _unionStatusLoaded ? _unionStatus : null,
    );
  }

  bool _blocksUnion(AuthProvider auth) {
    return RoleExclusivity.blocksUnionRegistration(auth.user);
  }

  void _showExclusivityDialog(BuildContext context, {required String titleKey, required String bodyKey}) {
    final loc = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(loc.t(titleKey)),
        content: Text(loc.t(bodyKey)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(loc.t('app.ok'))),
        ],
      ),
    );
  }

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
    context.watch<AppLanguageProvider>();
    final authProvider = context.watch<AuthProvider>();
    final user = authProvider.user;
    final role = widget.userRole ?? user?.role ?? 'passenger';
    final isDriver = role == 'driver' || user?.isDriverVerified == true;
    final driverStatus = user?.driverVerificationStatus ?? 'none';
    final driverCode = user?.driverCode;
    final isUnionAdmin = user?.role == 'union_admin';

    final loc = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(loc.t('app.profile.title')),
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
                InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => RatingsScreen(userRole: role),
                      ),
                    );
                  },
                  borderRadius: BorderRadius.circular(20),
                  child: _RatingSummaryChip(userId: user?.id),
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

          // Driver code (only when fully approved)
          if (user?.isDriverVerified == true && driverCode != null && driverCode.isNotEmpty) ...[
            Card(
              color: Colors.green[50],
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Your driver code',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        SelectableText(
                          driverCode,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 2,
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          tooltip: 'Copy',
                          icon: const Icon(Icons.copy, size: 20),
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: driverCode));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Driver code copied')),
                            );
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Give this code to your union to get added as a driver.',
                      style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Share your ride — hidden if union path is active
          if (!_blocksIndependent(authProvider))
            _buildShareRideButton(context, authProvider)
          else
            _buildExclusivePathNote(
              context,
              loc.t('exclusivity.driver_blocked.body'),
            ),

          const SizedBox(height: 28),

          // ── Section: Taxi union (so union admins see their option first) ──
          _sectionLabel(loc.t('profile.section.union')),
          const SizedBox(height: 8),
          if (isUnionAdmin)
            _buildMenuItem(
              context,
              icon: Icons.business_rounded,
              title: 'Union hub',
              subtitle: 'Schedules, drivers, posters',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const UnionDashboardScreen()),
                );
              },
            )
          else if (_blocksUnion(authProvider))
            _buildMenuItem(
              context,
              icon: Icons.business_rounded,
              title: 'Add your union',
              subtitle: loc.t('exclusivity.union_blocked.body'),
              onTap: () => _showExclusivityDialog(
                context,
                titleKey: 'exclusivity.union_blocked.title',
                bodyKey: 'exclusivity.union_blocked.body',
              ),
            )
          else
            _buildMenuItem(
              context,
              icon: Icons.business_rounded,
              title: 'Add your union',
              subtitle: 'List your union on LuhaRide',
              onTap: () => _openUnionSection(context, authProvider),
            ),
          const SizedBox(height: 28),

          // ── Section: Your trips (bookings & ratings – for passengers) ──
          _sectionLabel('Your trips (passenger)'),
          const SizedBox(height: 8),
          _buildMenuItem(
            context,
            icon: Icons.confirmation_number_outlined,
            title: 'My bookings',
            subtitle: 'Trips I booked',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const PassengerMyRidesScreen(),
                ),
              );
            },
          ),
          _buildMenuItem(
            context,
            icon: Icons.star_outline,
            title: 'Ratings',
            subtitle: 'What passengers said',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => RatingsScreen(userRole: role),
                ),
              );
            },
          ),
          const SizedBox(height: 28),

          // ── Section: Independent taxi driver (create & manage rides) ──
          _sectionLabel(loc.t('profile.section.driver')),
          const SizedBox(height: 8),
          if (_blocksIndependent(authProvider)) ...[
            _buildMenuItem(
              context,
              icon: Icons.info_outline,
              title: loc.t('exclusivity.driver_blocked.title'),
              subtitle: loc.t('exclusivity.driver_blocked.body'),
              onTap: () => _showExclusivityDialog(
                context,
                titleKey: 'exclusivity.driver_blocked.title',
                bodyKey: 'exclusivity.driver_blocked.body',
              ),
            ),
          ] else if (driverStatus == 'approved') ...[
            _buildMenuItem(
              context,
              icon: Icons.add_road_rounded,
              title: 'Create ride',
              subtitle: 'Post a taxi ride for passengers',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const CreateTripScreen()),
                );
              },
            ),
            _buildMenuItem(
              context,
              icon: Icons.route,
              title: 'My rides',
              subtitle: 'Rides I created as driver',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const MyRidesScreen()),
                );
              },
            ),
          ] else ...[
            _buildMenuItem(
              context,
              icon: driverStatus == 'rejected' ? Icons.error_outline : Icons.drive_eta,
              title: driverStatus == 'pending'
                  ? 'Verification pending'
                  : driverStatus == 'rejected'
                      ? 'Verification rejected'
                      : 'Drive with LuhaRide',
              subtitle: driverStatus == 'pending'
                  ? 'Admin is reviewing your documents'
                  : driverStatus == 'rejected'
                      ? 'Documents were rejected. Update details and submit again.'
                      : 'Get verified to create rides',
              onTap: driverStatus == 'pending'
                  ? null
                  : () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const DriverVerificationFormScreen()),
                      ).then((_) {
                        authProvider.refreshUser();
                        _loadUnionStatus();
                      });
                    },
            ),
          ],
          const SizedBox(height: 24),

          // ── Section: Account ──
          _sectionLabel('Account'),
          const SizedBox(height: 8),
          _buildMenuItem(
            context,
            icon: Icons.person_outline,
            title: 'Edit profile',
            subtitle: 'Name, email, photo',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const EditProfileScreen()),
              );
            },
          ),
          _buildMenuItem(
            context,
            icon: Icons.lock_outline,
            title: 'Change password',
            subtitle: 'Update password',
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
            subtitle: 'FAQs and contact',
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
            title: 'Terms',
            subtitle: 'Terms of use',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const TermsScreen()),
              );
            },
          ),
          const SizedBox(height: 24),

          _sectionLabel(loc.t('app.menu.language')),
          const SizedBox(height: 8),
          _buildMenuItem(
            context,
            icon: Icons.language,
            title: loc.t('app.menu.language'),
            subtitle: loc.t('app.menu.language.subtitle'),
            onTap: () => _openLanguageSheet(context),
          ),
          const SizedBox(height: 24),

          _buildMenuItem(
            context,
            icon: Icons.logout,
            title: loc.t('profile.logout'),
            subtitle: loc.t('profile.logout.subtitle'),
            color: Colors.red,
            onTap: () => _showLogoutDialog(context, authProvider),
          ),
        ],
      ),
    );
  }

  Widget _buildExclusivePathNote(BuildContext context, String message) {
    return Card(
      margin: EdgeInsets.zero,
      color: Colors.blueGrey[50],
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.blueGrey[200]!),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.info_outline, color: Colors.blueGrey[700], size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: TextStyle(fontSize: 13, color: Colors.blueGrey[900], height: 1.35),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: Colors.grey[600],
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  void _onShareRideTap(BuildContext context, AuthProvider authProvider) {
    if (_blocksIndependent(authProvider)) {
      _showExclusivityDialog(
        context,
        titleKey: 'exclusivity.driver_blocked.title',
        bodyKey: 'exclusivity.driver_blocked.body',
      );
      return;
    }
    final user = authProvider.user;
    final status = user?.driverVerificationStatus ?? 'none';
    final hasPhone = (user?.phone ?? '').trim().isNotEmpty;
    final hasEmail = (user?.email ?? '').trim().isNotEmpty;
    final hasProfilePic = (user?.profileImage ?? '').trim().isNotEmpty;

    if (!hasPhone || !hasEmail || !hasProfilePic) {
      _showProfilePrereqDialog(
        context,
        title: 'Complete profile first',
        message:
            'Independent driver verification is only for real taxi owners.\n\n'
            'Please add your profile photo, email address and make sure your phone number is correct before submitting documents. '
            'Fake / misuse submissions may lead to your account being blocked.',
      );
      return;
    }
    if (status == 'approved') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const CreateTripScreen()),
      ).then((_) => authProvider.refreshUser());
    } else if (status == 'pending') {
      _showVerifyDialog(
        context,
        authProvider,
        'Your driver verification is pending. Admin usually reviews within 24–48 hours.\n\n'
        'Agar isse zyada delay ho jaye, to aap supportluharide@gmail.com par politely email karke '
        'apni request ka status pooch sakte hain (subject mein apna naam aur phone number likh kar).',
      );
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

  void _openLanguageSheet(BuildContext context) {
    final langProvider = context.read<AppLanguageProvider>();
    final loc = AppLocalizations.of(context);
    final current = langProvider.language;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 12),
              ListTile(
                title: Text(loc.t('app.language.english')),
                leading: Radio<AppLanguageCode>(
                  value: AppLanguageCode.en,
                  groupValue: current,
                  onChanged: (v) async {
                    if (v == null) return;
                    await langProvider.setLanguage(v);
                    if (context.mounted) {
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(loc.t('app.language.saved'))),
                      );
                    }
                  },
                ),
                onTap: () async {
                  await langProvider.setLanguage(AppLanguageCode.en);
                  if (context.mounted) {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(loc.t('app.language.saved'))),
                    );
                  }
                },
              ),
              ListTile(
                title: Text(loc.t('app.language.hindi')),
                leading: Radio<AppLanguageCode>(
                  value: AppLanguageCode.hi,
                  groupValue: current,
                  onChanged: (v) async {
                    if (v == null) return;
                    await langProvider.setLanguage(v);
                    if (context.mounted) {
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(loc.t('app.language.saved'))),
                      );
                    }
                  },
                ),
                onTap: () async {
                  await langProvider.setLanguage(AppLanguageCode.hi);
                  if (context.mounted) {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(loc.t('app.language.saved'))),
                    );
                  }
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  void _showProfilePrereqDialog(
    BuildContext context, {
    required String title,
    required String message,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.info_outline, color: Colors.orange[700], size: 26),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        content: Text(
          message,
          style: const TextStyle(fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const EditProfileScreen()),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            ),
            child: const Text('Complete profile'),
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
                  Text('Create a ride', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.green[800])),
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

  /// Called when user taps "Add your union".
  /// Does a single server check — if already approved, refresh auth + open dashboard.
  /// No polling: one call only.
  /// Always opens the union registration form (or dashboard if already approved).
  /// Profile completeness is shown *inside* the form — we no longer block here with a dialog
  /// that only offered "Complete profile" → users thought "Add union" opened Edit profile.
  Future<void> _openUnionSection(BuildContext context, AuthProvider authProvider) async {
    if (_blocksUnion(authProvider)) {
      _showExclusivityDialog(
        context,
        titleKey: 'exclusivity.union_blocked.title',
        bodyKey: 'exclusivity.union_blocked.body',
      );
      return;
    }
    // Show brief loading indicator
    final snack = ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
            SizedBox(width: 12),
            Text('Checking union status…'),
          ],
        ),
        duration: Duration(seconds: 5),
      ),
    );

    try {
      final result = await UnionService().getMyUnion();
      if (!context.mounted) return;
      snack.close();

      final status = (result['status'] ?? 'none').toString();

      if (status == 'approved') {
        // Refresh local user model so role = union_admin everywhere
        await authProvider.refreshUser();
        if (!context.mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const UnionDashboardScreen()),
        );
      } else {
        // Not yet approved — open registration/status screen
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const UnionRegistrationScreen()),
        );
      }
    } catch (_) {
      if (!context.mounted) return;
      snack.close();
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const UnionRegistrationScreen()),
      );
    }
  }

  void _showLogoutDialog(BuildContext context, AuthProvider authProvider) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Do you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              // Close dialog first
              Navigator.pop(dialogCtx);
              
              // Logout immediately - clear auth state
              await authProvider.logout();
              
              // Force navigation to root - clear entire stack
              if (navigatorKey.currentState != null) {
                navigatorKey.currentState!.pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const LandingScreen()),
                  (route) => false, // Remove all previous routes
                );
              }
            },
            child: const Text('Logout', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

class _RatingSummaryChip extends StatelessWidget {
  final String? userId;

  const _RatingSummaryChip({this.userId});

  @override
  Widget build(BuildContext context) {
    if (userId == null || userId!.isEmpty) {
      return _chip(icon: Icons.star_outline, label: 'No ratings yet');
    }
    return FutureBuilder<Map<String, dynamic>>(
      future: ReviewService().getUserRatingSummary(userId!),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return _chip(icon: Icons.star_outline, label: '…');
        }
        final d = snapshot.data!;
        final total = (d['total_ratings'] as num?)?.toInt() ?? 0;
        final avg = (d['average_rating'] as num?)?.toDouble();
        if (total == 0) {
          return _chip(icon: Icons.star_outline, label: 'No ratings yet');
        }
        final avgStr = avg != null ? avg.toStringAsFixed(1) : '0';
        return _chip(icon: Icons.star, label: '$avgStr ★ ($total reviews)');
      },
    );
  }

  Widget _chip({required IconData icon, required String label}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.grey[600], size: 18),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(fontSize: 13, color: Colors.grey[600])),
        ],
      ),
    );
  }
}
