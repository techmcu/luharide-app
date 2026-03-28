import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
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
      print('🔍 HomeScreen - User: ${user?.email}, Role: $role');
    }

    // Global app admin: full verification / stats panel (API sets isAppAdmin / is_app_admin)
    if (isAppAdmin) {
      return const UnionAdminHomeScreen();
    }

    // Union admin: find rides (passenger UI) + union dashboard — same as passenger search flow
    if (role == 'union_admin') {
      return const RoleHomeShell(mode: RoleHomeShellMode.unionAdmin);
    }

    // Independent driver: find rides + driver hub (create trip, my rides, etc.)
    if (role == 'driver') {
      return const RoleHomeShell(mode: RoleHomeShellMode.driver);
    }

    return const PassengerHomeScreen();
  }
}
