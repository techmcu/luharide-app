import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
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

    if (kDebugMode) {
      // ignore: avoid_print
      print('🔍 HomeScreen - User: ${user?.email}, Role: $role');
    }

    if (role == 'union_admin' || role == 'admin') {
      return const UnionAdminHomeScreen();
    }

    return const PassengerHomeScreen();
  }
}
