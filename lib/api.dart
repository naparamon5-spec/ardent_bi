import 'dart:convert';
import 'package:http/http.dart' as http;
import 'demo_data.dart';

/// Raised when the API returns a non-2xx. `status == 401` drives the sign-out
/// path, mirroring the web client's 401-to-login redirect.
class ApiException implements Exception {
  final int? status;
  final String message;
  final String? hint;
  ApiException(this.message, {this.status, this.hint});
  @override
  String toString() => message;
}

/// Thin wrapper over http that attaches the JWT and points at the API base —
/// the mobile counterpart of `web/app/composables/useApi.js`. The base URL is
/// configurable at runtime (set on the login screen) because a phone cannot
/// reach the dev machine's `localhost`.
class ApiClient {
  String baseUrl;
  String? token;
  final http.Client _http;

  /// When true, requests return canned [DemoData] instead of hitting the network
  /// so the UI can be browsed without a backend.
  bool demo = false;

  /// Called on any 401 so the app can clear the session and return to login.
  void Function()? onUnauthorized;

  ApiClient({required this.baseUrl, this.token, http.Client? client})
      : _http = client ?? http.Client();

  Future<dynamic> _demo(String path, Object? body) async {
    // A small delay so loading states are visible, like a real request.
    await Future.delayed(const Duration(milliseconds: 180));
    return DemoData.resolve(path, body);
  }

  Map<String, String> get _headers => {
        'content-type': 'application/json',
        'accept': 'application/json',
        if (token != null && token!.isNotEmpty) 'authorization': 'Bearer $token',
      };

  Uri _uri(String path) => Uri.parse('${baseUrl.replaceAll(RegExp(r'/$'), '')}$path');

  Future<dynamic> get(String path) {
    if (demo) return _demo(path, null);
    return _send(() => _http.get(_uri(path), headers: _headers));
  }

  Future<dynamic> post(String path, [Object? body]) {
    if (demo) return _demo(path, body);
    return _send(() => _http.post(_uri(path), headers: _headers, body: jsonEncode(body ?? {})));
  }

  /// POST that keeps the raw response body (CSV export) instead of parsing JSON.
  Future<String> postText(String path, [Object? body]) async {
    if (demo) {
      final r = await _demo(path, body);
      return r is String ? r : jsonEncode(r);
    }
    late http.Response res;
    try {
      res = await _http
          .post(_uri(path), headers: _headers, body: jsonEncode(body ?? {}))
          .timeout(const Duration(seconds: 60));
    } catch (e) {
      throw ApiException('Cannot reach the server. Check the URL and your connection.');
    }
    if (res.statusCode == 401) onUnauthorized?.call();
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw ApiException('Request failed (${res.statusCode})', status: res.statusCode);
    }
    return res.body;
  }

  Future<dynamic> _send(Future<http.Response> Function() run) async {
    late http.Response res;
    try {
      res = await run().timeout(const Duration(seconds: 60));
    } catch (e) {
      throw ApiException('Cannot reach the server. Check the URL and your connection.');
    }
    if (res.statusCode == 401) {
      onUnauthorized?.call();
    }
    dynamic data;
    if (res.body.isNotEmpty) {
      try {
        data = jsonDecode(res.body);
      } catch (_) {
        data = null;
      }
    }
    if (res.statusCode < 200 || res.statusCode >= 300) {
      final map = data is Map ? data : const {};
      throw ApiException(
        (map['error'] ?? 'Request failed (${res.statusCode})').toString(),
        status: res.statusCode,
        hint: map['hint']?.toString(),
      );
    }
    return data;
  }
}
