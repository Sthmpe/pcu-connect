import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:workflow/data/firestore/notifications_repository.dart';
import 'package:workflow/domain/entities/app_notification.dart';
import 'package:workflow/presentation/common/notifications_cubit.dart';
import 'package:workflow/presentation/common/notifications_screen.dart';

class _Repo implements INotificationsRepository {
  final items = StreamController<List<AppNotification>>.broadcast();
  int marked = 0;
  @override
  Stream<List<AppNotification>> watch() => items.stream;
  @override
  Future<void> markAllRead() async => marked++;
}

void main() {
  test('unread count, live list, mark all read on open, cleared on sign-out', () async {
    final repo = _Repo();
    final cubit = NotificationsCubit(repo);
    expect(cubit.state.available, isFalse);
    cubit.start();
    expect(cubit.state.available, isTrue);
    repo.items.add(const [
      AppNotification(id: 'a', title: 'New guest for you', body: 'Ada Obi', tag: 'guest-G-1A2B'),
      AppNotification(id: 'b', title: '3 guests are waiting for your call', body: '', tag: 'daily-reminder', read: true),
    ]);
    await Future<void>.delayed(Duration.zero);
    expect(cubit.state.unread, 1);
    expect(cubit.state.items.first.guestId, 'G-1A2B');
    await cubit.markAllRead();
    expect(repo.marked, 1);
    await cubit.stop();
    expect(cubit.state.available, isFalse);
    expect(cubit.state.items, isEmpty);
    await cubit.close();
  });

  test('nothing to mark when all are read; no repository means no bell', () async {
    final repo = _Repo();
    final cubit = NotificationsCubit(repo)..start();
    repo.items.add(const [AppNotification(id: 'a', title: 'x', body: '', read: true)]);
    await Future<void>.delayed(Duration.zero);
    await cubit.markAllRead();
    expect(repo.marked, 0);
    await cubit.close();
    final none = NotificationsCubit(null)..start();
    expect(none.state.available, isFalse);
    await none.close();
  });

  test('document mapping and times', () {
    final n = NotificationsRepository.fromDoc('x', {'title': 'Sheet sync did not finish', 'tag': 'sync-failed', 'read': false, 'createdAt': DateTime.utc(2026, 11, 1, 8)});
    expect(n.read, isFalse);
    expect(n.guestId, isNull);
    final clock = DateTime.utc(2026, 11, 1, 9); // 10:00 Lagos
    expect(timeAgo(DateTime.utc(2026, 11, 1, 8, 59, 30), clock), 'Just now');
    expect(timeAgo(DateTime.utc(2026, 11, 1, 8, 40), clock), '20 min ago');
    expect(timeAgo(DateTime.utc(2026, 11, 1, 6), clock), '3 h ago');
    expect(timeAgo(DateTime.utc(2026, 10, 31, 12), clock), 'Yesterday');
    expect(timeAgo(DateTime.utc(2026, 10, 20, 12), clock), '20 Oct');
  });
}
