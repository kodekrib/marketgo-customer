import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Resolves the marketgo-api base URL.
///
/// Override with `--dart-define=API_URL=...`. Android emulators reach the host
/// machine through 10.0.2.2 rather than localhost.
String defaultApiBaseUrl() {
  const fromEnv = String.fromEnvironment('API_URL');
  if (fromEnv.isNotEmpty) return fromEnv;
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
    return 'http://10.0.2.2:8080';
  }
  return 'http://localhost:8080';
}

class ApiException implements Exception {
  const ApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

/// Thin JSON client for the marketgo-api (shared by every auth service).
class ApiClient {
  ApiClient({http.Client? httpClient, String? baseUrl, this.isOffline = false})
      : _http = httpClient ?? http.Client(),
        baseUrl = baseUrl ?? defaultApiBaseUrl();

  final http.Client _http;
  final String baseUrl;

  /// When true (e.g. an unauthenticated demo session), network calls are
  /// short-circuited so screens fall back to bundled demo data.
  bool isOffline;

  Future<void> _guard() async {
    if (isOffline) {
      throw const ApiException('Offline demo session', statusCode: 0);
    }
  }

  Future<Map<String, dynamic>> post(
    String path, {
    Map<String, dynamic>? body,
    Map<String, String>? headers,
  }) async {
    await _guard();
    final res = await _http.post(
      Uri.parse('$baseUrl$path'),
      headers: {'Content-Type': 'application/json', ...?headers},
      body: jsonEncode(body ?? const <String, dynamic>{}),
    ).timeout(_timeout);
    return _decode(res);
  }

  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, String>? headers,
  }) async {
    await _guard();
    final res = await _http.get(
      Uri.parse('$baseUrl$path'),
      headers: headers ?? const <String, String>{},
    ).timeout(_timeout);
    return _decode(res);
  }

  Future<Map<String, dynamic>> put(
    String path, {
    Map<String, dynamic>? body,
    Map<String, String>? headers,
  }) async {
    await _guard();
    final res = await _http.put(
      Uri.parse('$baseUrl$path'),
      headers: {'Content-Type': 'application/json', ...?headers},
      body: jsonEncode(body ?? const <String, dynamic>{}),
    ).timeout(_timeout);
    return _decode(res);
  }

  Future<Map<String, dynamic>> patch(
    String path, {
    Map<String, dynamic>? body,
    Map<String, String>? headers,
  }) async {
    await _guard();
    final res = await _http.patch(
      Uri.parse('$baseUrl$path'),
      headers: {'Content-Type': 'application/json', ...?headers},
      body: jsonEncode(body ?? const <String, dynamic>{}),
    ).timeout(_timeout);
    return _decode(res);
  }

  Future<Map<String, dynamic>> delete(
    String path, {
    Map<String, String>? headers,
  }) async {
    await _guard();
    final res = await _http.delete(
      Uri.parse('$baseUrl$path'),
      headers: headers ?? const <String, String>{},
    ).timeout(_timeout);
    return _decode(res);
  }

  static const _timeout = Duration(seconds: 15);

  Map<String, dynamic> _decode(http.Response res) {
    Map<String, dynamic> json;
    try {
      json = jsonDecode(res.body) as Map<String, dynamic>;
    } catch (_) {
      json = const <String, dynamic>{};
    }
    if (res.statusCode < 200 || res.statusCode >= 300) {
      final message =
          (json['error'] as String?) ?? 'Request failed (${res.statusCode})';
      throw ApiException(message, statusCode: res.statusCode);
    }
    return json;
  }
}