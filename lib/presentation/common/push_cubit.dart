import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/storage/local_cache.dart';
import '../../data/firestore/push_service.dart';

class PushState extends Equatable {
  final PushPermission permission;

  /// The person chose "Not now" recently.
  final bool snoozed;
  final bool busy;
  final String? message;

  const PushState({
    this.permission = PushPermission.unsupported,
    this.snoozed = false,
    this.busy = false,
    this.message,
  });

  /// Ask politely only when the browser has not asked yet.
  bool get showPrompt => permission == PushPermission.notAsked && !snoozed;

  PushState copyWith({PushPermission? permission, bool? snoozed, bool? busy, String? message}) => PushState(
        permission: permission ?? this.permission,
        snoozed: snoozed ?? this.snoozed,
        busy: busy ?? this.busy,
        message: message,
      );

  @override
  List<Object?> get props => [permission, snoozed, busy, message];
}

/// Web push after sign-in: the polite prompt, the device token, and pushes
/// that arrive while the app is open ([onForeground] plays the chime).
class PushCubit extends Cubit<PushState> {
  final IPushService? _service;
  final LocalCache? _cache;
  final void Function(ForegroundPush push)? onForeground;
  StreamSubscription<ForegroundPush>? _sub;

  static const snoozeKey = 'push.snoozedAt';
  static const snoozeFor = Duration(days: 14);

  PushCubit(this._service, {LocalCache? cache, this.onForeground})
      : _cache = cache,
        super(const PushState());

  /// Called by the signed-in shells. Never asks the browser by itself.
  Future<void> start() async {
    final service = _service;
    if (service == null) return;
    final permission = await service.permission();
    if (isClosed) return;
    final snoozedAt = _cache?.read(snoozeKey);
    emit(state.copyWith(
      permission: permission,
      snoozed: snoozedAt != null && snoozedAt.isFresherThan(snoozeFor),
    ));
    if (permission == PushPermission.granted) {
      unawaited(service.refresh());
      _sub ??= service.foreground.listen((p) => onForeground?.call(p));
    }
  }

  /// "Turn on": the browser asks now, because the person chose to.
  Future<void> enable() async {
    final service = _service;
    if (service == null || state.busy) return;
    emit(state.copyWith(busy: true));
    final permission = await service.enable();
    if (isClosed) return;
    emit(state.copyWith(
      permission: permission,
      busy: false,
      message: switch (permission) {
        PushPermission.granted => 'Notifications are on.',
        PushPermission.denied => 'Notifications are blocked. You can allow them in your browser settings.',
        _ => null,
      },
    ));
    if (permission == PushPermission.granted) {
      _sub ??= service.foreground.listen((p) => onForeground?.call(p));
    }
  }

  /// "Not now": hide the card for two weeks.
  Future<void> snooze() async {
    await _cache?.write(snoozeKey, true);
    if (!isClosed) emit(state.copyWith(snoozed: true));
  }

  @override
  Future<void> close() async {
    await _sub?.cancel();
    return super.close();
  }
}
