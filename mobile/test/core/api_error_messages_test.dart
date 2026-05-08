import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:luharide/core/utils/api_error_messages.dart';

RequestOptions _opts() => RequestOptions(path: '/test');

void main() {
  group('dioResponseMessage', () {
    test('extracts message from Map response data', () {
      final e = DioException(
        requestOptions: _opts(),
        response: Response(
          requestOptions: _opts(),
          statusCode: 400,
          data: {'message': 'Bad input'},
        ),
      );
      expect(dioResponseMessage(e), 'Bad input');
    });

    test('returns null when data is a String (HTML error page)', () {
      final e = DioException(
        requestOptions: _opts(),
        response: Response(
          requestOptions: _opts(),
          statusCode: 502,
          data: '<html>502 Bad Gateway</html>',
        ),
      );
      expect(dioResponseMessage(e), isNull);
    });

    test('returns null when response is null', () {
      final e = DioException(requestOptions: _opts());
      expect(dioResponseMessage(e), isNull);
    });

    test('returns null when data Map has no message key', () {
      final e = DioException(
        requestOptions: _opts(),
        response: Response(
          requestOptions: _opts(),
          statusCode: 500,
          data: {'error': 'something'},
        ),
      );
      expect(dioResponseMessage(e), isNull);
    });
  });

  group('userMessageFromDio', () {
    test('timeout returns friendly message', () {
      final e = DioException(
        requestOptions: _opts(),
        type: DioExceptionType.connectionTimeout,
      );
      final msg = userMessageFromDio(e);
      expect(msg, contains('timeout'));
    });

    test('connectionError returns friendly message', () {
      final e = DioException(
        requestOptions: _opts(),
        type: DioExceptionType.connectionError,
      );
      final msg = userMessageFromDio(e);
      expect(msg, contains('server'));
    });

    test('502 returns server unavailable', () {
      final e = DioException(
        requestOptions: _opts(),
        type: DioExceptionType.badResponse,
        response: Response(
          requestOptions: _opts(),
          statusCode: 502,
          data: '<html>Bad Gateway</html>',
        ),
      );
      final msg = userMessageFromDio(e);
      expect(msg, contains('available'));
    });

    test('503 returns server unavailable', () {
      final e = DioException(
        requestOptions: _opts(),
        type: DioExceptionType.badResponse,
        response: Response(
          requestOptions: _opts(),
          statusCode: 503,
        ),
      );
      final msg = userMessageFromDio(e);
      expect(msg, contains('available'));
    });

    test('429 returns rate limit message', () {
      final e = DioException(
        requestOptions: _opts(),
        type: DioExceptionType.badResponse,
        response: Response(
          requestOptions: _opts(),
          statusCode: 429,
        ),
      );
      final msg = userMessageFromDio(e);
      expect(msg, contains('requests'));
    });

    test('server message from response body is preferred', () {
      final e = DioException(
        requestOptions: _opts(),
        type: DioExceptionType.badResponse,
        response: Response(
          requestOptions: _opts(),
          statusCode: 422,
          data: {'message': 'Custom server error'},
        ),
      );
      final msg = userMessageFromDio(e);
      expect(msg, 'Custom server error');
    });

    test('SSL error detected in connectionError', () {
      final e = DioException(
        requestOptions: _opts(),
        type: DioExceptionType.connectionError,
        error: 'HandshakeException: CERTIFICATE_VERIFY_FAILED',
      );
      final msg = userMessageFromDio(e);
      expect(msg, contains('SSL'));
    });
  });

  group('userFacingAuthError', () {
    test('DioException is routed through userMessageFromDio', () {
      final e = DioException(
        requestOptions: _opts(),
        type: DioExceptionType.receiveTimeout,
      );
      final msg = userFacingAuthError(e);
      expect(msg, contains('timeout'));
    });

    test('plain Exception strips prefix', () {
      final msg = userFacingAuthError(Exception('Something went wrong'));
      expect(msg, contains('Something went wrong'));
    });

    test('SocketException in string gives network message', () {
      final msg = userFacingAuthError(Exception('SocketException: Failed host lookup'));
      expect(msg, contains('server'));
    });

    test('raw Dio advice text is replaced with friendly message', () {
      final msg = userFacingAuthError(
        Exception('RequestOptions.connectTimeout blah blah'),
      );
      expect(msg, contains('timeout'));
    });
  });
}
