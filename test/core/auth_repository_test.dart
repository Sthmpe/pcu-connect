import 'package:flutter_test/flutter_test.dart';
import 'package:workflow/core/network/api_client.dart';
import 'package:workflow/data/repositories/auth_repository_impl.dart';

void main() {
  test('mock session uses the mock token and cannot be refreshed', () async {
    final repo = AuthRepositoryImpl(
      apiClient: ApiClient(baseUrl: 'https://example.com/exec'),
    );
    repo.useMockSession('a@x.com');
    expect(await repo.getIdToken(), 'mock_token_a@x.com');
    expect(await repo.getIdToken(forceRefresh: true), isNull);
  });
}
