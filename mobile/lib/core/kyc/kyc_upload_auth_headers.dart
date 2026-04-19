import 'package:shared_preferences/shared_preferences.dart';

/// Bearer token for same-origin `/uploads/...` requests when the server (or nginx)
/// requires `Authorization` (fixes 401 on web/mobile for KYC images/PDFs).
Future<Map<String, String>?> kycUploadAuthHeaders() async {
  final p = await SharedPreferences.getInstance();
  final t = p.getString('access_token');
  if (t == null || t.isEmpty) return null;
  return {'Authorization': 'Bearer $t'};
}
