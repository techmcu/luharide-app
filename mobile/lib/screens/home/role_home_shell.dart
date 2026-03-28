import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/localization/app_localizations.dart';
import '../../providers/app_language_provider.dart';
import '../profile/union_dashboard_screen.dart';
import 'driver_home_screen.dart';
import 'passenger_home_screen.dart';

/// Union admins and independent drivers both need the **passenger find-rides** home,
/// plus their operator dashboard. Tab 0 = same [PassengerHomeScreen] as plain passengers.
enum RoleHomeShellMode { unionAdmin, driver }

class RoleHomeShell extends StatefulWidget {
  const RoleHomeShell({super.key, required this.mode});

  final RoleHomeShellMode mode;

  @override
  State<RoleHomeShell> createState() => _RoleHomeShellState();
}

class _RoleHomeShellState extends State<RoleHomeShell> {
  int _tabIndex = 0;

  @override
  Widget build(BuildContext context) {
    context.watch<AppLanguageProvider>();
    final loc = AppLocalizations.of(context);
    final isUnion = widget.mode == RoleHomeShellMode.unionAdmin;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
              child: SegmentedButton<int>(
                showSelectedIcon: false,
                segments: [
                  ButtonSegment<int>(
                    value: 0,
                    label: Text(loc.t('home.shell.tab.find_rides'), style: const TextStyle(fontSize: 12)),
                    icon: const Icon(Icons.search_rounded, size: 18),
                  ),
                  ButtonSegment<int>(
                    value: 1,
                    label: Text(
                      isUnion ? loc.t('home.shell.tab.union') : loc.t('home.shell.tab.driver'),
                      style: const TextStyle(fontSize: 12),
                    ),
                    icon: Icon(
                      isUnion ? Icons.groups_rounded : Icons.local_taxi_rounded,
                      size: 18,
                    ),
                  ),
                ],
                selected: {_tabIndex},
                onSelectionChanged: (s) {
                  setState(() => _tabIndex = s.first);
                },
              ),
            ),
            Expanded(
              child: IndexedStack(
                index: _tabIndex,
                children: [
                  const PassengerHomeScreen(),
                  isUnion ? const UnionDashboardScreen() : const DriverHomeScreen(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
