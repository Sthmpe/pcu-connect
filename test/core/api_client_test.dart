import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:workflow/core/network/api_client.dart';

void main() {
  group('ApiClient', () {
    test('sends text/plain JSON payload with action and idToken', () async {
      late http.Request sentRequest;
      final client = ApiClient(
        baseUrl: 'https://example.com/exec',
        client: MockClient((request) async {
          sentRequest = request;
          return http.Response(
            jsonEncode({'ok': true, 'data': {'name': 'David'}}),
            200,
          );
        }),
      );

      final result = await client.postAction(
        action: 'me',
        idToken: 'token-123',
        payload: {'month': '2026-10'},
      );

      expect(result.isSuccess, isTrue);
      expect(result.data['name'], 'David');
      expect(sentRequest.headers['Content-Type'], startsWith('text/plain'));

      final body = jsonDecode(sentRequest.body) as Map<String, dynamic>;
      expect(body['action'], 'me');
      expect(body['idToken'], 'token-123');
      expect(body['month'], '2026-10');
    });

    test('handles server error responses properly', () async {
      final client = ApiClient(
        baseUrl: 'https://example.com/exec',
        client: MockClient((request) async {
          return http.Response(
            jsonEncode({'ok': false, 'error': 'Access denied'}),
            200,
          );
        }),
      );

      final result = await client.postAction(
        action: 'me',
        idToken: 'token-bad',
      );

      expect(result.isFailure, isTrue);
      expect(result.failure?.message, contains('Access denied'));
    });
  });
}
