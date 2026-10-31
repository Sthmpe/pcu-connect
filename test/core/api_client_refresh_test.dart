import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:workflow/core/network/api_client.dart';

void main() {
  group('ApiClient.postAuthed', () {
    test('refreshes the token and retries once on UNAUTHENTICATED', () async {
      final seen = <String>[];
      final client = ApiClient(
        baseUrl: 'https://example.com/exec',
        client: MockClient((request) async {
          final token = jsonDecode(request.body)['idToken'] as String;
          seen.add(token);
          if (token == 'old') {
            return http.Response(
              jsonEncode({'ok': false, 'code': 'UNAUTHENTICATED', 'error': 'expired'}),
              200,
            );
          }
          return http.Response(jsonEncode({'ok': true, 'data': 'hi'}), 200);
        }),
      );

      final result = await client.postAuthed(
        action: 'me',
        getToken: ({bool forceRefresh = false}) async =>
            forceRefresh ? 'new' : 'old',
      );

      expect(result.isSuccess, isTrue);
      expect(seen, ['old', 'new']);
    });

    test('does not retry when the token cannot be refreshed', () async {
      var calls = 0;
      final client = ApiClient(
        baseUrl: 'https://example.com/exec',
        client: MockClient((request) async {
          calls++;
          return http.Response(
            jsonEncode({'ok': false, 'code': 'UNAUTHENTICATED', 'error': 'Please sign in.'}),
            200,
          );
        }),
      );

      final result = await client.postAuthed(
        action: 'me',
        getToken: ({bool forceRefresh = false}) async =>
            forceRefresh ? null : 'mock_token_a@x.com',
      );

      expect(result.isFailure, isTrue);
      expect(result.failure!.code, 'UNAUTHENTICATED');
      expect(calls, 1);
    });

    test('fails without a request when there is no token', () async {
      var calls = 0;
      final client = ApiClient(
        baseUrl: 'https://example.com/exec',
        client: MockClient((request) async {
          calls++;
          return http.Response('{}', 200);
        }),
      );
      final result = await client.postAuthed(
        action: 'me',
        getToken: ({bool forceRefresh = false}) async => null,
      );
      expect(result.isFailure, isTrue);
      expect(calls, 0);
    });
  });
}
