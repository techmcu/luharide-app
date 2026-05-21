import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../services/app_config_service.dart';
import '../../../../services/realtime_socket_service.dart';

class MaintenanceScreen extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const MaintenanceScreen({super.key, required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.construction_rounded, size: 80, color: Colors.orange.shade400),
              const SizedBox(height: 24),
              const Text(
                'App Under Maintenance',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                message.isNotEmpty ? message : 'We are currently performing scheduled maintenance. Service will resume shortly. We apologise for the inconvenience.',
                style: const TextStyle(fontSize: 15, color: Colors.black54, height: 1.5),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
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
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.system_update_rounded, size: 80, color: Colors.blue.shade400),
              const SizedBox(height: 24),
              const Text(
                'Update Required',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'A new version ($minVersion) is available. Please update to continue using LuhaRide.',
                style: const TextStyle(fontSize: 15, color: Colors.black54, height: 1.5),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              FilledButton.icon(
                onPressed: () {
                  launchUrl(
                    Uri.parse('https://play.google.com/store/apps/details?id=cloud.luharide.app'),
                    mode: LaunchMode.externalApplication,
                  );
                },
                icon: const Icon(Icons.download),
                label: const Text('Update Now'),
              ),
            ],
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
  StreamSubscription<Map<String, dynamic>>? _maintenanceSub;
  StreamSubscription<Map<String, dynamic>>? _notifSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _check();
    _maintenanceSub = RealtimeSocketService.instance.maintenanceStream.listen(_onMaintenanceEvent);
    _notifSub = RealtimeSocketService.instance.notificationStream.listen(_onNotification);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _silentCheck();
    }
  }

  void _onMaintenanceEvent(Map<String, dynamic> data) {
    if (!mounted) return;
    final raw = data['maintenanceMode'];
    final mode = raw == true || raw == 'true';
    final message = data['message']?.toString() ?? '';
    setState(() {
      _config = AppConfigResult(
        maintenanceMode: mode,
        maintenanceMessage: message,
        forceUpdate: _config?.forceUpdate ?? false,
        minVersion: _config?.minVersion ?? '',
      );
    });
  }

  void _onNotification(Map<String, dynamic> data) {
    if (data['type'] == 'maintenance') _silentCheck();
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

  Future<void> _silentCheck() async {
    final result = await AppConfigService.instance.check();
    if (!mounted) return;
    setState(() => _config = result);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _maintenanceSub?.cancel();
    _notifSub?.cancel();
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
      return MaintenanceScreen(
        message: _config!.maintenanceMessage,
        onRetry: _check,
      );
    }

    return widget.child;
  }
}
