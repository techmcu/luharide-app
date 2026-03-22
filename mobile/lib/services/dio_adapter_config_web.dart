import 'package:dio/browser.dart';
import 'package:dio/dio.dart';

/// Web — explicit browser adapter (XHR/fetch); avoids edge cases on some Chrome builds.
void configureDioHttpAdapter(Dio dio) {
  dio.httpClientAdapter = BrowserHttpClientAdapter();
}
