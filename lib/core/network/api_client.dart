import 'dart:async';
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
        final dynamic decoded;
        try {
          decoded = jsonDecode(response.body);
        } on FormatException {
          // Apps Script sends an HTML page when the script itself fails.
          return const ApiResult.failure(
            ServerFailure('The server sent an unexpected answer. Please try again in a minute.', 'BAD_RESPONSE'),
          );
        }
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
    } on TimeoutException {
      return const ApiResult.failure(
          NetworkFailure('The server took too long to answer. Check your connection and try again.'));
    } catch (e) {
      return const ApiResult.failure(
          NetworkFailure('We could not reach the server. Check your connection and try again.'));
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
