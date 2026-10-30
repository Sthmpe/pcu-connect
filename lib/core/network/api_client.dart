import 'dart:convert';
import 'package:http/http.dart' as http;
import '../errors/failures.dart';
import 'api_result.dart';

/// HTTP Client specially designed for Google Apps Script Web App API
/// Enforces Content-Type: text/plain to prevent browser CORS OPTIONS preflight,
/// automatically includes Google ID token, and follows redirects.
class ApiClient {
  final String baseUrl;
  final http.Client _client;

  ApiClient({
    required this.baseUrl,
    http.Client? client,
  }) : _client = client ?? http.Client();

  Future<ApiResult<dynamic>> postAction({
    required String action,
    required String idToken,
    Map<String, dynamic>? payload,
  }) async {
    try {
      final bodyMap = {
        'action': action,
        'idToken': idToken,
        ...?payload,
      };

      final response = await _client
          .post(
            Uri.parse(baseUrl),
            headers: {
              // Crucial: text/plain bypasses CORS preflight in Google Apps Script!
              'Content-Type': 'text/plain;charset=utf-8',
            },
            body: jsonEncode(bodyMap),
          )
          .timeout(const Duration(seconds: 25));

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) {
          if (decoded['ok'] == true) {
            return ApiResult.success(decoded['data']);
          } else {
            return ApiResult.failure(
              ServerFailure(decoded['error']?.toString() ?? 'Server error'),
            );
          }
        }
        return ApiResult.success(decoded);
      } else {
        return ApiResult.failure(
          ServerFailure('HTTP ${response.statusCode}: ${response.reasonPhrase}'),
        );
      }
    } catch (e) {
      return ApiResult.failure(NetworkFailure(e.toString()));
    }
  }

  void dispose() {
    _client.close();
  }
}
