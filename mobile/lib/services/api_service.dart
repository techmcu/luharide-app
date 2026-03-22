import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/constants/api_constants.dart';
import '../core/config/env_config.dart';
import 'realtime_socket_service.dart';

/// Builds the **full request URL** so we never rely on Dio `baseUrl` + path merging
/// (which can drop `/api` or behave differently per platform).
String buildApiUrl(String path) {
  final p = path.trim();
  if (p.startsWith('http://') || p.startsWith('https://')) {
    return p;
  }
  final base = EnvConfig.apiBaseUrl.replaceAll(RegExp(r'/+$'), '');
  final rel = p.startsWith('/') ? p.substring(1) : p;
  return '$base/$rel';
}

/// For matching refresh/logout paths when [RequestOptions.path] may be relative or absolute.
String dioRelativePath(String path) {
  if (path.isEmpty) return path;
  return path.startsWith('/') ? path.substring(1) : path;
}

class ApiService {
  static final ApiService _instance = ApiService._internal();
  late final Dio _dio;

  factory ApiService() {
    return _instance;
  }

  ApiService._internal() {
    _dio = Dio(
      BaseOptions(
        // Every call uses [buildApiUrl] — empty avoids any merge ambiguity.
        baseUrl: '',
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 30),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          if (kDebugMode) {
            // ignore: avoid_print
            print('🔵 REQUEST[${options.method}] => ${options.uri}');
            final p = options.uri.toString();
            final isPublicAuth = p.contains('simple-auth/login') ||
                p.contains('simple-auth/signup') ||
                p.contains('simple-auth/forgot-password') ||
                p.contains('simple-auth/reset-password');
            if (options.headers['Authorization'] != null) {
              // ignore: avoid_print
              print('🔑 Token: ${options.headers['Authorization'].toString().substring(0, 20)}...');
            } else if (!isPublicAuth) {
              // Login/signup etc. intentionally have no token — don't spam "no token"
              // ignore: avoid_print
              print('⚠️  No token found in request');
            }
          }
          return handler.next(options);
        },
        onResponse: (response, handler) {
          if (kDebugMode) {
            // ignore: avoid_print
            print('🟢 RESPONSE[${response.statusCode}] => ${response.requestOptions.uri}');
          }
          return handler.next(response);
        },
        onError: (error, handler) {
          if (kDebugMode) {
            // ignore: avoid_print
            print('🔴 ERROR[${error.response?.statusCode}] => ${error.requestOptions.uri}');
            // ignore: avoid_print
            print('Error message: ${error.message}');
            if (kIsWeb && error.type == DioExceptionType.connectionError) {
              // ignore: avoid_print
              print(
                '💡 Web: (1) Backend `node server.js` chal raha hai? `http://localhost:3000/health` browser me kholo. '
                '(2) API URL `localhost` honi chahiye (127.0.0.1 Chrome PNA se block ho sakta tha). '
                '(3) Backend restart — CORS + Access-Control-Allow-Private-Network fix.',
              );
            }
          }
          // 429: rate limit — show clear message (not raw Dio validateStatus text)
          if (error.response?.statusCode == 429) {
            final friendly = DioException(
              requestOptions: error.requestOptions,
              response: error.response,
              type: DioExceptionType.badResponse,
              message:
                  'Bahut saare requests — server limit. 1–2 minute baad dubara try karein. '
                  '(Too many requests; please wait and try again.)',
            );
            return handler.next(friendly);
          }
          // Global 401 handler: try refresh once, then logout on failure.
          if (error.response?.statusCode == 401 &&
              error.requestOptions.extra['__retriable__'] != false &&
              !_isAuthRefreshPath(error.requestOptions)) {
            _handleUnauthorized(error, handler);
          } else {
            return handler.next(error);
          }
        },
      ),
    );
  }

  bool _isAuthRefreshPath(RequestOptions o) {
    final s = o.uri.toString();
    final r = dioRelativePath(ApiConstants.refreshToken);
    final l = dioRelativePath(ApiConstants.logout);
    return s.contains(r) || s.contains(l);
  }

  // Centralized 401 handling: refresh token once and retry original request.
  Future<void> _handleUnauthorized(DioException error, ErrorInterceptorHandler handler) async {
    try {
      final refreshed = await _refreshAccessToken();
      if (!refreshed) {
        // Logout-like behavior: clear token so app can redirect user.
        clearAuthToken();
        return handler.next(error);
      }

      final req = error.requestOptions;
      final opts = Options(
        method: req.method,
        headers: req.headers,
        responseType: req.responseType,
        contentType: req.contentType,
        followRedirects: req.followRedirects,
        validateStatus: req.validateStatus,
        receiveDataWhenStatusError: req.receiveDataWhenStatusError,
      );
      // Mark as non-retriable to avoid infinite loop.
      req.extra['__retriable__'] = false;

      final cloneResponse = await _dio.request<dynamic>(
        req.uri.toString(),
        data: req.data,
        queryParameters: req.queryParameters,
        options: opts,
      );
      return handler.resolve(cloneResponse);
    } catch (_) {
      clearAuthToken();
      return handler.next(error);
    }
  }

  Future<bool> _refreshAccessToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final refreshToken = prefs.getString('refresh_token');
      if (refreshToken == null || refreshToken.isEmpty) {
        return false;
      }

      final response = await _dio.post(
        dioRelativePath(ApiConstants.refreshToken),
        data: {
          'refreshToken': refreshToken,
          'platform': 'mobile',
        },
        options: Options(
          // Avoid recursive interceptor on this call
          extra: {'__retriable__': false},
        ),
      );

      if (response.statusCode == 200 && response.data['success'] == true) {
        final data = response.data['data'];
        final tokens = data['tokens'] as Map<String, dynamic>? ?? {};
        final access = tokens['accessToken']?.toString();
        final refresh = tokens['refreshToken']?.toString();
        if (access == null || access.isEmpty) return false;

        await prefs.setString('access_token', access);
        if (refresh != null && refresh.isNotEmpty) {
          await prefs.setString('refresh_token', refresh);
        }
        setAuthToken(access);
        RealtimeSocketService.instance.connect();
        if (kDebugMode) {
          // ignore: avoid_print
          print('🔄 Token refreshed via interceptor');
        }
        return true;
      }
      return false;
    } on DioException catch (e) {
      if (kDebugMode) {
        // ignore: avoid_print
        print('⚠️  Refresh token failed: ${e.message}');
      }
      return false;
    } on SocketException {
      return false;
    } on TimeoutException {
      return false;
    } catch (_) {
      return false;
    }
  }

  // GET request
  Future<Response> get(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      final response = await _dio.get(
        buildApiUrl(path),
        queryParameters: queryParameters,
        options: options,
      );
      return response;
    } catch (e) {
      rethrow;
    }
  }

  // POST request
  Future<Response> post(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      final response = await _dio.post(
        buildApiUrl(path),
        data: data,
        queryParameters: queryParameters,
        options: options,
      );
      return response;
    } catch (e) {
      rethrow;
    }
  }

  // PUT request
  Future<Response> put(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      final response = await _dio.put(
        buildApiUrl(path),
        data: data,
        queryParameters: queryParameters,
        options: options,
      );
      return response;
    } catch (e) {
      rethrow;
    }
  }

  // PATCH request
  Future<Response> patch(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      final response = await _dio.patch(
        buildApiUrl(path),
        data: data,
        queryParameters: queryParameters,
        options: options,
      );
      return response;
    } catch (e) {
      rethrow;
    }
  }

  // DELETE request
  Future<Response> delete(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      final response = await _dio.delete(
        buildApiUrl(path),
        data: data,
        queryParameters: queryParameters,
        options: options,
      );
      return response;
    } catch (e) {
      rethrow;
    }
  }

  // Set auth token
  void setAuthToken(String token) {
    _dio.options.headers['Authorization'] = 'Bearer $token';
  }

  // Clear auth token
  void clearAuthToken() {
    _dio.options.headers.remove('Authorization');
  }
}
