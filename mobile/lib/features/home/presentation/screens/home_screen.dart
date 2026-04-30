import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../providers/auth_provider.dart';
import '../../../../widgets/exit_guard.dart';
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

    Widget child;

    if (role == 'union_admin' && !isAppAdmin) {
      child = const RoleHomeShell(
        mode: RoleHomeShellMode.unionAdmin,
        showApprovalsTab: false,
      );
    } else if (role == 'union_admin' && isAppAdmin) {
      child = const UnionAdminHomeScreen();
    } else if (role == 'driver') {
      child = RoleHomeShell(
        mode: RoleHomeShellMode.driver,
        showApprovalsTab: isAppAdmin,
      );
    } else {
      child = const PassengerHomeScreen();
    }

    return ExitGuard(child: child);
  }
}
