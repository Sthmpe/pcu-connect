import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/firestore/notifications_repository.dart';
import '../../domain/entities/app_notification.dart';

class NotificationsState extends Equatable {
  final bool available;
  final bool loaded;
  final List<AppNotification> items;

  const NotificationsState({this.available = false, this.loaded = false, this.items = const []});

  int get unread => items.where((n) => !n.read).length;

  @override
  List<Object?> get props => [available, loaded, items];
}

/// The bell: a live list of the signed-in person's notifications.
class NotificationsCubit extends Cubit<NotificationsState> {
  final INotificationsRepository? _repo;
  StreamSubscription<List<AppNotification>>? _sub;

  NotificationsCubit(this._repo) : super(const NotificationsState());

  /// Called by the signed-in shells.
  void start() {
    final repo = _repo;
    if (repo == null || _sub != null) return;
    emit(const NotificationsState(available: true));
    _sub = repo.watch().listen(
          (items) => emit(NotificationsState(available: true, loaded: true, items: items)),
          // Keep what is shown; the bell just stops updating.
          onError: (_) {},
        );
  }

  /// Opening the list marks everything in it as read.
  Future<void> markAllRead() async {
    if (state.unread == 0) return;
    try {
      await _repo?.markAllRead();
    } catch (_) {
      // Stays unread; it is tried again next time the list opens.
    }
  }

  /// After sign-out, so the next person never sees these.
  Future<void> stop() async {
    await _sub?.cancel();
    _sub = null;
    if (!isClosed) emit(const NotificationsState());
  }

  @override
  Future<void> close() async {
    await _sub?.cancel();
    return super.close();
  }
}
