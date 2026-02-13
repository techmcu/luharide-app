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

    // Debug: Print user info
    print('🔍 HomeScreen - User: ${user?.email}, Role: ${user?.role} (lowercase: $role)');

    // Admin/Union Admin gets dedicated admin panel (no search bar, driver verification only)
    if (role == 'union_admin' || role == 'admin') {
      print('✅ Showing Admin Panel');
      return const UnionAdminHomeScreen();
    }

    // BlaBlaCar style: unified home for passengers and drivers
    // Drivers see Create Ride; passengers see it too but gate at click
    print('👤 Showing Passenger/Driver Screen');
    return const PassengerHomeScreen();
  }
}
