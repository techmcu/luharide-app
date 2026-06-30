import 'package:dio/dio.dart';

/// Current app language code — set by [AppLanguageProvider] on change.
/// Defaults to 'en'. Error messages respect this without needing BuildContext.
String _appLang = 'en';

void setErrorMessageLocale(String lang) {
  _appLang = lang;
}

String _pick(String en, String hi) => _appLang == 'hi' ? hi : en;

/// Safe message for [AuthProvider] / SnackBars: never show raw Dio "RequestOptions…" text.
String userFacingAuthError(Object error) {
  if (error is DioException) {
    return userMessageFromDio(error);
  }
  final raw = error.toString().replaceAll('Exception:', '').trim();
  if (_looksLikeRawDioAdvice(raw) ||
      raw.contains('connection took longer than') ||
      (raw.contains('0:00:') && raw.contains('aborted'))) {
    return _pick(
      'Server did not respond in time. Please check your internet and try again.',
      'सर्वर ने समय पर जवाब नहीं दिया। कृपया इंटरनेट जाँचें और पुनः प्रयास करें।',
    );
  }
  if (raw.contains('SocketException') ||
      raw.contains('Failed host lookup') ||
      raw.contains('Network is unreachable')) {
    return _pick(
      'Cannot reach the server. Please check your Wi-Fi or mobile data.',
      'सर्वर तक पहुँच नहीं हो पा रही। कृपया Wi-Fi या मोबाइल डेटा जाँचें।',
    );
  }
  return raw;
}

/// User-facing text for SnackBars — localized per app language setting.
String userMessageFromDio(DioException e) {
  switch (e.type) {
    case DioExceptionType.connectionTimeout:
    case DioExceptionType.sendTimeout:
    case DioExceptionType.receiveTimeout:
      return _pick(
        'Server did not respond in time. Please check your internet and try again.',
        'सर्वर ने समय पर जवाब नहीं दिया। कृपया इंटरनेट जाँचें और पुनः प्रयास करें।',
      );
    case DioExceptionType.connectionError:
      final inner = e.error?.toString() ?? '';
      if (inner.contains('HandshakeException') ||
          inner.contains('CERTIFICATE_VERIFY_FAILED') ||
          inner.contains('TlsException')) {
        return _pick(
          'Secure connection failed (SSL). Please check your phone date/time and try disabling VPN.',
          'सुरक्षित कनेक्शन विफल (SSL)। कृपया फ़ोन की दिनांक/समय जाँचें और VPN बंद करके प्रयास करें।',
        );
      }
      return _pick(
        'Cannot reach the server. Please check your Wi-Fi, mobile data, or flight mode.',
        'सर्वर तक पहुँच नहीं हो पा रही। कृपया Wi-Fi, मोबाइल डेटा या फ्लाइट मोड जाँचें।',
      );
    case DioExceptionType.cancel:
      return _pick('Request cancelled.', 'अनुरोध रद्द कर दिया गया।');
    case DioExceptionType.badCertificate:
      return _pick(
        'Secure connection failed (SSL). Please check your network or VPN.',
        'सुरक्षित कनेक्शन विफल (SSL)। कृपया नेटवर्क या VPN जाँचें।',
      );
    default:
      // badResponse, unknown, and any future Dio exception types (e.g.
      // transformTimeout added in newer dio) fall through to the HTTP
      // status-code handling below. Using `default` keeps this switch
      // exhaustive across dio versions so CI analyze never breaks on it.
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
        _pick(
          'This service is currently unavailable. Please try again later.',
          'यह सेवा अभी उपलब्ध नहीं है। कृपया बाद में पुनः प्रयास करें।',
        );
  }
  if (code == 502 || code == 503 || code == 504) {
    return _pick(
      'Server is temporarily unavailable. Please try again later.',
      'सर्वर अस्थायी रूप से अनुपलब्ध है। कृपया बाद में पुनः प्रयास करें।',
    );
  }
  if (code == 429) {
    return _pick(
      'Too many requests. Please wait 1–2 minutes and try again.',
      'बहुत अधिक अनुरोध। कृपया 1–2 मिनट प्रतीक्षा करें और पुनः प्रयास करें।',
    );
  }
  if (serverMsg != null && serverMsg.isNotEmpty) {
    return serverMsg;
  }
  return e.message != null && !_looksLikeRawDioAdvice(e.message!)
      ? e.message!
      : _pick(
          'Network error. Please check your connection.',
          'नेटवर्क त्रुटि। कृपया अपना कनेक्शन जाँचें।',
        );
}

bool _looksLikeRawDioAdvice(String m) {
  return m.contains('RequestOptions.connectTimeout') ||
      m.contains('receiveTimeout') ||
      m.contains('sendTimeout');
}

/// Safely extract 'message' from a Dio error response body.
String? dioResponseMessage(DioException e) {
  final data = e.response?.data;
  if (data is Map) {
    return data['message']?.toString();
  }
  return null;
}
