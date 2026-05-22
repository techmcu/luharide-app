import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../providers/auth_provider.dart';
import '../../../../services/app_config_service.dart';
import '../../../../services/push_notification_service.dart';
import '../../../../services/realtime_socket_service.dart';

class MaintenanceScreen extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  final bool checking;

  const MaintenanceScreen({
    super.key,
    required this.message,
    required this.onRetry,
    this.checking = false,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.build_rounded,
                    size: 56,
                    color: Colors.orange.shade600,
                  ),
                ),
                const SizedBox(height: 32),
                Text(
                  'Under Maintenance',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: Colors.grey.shade900,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  message.isNotEmpty
                      ? message
                      : 'We are currently performing scheduled maintenance. Service will resume shortly. We apologise for the inconvenience.',
                  style: TextStyle(
                    fontSize: 15,
                    color: Colors.grey.shade600,
                    height: 1.6,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 40),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: FilledButton.icon(
                    onPressed: checking ? null : onRetry,
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.orange.shade600,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: checking
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.refresh_rounded),
                    label: Text(checking ? 'Checking...' : 'Try Again'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class ForceUpdateScreen extends StatelessWidget {
  final String minVersion;

  const ForceUpdateScreen({super.key, required this.minVersion});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.system_update_rounded,
                    size: 56,
                    color: Colors.blue.shade600,
                  ),
                ),
                const SizedBox(height: 32),
                Text(
                  'Update Required',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: Colors.grey.shade900,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'A new version ($minVersion) is available.\nPlease update to continue using LuhaRide.',
                  style: TextStyle(
                    fontSize: 15,
                    color: Colors.grey.shade600,
                    height: 1.6,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 40),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: FilledButton.icon(
                    onPressed: () {
                      launchUrl(
                        Uri.parse(
                          'https://play.google.com/store/apps/details?id=cloud.luharide.app',
                        ),
                        mode: LaunchMode.externalApplication,
                      );
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.blue.shade600,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.download_rounded),
                    label: const Text('Update Now'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class AppGate extends StatefulWidget {
  final Widget child;

  const AppGate({super.key, required this.child});

  @override
  State<AppGate> createState() => _AppGateState();
}

class _AppGateState extends State<AppGate> with WidgetsBindingObserver {
  AppConfigResult? _config;
  bool _loading = true;
  bool _checking = false;
  Timer? _pollTimer;
  StreamSubscription<Map<String, dynamic>>? _maintenanceSub;
  StreamSubscription<RemoteMessage>? _fcmSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _check();
    _pollTimer = Timer.periodic(const Duration(seconds: 30), (_) => _silentCheck());
    _maintenanceSub = RealtimeSocketService.instance.maintenanceStream.listen(_onMaintenanceEvent);
    _fcmSub = PushNotificationService.instance.foregroundMessages.listen(_onFcmForeground);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _silentCheck();
  }

  void _onMaintenanceEvent(Map<String, dynamic> data) {
    if (!mounted) return;
    // Don't trust WebSocket data directly — re-check via API so the backend's
    // admin exemption logic runs (it returns maintenance_mode=false for admin).
    _silentCheck();
  }

  void _onFcmForeground(RemoteMessage message) {
    if (message.data['type'] == 'maintenance') _silentCheck();
  }

  Future<void> _check() async {
    setState(() => _loading = true);
    final result = await AppConfigService.instance.check();
    if (!mounted) return;
    setState(() {
      _config = result;
      _loading = false;
    });
  }

  Future<void> _retryCheck() async {
    setState(() => _checking = true);
    final result = await AppConfigService.instance.check();
    if (!mounted) return;
    setState(() {
      _config = result;
      _checking = false;
    });
  }

  Future<void> _silentCheck() async {
    final result = await AppConfigService.instance.check();
    if (!mounted) return;
    setState(() => _config = result);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pollTimer?.cancel();
    _maintenanceSub?.cancel();
    _fcmSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_config != null && _config!.forceUpdate) {
      return ForceUpdateScreen(minVersion: _config!.minVersion);
    }

    if (_config != null && _config!.maintenanceMode) {
      final auth = context.watch<AuthProvider>();
      if (auth.isAuthenticated && auth.user?.isAppAdmin != true) {
        return MaintenanceScreen(
          message: _config!.maintenanceMessage,
          onRetry: _retryCheck,
          checking: _checking,
        );
      }
    }

    return widget.child;
  }
}
