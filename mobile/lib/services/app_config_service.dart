import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'api_service.dart';

class AppConfigResult {
  final bool forceUpdate;
  final String minVersion;

  const AppConfigResult({
    this.forceUpdate = false,
    this.minVersion = '',
  });
}

class AppConfigService {
  AppConfigService._();
  static final AppConfigService instance = AppConfigService._();

  Future<AppConfigResult> check() async {
    try {
      final res = await ApiService().get('/app-config');
      final data = res.data;
      if (data is! Map) return const AppConfigResult();

      final config = (data['data'] ?? data) as Map? ?? {};
      final minVersion = config['force_update_min_version']?.toString() ?? '';

      bool needsUpdate = false;
      if (minVersion.isNotEmpty) {
        try {
          final info = await PackageInfo.fromPlatform();
          needsUpdate = _isVersionLower(info.version, minVersion);
        } catch (_) {}
      }

      return AppConfigResult(
        forceUpdate: needsUpdate,
        minVersion: minVersion,
      );
    } catch (e) {
      debugPrint('AppConfigService check failed: $e');
      return const AppConfigResult();
    }
  }

  bool _isVersionLower(String current, String minimum) {
    final cur = current.split('.').map((s) => int.tryParse(s) ?? 0).toList();
    final min = minimum.split('.').map((s) => int.tryParse(s) ?? 0).toList();
    while (cur.length < 3) { cur.add(0); }
    while (min.length < 3) { min.add(0); }
    for (int i = 0; i < 3; i++) {
      if (cur[i] < min[i]) return true;
      if (cur[i] > min[i]) return false;
    }
    return false;
  }
}
