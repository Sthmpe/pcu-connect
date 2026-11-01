import 'dart:async';
import 'package:flutter/foundation.dart';

/// What the sync chip watches besides connectivity (Firestore mode):
/// saves not yet confirmed by the server, and live lists still showing the
/// device copy while the server's answer (new assignments) is on its way.
class SyncSignals {
  final ValueNotifier<int> pendingWrites = ValueNotifier(0);
  final ValueNotifier<bool> receiving = ValueNotifier(false);
  final Map<Object, bool> _fromCache = {};

  /// [commit] completes when the server has the write.
  void trackWrite(Future<void> commit) {
    pendingWrites.value++;
    commit.catchError((Object _) {}).whenComplete(() => pendingWrites.value--);
  }

  /// A live list reports whether its latest snapshot came from the device copy.
  void listFromCache(Object key, bool fromCache) {
    _fromCache[key] = fromCache;
    receiving.value = _fromCache.values.any((v) => v);
  }

  /// A live list stopped listening.
  void listClosed(Object key) {
    _fromCache.remove(key);
    receiving.value = _fromCache.values.any((v) => v);
  }
}
