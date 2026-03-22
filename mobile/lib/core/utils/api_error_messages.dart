import 'package:dio/dio.dart';

/// User-facing text for SnackBars (Hindi + English short).
String userMessageFromDio(DioException e) {
  final code = e.response?.statusCode;
  final data = e.response?.data;
  String? serverMsg;
  if (data is Map) {
    serverMsg = data['message']?.toString() ?? data['error']?.toString();
  }

  if (code == 404) {
    return 'Server par API nahi mila (404). VPS par latest backend deploy + restart karein. '
        'Local test: `node server.js` phir Flutter `--dart-define=USE_LOCAL_API=true`.';
  }
  if (code == 502 || code == 503 || code == 504) {
    return serverMsg ??
        'Server abhi available nahi ($code). Thodi der baad try karein.';
  }
  if (code == 429) {
    return 'Bahut saare requests — 1–2 minute baad dubara try karein.';
  }
  if (serverMsg != null && serverMsg.isNotEmpty) {
    return serverMsg;
  }
  return e.message ?? 'Network error. Connection check karein.';
}
