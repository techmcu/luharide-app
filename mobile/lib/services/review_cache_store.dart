import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// On-device cache for review bundles (latest window per user). Full history stays on server.
class ReviewCacheStore {
  ReviewCacheStore._();

  static const _bundlePrefix = 'lr_bundle_v1_';
  static const _fpPrefix = 'lr_summary_fp_v1_';

  static String _bundleKey(String userId) => '$_bundlePrefix$userId';
  static String _fpKey(String userId) => '$_fpPrefix$userId';

  /// Fingerprint for cheap "did anything change?" checks (one small summary API on login).
  static String fingerprintFromSummary(Map<String, dynamic> d) {
    final t = d['total_ratings']?.toString() ?? '0';
    final l = d['latest_review_at']?.toString() ?? '';
    final a = d['average_rating']?.toString() ?? '0';
    return '$t|$l|$a';
  }

  static Future<Map<String, dynamic>?> readBundle(String userId) async {
    if (userId.isEmpty) return null;
    final p = await SharedPreferences.getInstance();
    final s = p.getString(_bundleKey(userId));
    if (s == null || s.isEmpty) return null;
    try {
      final o = jsonDecode(s);
      if (o is Map<String, dynamic>) return o;
      if (o is Map) return Map<String, dynamic>.from(o);
    } catch (_) {}
    return null;
  }

  static Future<void> writeBundle(String userId, Map<String, dynamic> data) async {
    if (userId.isEmpty) return;
    final p = await SharedPreferences.getInstance();
    await p.setString(_bundleKey(userId), jsonEncode(data));
  }

  static Future<void> clearBundle(String userId) async {
    if (userId.isEmpty) return;
    final p = await SharedPreferences.getInstance();
    await p.remove(_bundleKey(userId));
    await p.remove(_fpKey(userId));
  }

  static Future<String?> readFingerprint(String userId) async {
    if (userId.isEmpty) return null;
    final p = await SharedPreferences.getInstance();
    return p.getString(_fpKey(userId));
  }

  static Future<void> writeFingerprint(String userId, String fp) async {
    if (userId.isEmpty) return;
    final p = await SharedPreferences.getInstance();
    await p.setString(_fpKey(userId), fp);
  }
}
