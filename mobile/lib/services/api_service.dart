import 'package:dio/dio.dart';
import '../core/constants/api_constants.dart';
import '../core/config/env_config.dart';

class ApiService {
  static final ApiService _instance = ApiService._internal();
  late final Dio _dio;
  
  factory ApiService() {
    return _instance;
  }
  
  ApiService._internal() {
    _dio = Dio(
      BaseOptions(
        baseUrl: EnvConfig.apiBaseUrl,
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 30),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    // Add interceptors
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          // Token is already set in headers via setAuthToken method
          print('🔵 REQUEST[${options.method}] => ${options.path}');
          if (options.headers['Authorization'] != null) {
            print('🔑 Token: ${options.headers['Authorization'].toString().substring(0, 20)}...');
          } else {
            print('⚠️  No token found in request');
          }
          return handler.next(options);
        },
        onResponse: (response, handler) {
          print('🟢 RESPONSE[${response.statusCode}] => ${response.requestOptions.path}');
          return handler.next(response);
        },
        onError: (error, handler) {
          print('🔴 ERROR[${error.response?.statusCode}] => ${error.requestOptions.path}');
          print('Error message: ${error.message}');
          if (error.response?.statusCode == 401) {
            print('❌ Authentication failed - Token might be invalid or expired');
          }
          return handler.next(error);
        },
      ),
    );
  }

  // GET request
  Future<Response> get(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      final response = await _dio.get(
        path,
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
        path,
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
        path,
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
        path,
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
