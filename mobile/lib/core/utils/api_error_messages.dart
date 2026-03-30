import 'package:dio/dio.dart';

/// User-facing text for SnackBars (Hindi + English short).
String userMessageFromDio(DioException e) {
  // No HTTP body: timeouts, DNS, offline, TLS — always show simple text (never raw Dio internals).
  switch (e.type) {
    case DioExceptionType.connectionTimeout:
    case DioExceptionType.sendTimeout:
    case DioExceptionType.receiveTimeout:
      return 'Server se time par jawab nahi mila (timeout). Internet check karke thodi der baad dubara try karein. '
          '(The connection or server took too long.)';
    case DioExceptionType.connectionError:
      return 'Server tak pahunch nahi paye. Wi‑Fi / mobile data ya flight mode check karein. '
          '(Cannot reach server.)';
    case DioExceptionType.cancel:
      return 'Request radd ho gayi.';
    case DioExceptionType.badCertificate:
      return 'Secure connection fail (SSL). VPN / network check karein.';
    case DioExceptionType.badResponse:
    case DioExceptionType.unknown:
      break;
  }

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
  return e.message != null && !_looksLikeRawDioAdvice(e.message!)
      ? e.message!
      : 'Network error. Connection check karein.';
}

bool _looksLikeRawDioAdvice(String m) {
  return m.contains('RequestOptions.connectTimeout') ||
      m.contains('receiveTimeout') ||
      m.contains('sendTimeout');
}
