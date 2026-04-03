import 'dart:convert';
import 'dart:developer';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:hipster_meeting_test/config/env_config.dart';
import 'package:hipster_meeting_test/network/api_endpoints.dart';
import 'package:hipster_meeting_test/utils/app_logger.dart';

class ApiClient {
  late Dio _dio;

  ApiClient() {
    _dio = Dio(
      BaseOptions(
        baseUrl: ApiEndpoints.baseUrl,
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 30),
        sendTimeout: const Duration(seconds: 30),
        followRedirects: true,
      ),
    );

    if (kDebugMode) {
      _dio.interceptors.add(LogInterceptor(requestBody: true, responseBody: true));
    }
    _dio.interceptors.add(_ErrorInterceptor());
  }

  Map<String, String> get _jsonHeaders => {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        'x-api-key': EnvConfig.apiKey,
      };

  Future<Response> postRequest(
    String path, {
    Map<String, dynamic>? data,
    Map<String, dynamic>? queryParameters,
  }) async {
    AppLogger.debug('POST $path | query: $queryParameters | body: $data', tag: 'API');

    final response = await _dio.post(
      path,
      data: data != null ? json.encode(data) : null,
      queryParameters: queryParameters,
      options: Options(headers: _jsonHeaders),
    );

    if (kDebugMode) {
      log(const JsonEncoder.withIndent('  ').convert(response.data), name: 'API_RESPONSE');
    }

    return response;
  }

  Future<Response> getRequest(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    AppLogger.debug('GET $path | query: $queryParameters', tag: 'API');

    final response = await _dio.get(
      path,
      queryParameters: queryParameters,
      options: Options(headers: _jsonHeaders),
    );

    return response;
  }
}

class _ErrorInterceptor extends Interceptor {
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    AppLogger.error(
      'API Error: ${err.response?.statusCode} - ${err.message}',
      tag: 'API',
      error: err,
    );

    // Let error responses with body pass through so repository can extract user-friendly messages
    if (err.response != null && err.response!.data != null) {
      return handler.resolve(err.response!);
    }

    switch (err.type) {
      case DioExceptionType.connectionTimeout:
        throw ConnectionTimeoutException(err.requestOptions);
      case DioExceptionType.sendTimeout:
        throw SendTimeoutException(err.requestOptions);
      case DioExceptionType.receiveTimeout:
        throw ReceiveTimeoutException(err.requestOptions);
      case DioExceptionType.connectionError:
        throw NoConnectionException(err.requestOptions);
      case DioExceptionType.badResponse:
        throw BadResponseException(err);
      default:
        break;
    }
    handler.next(err);
  }
}

class ConnectionTimeoutException extends DioException {
  ConnectionTimeoutException(RequestOptions r) : super(requestOptions: r);
  @override
  String toString() => 'Connection timed out. Please try again.';
}

class SendTimeoutException extends DioException {
  SendTimeoutException(RequestOptions r) : super(requestOptions: r);
  @override
  String toString() => 'Send timed out. Please try again.';
}

class ReceiveTimeoutException extends DioException {
  ReceiveTimeoutException(RequestOptions r) : super(requestOptions: r);
  @override
  String toString() => 'Receive timed out. Please try again.';
}

class NoConnectionException extends DioException {
  NoConnectionException(RequestOptions r) : super(requestOptions: r);
  @override
  String toString() => 'No internet connection. Please check your network.';
}

class BadResponseException extends DioException {
  BadResponseException(DioException e) : super(requestOptions: e.requestOptions, response: e.response);
  @override
  String toString() => 'Server error: ${response?.statusCode}';
}
