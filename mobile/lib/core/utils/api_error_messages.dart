import 'package:dio/dio.dart';

/// Safe message for [AuthProvider] / SnackBars: never show raw Dio "RequestOptions…" text.
String userFacingAuthError(Object error) {
  if (error is DioException) {
    return userMessageFromDio(error);
  }
  final raw = error.toString().replaceAll('Exception:', '').trim();
  if (_looksLikeRawDioAdvice(raw) ||
      raw.contains('connection took longer than') ||
      (raw.contains('0:00:') && raw.contains('aborted'))) {
    return 'Server se time par jawab nahi mila (timeout). Internet check karke thodi der baad dubara try karein. '
        '(Request timed out.)';
  }
  if (raw.contains('SocketException') ||
      raw.contains('Failed host lookup') ||
      raw.contains('Network is unreachable')) {
    return 'Server tak pahunch nahi paye. Wi‑Fi / mobile data check karein. (Cannot reach server.)';
  }
  return raw;
}

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
      final inner = e.error?.toString() ?? '';
      if (inner.contains('HandshakeException') ||
          inner.contains('CERTIFICATE_VERIFY_FAILED') ||
          inner.contains('TlsException')) {
        return 'Secure connection fail (SSL). Phone date/time sahi hai? VPN off karke try karein. '
            '(SSL / certificate error.)';
      }
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
    return serverMsg ??
        'Yeh service abhi uplabdh nahi (404). Thodi der baad try karein. (Service not found.)';
  }
  if (code == 502 || code == 503 || code == 504) {
    return 'Server abhi available nahi hai. Thodi der baad dubara try karein. '
        '(Server temporarily unavailable.)';
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

/// Safely extract 'message' from a Dio error response body.
/// Returns null if data is not a Map or 'message' key is missing.
String? dioResponseMessage(DioException e) {
  final data = e.response?.data;
  if (data is Map) {
    return data['message']?.toString();
  }
  return null;
}
