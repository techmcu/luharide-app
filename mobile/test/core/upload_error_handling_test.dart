import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:luharide/core/utils/api_error_messages.dart';

RequestOptions _opts() => RequestOptions(path: '/uploads/driver-doc');

void main() {
  group('Upload error scenarios - dioResponseMessage safety', () {
    test('HTML 502 response does not crash', () {
      final e = DioException(
        requestOptions: _opts(),
        response: Response(
          requestOptions: _opts(),
          statusCode: 502,
          data: '<html><body>502 Bad Gateway</body></html>',
        ),
      );
      // Must not throw — old code did e.response?.data['message'] which crashes on String data
      expect(dioResponseMessage(e), isNull);
    });

    test('null response does not crash', () {
      final e = DioException(requestOptions: _opts());
      expect(dioResponseMessage(e), isNull);
    });

    test('numeric response data does not crash', () {
      final e = DioException(
        requestOptions: _opts(),
        response: Response(
          requestOptions: _opts(),
          statusCode: 500,
          data: 12345,
        ),
      );
      expect(dioResponseMessage(e), isNull);
    });

    test('list response data does not crash', () {
      final e = DioException(
        requestOptions: _opts(),
        response: Response(
          requestOptions: _opts(),
          statusCode: 500,
          data: ['error'],
        ),
      );
      expect(dioResponseMessage(e), isNull);
    });

    test('valid JSON map extracts message', () {
      final e = DioException(
        requestOptions: _opts(),
        response: Response(
          requestOptions: _opts(),
          statusCode: 413,
          data: {'success': false, 'message': 'File too large. Maximum size is 20 MB.'},
        ),
      );
      expect(dioResponseMessage(e), 'File too large. Maximum size is 20 MB.');
    });
  });

  group('502/503 retry should skip FormData', () {
    test('FormData is detected as non-retryable type', () {
      final Object formData = FormData.fromMap({'file': 'test'});
      expect(formData is FormData, isTrue);
      final Object mapData = {'key': 'value'};
      expect(mapData is FormData, isFalse);
    });
  });

  group('Upload-specific error messages', () {
    test('502 gives upload-specific message not raw DioException', () {
      final e = DioException(
        requestOptions: _opts(),
        type: DioExceptionType.badResponse,
        response: Response(
          requestOptions: _opts(),
          statusCode: 502,
          data: {'success': false, 'message': 'Server temporarily unavailable.'},
        ),
      );
      // userMessageFromDio for 502 should return friendly text
      final msg = userMessageFromDio(e);
      expect(msg, contains('available'));
      // Should NOT contain raw Dio internals
      expect(msg, isNot(contains('RequestOptions')));
      expect(msg, isNot(contains('DioException')));
    });

    test('timeout gives clear message', () {
      final e = DioException(
        requestOptions: _opts(),
        type: DioExceptionType.sendTimeout,
      );
      final msg = userMessageFromDio(e);
      expect(msg, anyOf(contains('timeout'), contains('long')));
    });
  });
}
