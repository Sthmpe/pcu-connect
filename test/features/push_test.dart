import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workflow/core/storage/local_cache.dart';
import 'package:workflow/data/firestore/push_service.dart';
import 'package:workflow/presentation/common/push_cubit.dart';

class _Service implements IPushService {
  PushPermission current;
  PushPermission answer;
  int asked = 0;
  int refreshed = 0;
  final pushes = StreamController<ForegroundPush>.broadcast();
  _Service(this.current, {this.answer = PushPermission.granted});

  @override
  Future<PushPermission> permission() async => current;
  @override
  Future<PushPermission> enable() async {
    asked++;
    return current = answer;
  }

  @override
  Future<void> refresh() async => refreshed++;
  @override
  Stream<ForegroundPush> get foreground => pushes.stream;
}

Future<LocalCache> cache() async {
  SharedPreferences.setMockInitialValues({});
  return LocalCache(await SharedPreferences.getInstance());
}

void main() {
  test('after sign-in the card shows, but the browser is never asked by itself', () async {
    final s = _Service(PushPermission.notAsked);
    final cubit = PushCubit(s, cache: await cache());
    await cubit.start();
    expect(cubit.state.showPrompt, isTrue);
    expect(s.asked, 0);
    await cubit.close();
  });

  test('"Turn on" asks, saves the token and plays the chime for pushes while open', () async {
    final s = _Service(PushPermission.notAsked);
    final heard = <String>[];
    final cubit = PushCubit(s, cache: await cache(), onForeground: (p) => heard.add(p.title));
    await cubit.start();
    await cubit.enable();
    expect(s.asked, 1);
    expect(cubit.state.permission, PushPermission.granted);
    expect(cubit.state.showPrompt, isFalse);
    expect(cubit.state.message, 'Notifications are on.');
    s.pushes.add(const ForegroundPush('New guest assigned', 'Ada Obi'));
    await Future<void>.delayed(Duration.zero);
    expect(heard, ['New guest assigned']);
    await cubit.close();
  });

  test('"Not now" hides the card for two weeks, also after a restart', () async {
    final c = await cache();
    final cubit = PushCubit(_Service(PushPermission.notAsked), cache: c);
    await cubit.start();
    await cubit.snooze();
    expect(cubit.state.showPrompt, isFalse);
    await cubit.close();
    final again = PushCubit(_Service(PushPermission.notAsked), cache: c);
    await again.start();
    expect(again.state.showPrompt, isFalse);
    await again.close();
  });

  test('blocked notifications get a plain message; granted ones refresh the token silently', () async {
    final denied = PushCubit(_Service(PushPermission.notAsked, answer: PushPermission.denied), cache: await cache());
    await denied.start();
    await denied.enable();
    expect(denied.state.message, contains('browser settings'));
    await denied.close();

    final s = _Service(PushPermission.granted);
    final granted = PushCubit(s, cache: await cache());
    await granted.start();
    expect(s.refreshed, 1);
    expect(granted.state.showPrompt, isFalse);
    await granted.close();
  });

  test('no service (API mode or not the web): nothing shows', () async {
    final cubit = PushCubit(null);
    await cubit.start();
    expect(cubit.state.showPrompt, isFalse);
    await cubit.close();
  });
}
