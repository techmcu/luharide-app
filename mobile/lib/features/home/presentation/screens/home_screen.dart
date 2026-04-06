import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../providers/auth_provider.dart';
import 'passenger_home_screen.dart';
import 'role_home_shell.dart';
import 'union_admin_home_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final user = authProvider.user;
    final role = (user?.role ?? 'passenger').toString().toLowerCase();
    final isAppAdmin = user?.isAppAdmin ?? false;

    if (kDebugMode) {
      // ignore: avoid_print
      print('🔍 HomeScreen - User: ${user?.email}, Role: $role, isAppAdmin: $isAppAdmin');
    }

    // Union head (not platform admin): find rides + union dashboard only — no global KYC mixed in.
    if (role == 'union_admin' && !isAppAdmin) {
      return const RoleHomeShell(
        mode: RoleHomeShellMode.unionAdmin,
        showApprovalsTab: false,
      );
    }

    // Platform admin (ADMIN_EMAIL): moderation-only home — no passenger search / union ops / driver hub here.
    // Avoids showing the same shell as union leaders (no "Driver" tab or independent-driver UI for this account).
    if (role == 'union_admin' && isAppAdmin) {
      return const UnionAdminHomeScreen();
    }

    // Independent driver: find rides + driver hub; rare: same user is app admin → Approvals tab added.
    if (role == 'driver') {
      return RoleHomeShell(
        mode: RoleHomeShellMode.driver,
        showApprovalsTab: isAppAdmin,
      );
    }

    return const PassengerHomeScreen();
  }
}
