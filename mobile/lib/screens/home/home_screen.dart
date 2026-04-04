import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import 'passenger_home_screen.dart';
import 'role_home_shell.dart';
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

    // Union admin: find rides + union dashboard; app admin also gets an "Approvals" tab (KYC panel)
    if (role == 'union_admin') {
      return RoleHomeShell(
        mode: RoleHomeShellMode.unionAdmin,
        showApprovalsTab: isAppAdmin,
      );
    }

    // Independent driver: find rides + driver hub (create trip, my rides, etc.)
    if (role == 'driver') {
      return RoleHomeShell(
        mode: RoleHomeShellMode.driver,
        showApprovalsTab: isAppAdmin,
      );
    }

    return const PassengerHomeScreen();
  }
}
