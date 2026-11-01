import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workflow/core/network/api_client.dart';
import 'package:workflow/core/network/api_result.dart';
import 'package:workflow/core/storage/local_cache.dart';
import 'package:workflow/core/utils/month_utils.dart';
import 'package:workflow/domain/entities/worker_user.dart';
import 'package:workflow/domain/repositories/i_auth_repository.dart';
import 'package:workflow/presentation/auth/bloc/auth_bloc.dart';
import 'package:workflow/presentation/auth/bloc/auth_event.dart';
import 'package:workflow/presentation/auth/bloc/auth_state.dart';

class _Auth implements IAuthRepository {
  final log = <String>[];
  @override
  Future<void> signOut() async => log.add('signOut');
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('F1 months follow Lagos, not the device', () {
    test('23:30 UTC on 31 Oct is already November in Lagos', () {
      expect(MonthUtils.current(DateTime.utc(2026, 10, 31, 23, 30)), '2026-11');
      expect(MonthUtils.current(DateTime.utc(2026, 10, 31, 22, 59)), '2026-10');
      expect(MonthUtils.recent(2, DateTime.utc(2026, 12, 31, 23, 30)), ['2027-01', '2026-12']);
    });
  });

  group('F4 plain messages from the API client', () {
    ApiClient client(Future<http.Response> Function(http.Request) handler) =>
        ApiClient(baseUrl: 'https://example.com/exec', client: MockClient(handler));

    test('an HTML error page from Apps Script', () async {
      final r = await client((_) async => http.Response('<html>Sorry, unable to open the file</html>', 200))
          .postAction(action: 'me', idToken: 't');
      expect(r.failure!.code, 'BAD_RESPONSE');
      expect(r.failure!.message, isNot(contains('FormatException')));
    });

    test('a timeout and a dropped connection', () async {
      final slow = await client((_) async => throw TimeoutException('slow')).postAction(action: 'me', idToken: 't');
      expect(slow.failure!.message, 'The server took too long to answer. Check your connection and try again.');
      final down = await client((_) async => throw http.ClientException('XMLHttpRequest error')).postAction(action: 'me', idToken: 't');
      expect(down.failure!.message, 'We could not reach the server. Check your connection and try again.');
    });
  });

  group('F6 sign-out removes this device from the person first', () {
    test('beforeSignOut runs while still signed in, then sign-out', () async {
      SharedPreferences.setMockInitialValues({});
      final auth = _Auth();
      final bloc = AuthBloc(
        authRepository: auth,
        localCache: LocalCache(await SharedPreferences.getInstance()),
        beforeSignOut: () async => auth.log.add('forget token'),
      );
      bloc.add(AuthSignOutRequestedEvent());
      await bloc.stream.firstWhere((s) => s is AuthUnauthenticatedState);
      expect(auth.log, ['forget token', 'signOut']);
      await bloc.close();
    });

    test('a failing or slow hook never blocks sign-out', () async {
      SharedPreferences.setMockInitialValues({});
      final auth = _Auth();
      final bloc = AuthBloc(
        authRepository: auth,
        localCache: LocalCache(await SharedPreferences.getInstance()),
        beforeSignOut: () async => throw Exception('offline'),
      );
      bloc.add(AuthSignOutRequestedEvent());
      await bloc.stream.firstWhere((s) => s is AuthUnauthenticatedState);
      expect(auth.log, ['signOut']);
      await bloc.close();
    });
  });

  test('ApiResult and WorkerUser stay usable in tests', () {
    expect(const ApiResult.success(1).isSuccess, isTrue);
    expect(const WorkerUser(id: 'W1', name: 'A', email: 'a@x.com', phone: '', role: 'Admin', active: true).isAdmin, isTrue);
  });
}
