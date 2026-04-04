import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/localization/app_localizations.dart';
import '../../providers/app_language_provider.dart';
import '../../providers/auth_provider.dart';
import '../profile/union_dashboard_screen.dart';
import 'driver_home_screen.dart';
import 'passenger_home_screen.dart';
import 'union_admin_home_screen.dart';

/// Union admins and independent drivers both need the **passenger find-rides** home,
/// plus their operator dashboard. Tab 0 = same [PassengerHomeScreen] as plain passengers.
enum RoleHomeShellMode { unionAdmin, driver }

class RoleHomeShell extends StatefulWidget {
  const RoleHomeShell({
    super.key,
    required this.mode,
    this.showApprovalsTab = false,
  });

  final RoleHomeShellMode mode;

  /// Global app admin (`isAppAdmin`): third tab opens [UnionAdminHomeScreen] (driver + union KYC).
  final bool showApprovalsTab;

  @override
  State<RoleHomeShell> createState() => _RoleHomeShellState();
}

class _RoleHomeShellState extends State<RoleHomeShell> {
  int _tabIndex = 0;

  @override
  void didUpdateWidget(RoleHomeShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.showApprovalsTab && !widget.showApprovalsTab && _tabIndex == 2) {
      _tabIndex = 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    context.watch<AppLanguageProvider>();
    context.watch<AuthProvider>();
    final loc = AppLocalizations.of(context);
    final isUnion = widget.mode == RoleHomeShellMode.unionAdmin;
    final showAppr = widget.showApprovalsTab;
    final maxIx = showAppr ? 2 : 1;
    final idx = _tabIndex.clamp(0, maxIx);

    final segments = <ButtonSegment<int>>[
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
    ];
    if (showAppr) {
      segments.add(
        ButtonSegment<int>(
          value: 2,
          label: Text(loc.t('home.shell.tab.approvals'), style: const TextStyle(fontSize: 11)),
          icon: const Icon(Icons.fact_check_outlined, size: 17),
        ),
      );
    }

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
                segments: segments,
                selected: {idx},
                onSelectionChanged: (s) {
                  setState(() => _tabIndex = s.first);
                },
              ),
            ),
            Expanded(
              child: IndexedStack(
                index: idx,
                children: [
                  const PassengerHomeScreen(),
                  isUnion ? const UnionDashboardScreen() : const DriverHomeScreen(),
                  if (showAppr) const UnionAdminHomeScreen(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
