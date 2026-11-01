import 'dart:async';
import 'package:flutter/widgets.dart';

/// Notices when the worker taps Call or WhatsApp, leaves the app, and comes
/// back, so the app can ask "How did the call go?" for that guest.
///
/// - Only a real leave counts: the app must be hidden or paused (the dialer
///   or WhatsApp in front). A dialog that only takes focus (inactive) is not
///   a leave, so a cancelled call never asks.
/// - The leave must start within [leaveWithin] of the tap; an old tap that
///   never opened anything is forgotten.
/// - One tap asks at most once.
class CallReturnWatcher {
  CallReturnWatcher({DateTime Function()? clock, this.leaveWithin = const Duration(seconds: 30)})
      : _clock = clock ?? DateTime.now;

  static final CallReturnWatcher instance = CallReturnWatcher();

  final DateTime Function() _clock;
  final Duration leaveWithin;
  final _returns = StreamController<String>.broadcast();

  String? _guestId;
  DateTime? _tappedAt;
  bool _left = false;

  /// The guest ID, once per tap, when the worker comes back.
  Stream<String> get returns => _returns.stream;

  /// Call or WhatsApp was tapped for [guestId]. A newer tap replaces an older one.
  void launched(String guestId) {
    _guestId = guestId;
    _tappedAt = _clock();
    _left = false;
  }

  /// The link could not be opened: nothing to ask about.
  void cancel() {
    _guestId = null;
    _tappedAt = null;
    _left = false;
  }

  void onLifecycle(AppLifecycleState state) {
    final id = _guestId;
    if (id == null) return;
    switch (state) {
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
        if (_left) return;
        if (_clock().difference(_tappedAt!) <= leaveWithin) {
          _left = true;
        } else {
          cancel();
        }
      case AppLifecycleState.resumed:
        if (!_left) return;
        cancel();
        _returns.add(id);
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
        break;
    }
  }
}
