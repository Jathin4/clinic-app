import 'dart:convert';
import 'package:http/http.dart' as http;

/// ─── Central API configuration ───────────────────────────────────────────────
/// Change this ONE value to point to your backend server.
class ApiConfig {
  /// Base URL — no trailing slash, no /api/v1 prefix.
  /// Examples:
  ///   'http://10.11.1.128:5020'   (LAN)
  ///   'http://192.168.1.10:5020'  (local dev)
  ///   'https://api.yourdomain.com'(production)
  ///   'http://98.70.50.9:5014'    (Server)
  static const String baseUrl = 'http://98.70.50.9:5014';
}

class ApiClient {
  static const String baseUrl = ApiConfig.baseUrl;

  static Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };

  static Future<Map<String, dynamic>> get(
    String endpoint, {
    Map<String, dynamic>? queryParams,
  }) async {
    final uri = Uri.parse('$baseUrl$endpoint').replace(
      queryParameters: queryParams?.map(
        (k, v) => MapEntry(k, v.toString()),
      ),
    );
    final response = await http.get(uri, headers: _headers);
    return _handleResponse(response);
  }

  static Future<Map<String, dynamic>> post(
    String endpoint,
    Map<String, dynamic> body,
  ) async {
    final uri = Uri.parse('$baseUrl$endpoint');
    final response = await http.post(
      uri,
      headers: _headers,
      body: jsonEncode(body),
    );
    return _handleResponse(response);
  }

  static Future<Map<String, dynamic>> delete(
    String endpoint,
    Map<String, dynamic> body,
  ) async {
    final uri = Uri.parse('$baseUrl$endpoint');
    final response = await http.delete(
      uri,
      headers: _headers,
      body: jsonEncode(body),
    );
    return _handleResponse(response);
  }

  static Map<String, dynamic> _handleResponse(http.Response response) {
    final decoded = jsonDecode(response.body);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (decoded is List) return {'data': decoded, 'status': response.statusCode};
      return {...(decoded as Map<String, dynamic>), 'status': response.statusCode};
    }
    throw ApiException(
      statusCode: response.statusCode,
      message: decoded is Map ? (decoded['detail'] ?? decoded['error'] ?? 'Unknown error') : 'Error',
    );
  }
}

class ApiException implements Exception {
  final int statusCode;
  final dynamic message;
  const ApiException({required this.statusCode, required this.message});

  @override
  String toString() => 'ApiException($statusCode): $message';
}
