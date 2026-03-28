import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../profile/union_dashboard_screen.dart';
import 'passenger_home_screen.dart';
import 'driver_home_screen.dart';
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

    // Approved union operator: union dashboard as home (not passenger search UI)
    if (role == 'union_admin') {
      return const UnionDashboardScreen();
    }

    if (role == 'driver') {
      return const DriverHomeScreen();
    }

    return const PassengerHomeScreen();
  }
}
