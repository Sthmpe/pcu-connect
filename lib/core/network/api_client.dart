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
              ServerFailure(
                decoded['error']?.toString() ?? 'Server error',
                decoded['code']?.toString(),
              ),
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

  /// Sends [action] with a token from [getToken]. If the backend answers
  /// UNAUTHENTICATED, asks for a refreshed token and retries once.
  Future<ApiResult<dynamic>> postAuthed({
    required String action,
    required Future<String?> Function({bool forceRefresh}) getToken,
    Map<String, dynamic>? payload,
  }) async {
    final token = await getToken();
    if (token == null) {
      return const ApiResult.failure(
        AuthFailure('Please sign in.', 'UNAUTHENTICATED'),
      );
    }
    final first =
        await postAction(action: action, idToken: token, payload: payload);
    if (first.isSuccess || first.failure?.code != 'UNAUTHENTICATED') {
      return first;
    }
    final fresh = await getToken(forceRefresh: true);
    if (fresh == null || fresh == token) return first;
    return postAction(action: action, idToken: fresh, payload: payload);
  }

  void dispose() {
    _client.close();
  }
}
