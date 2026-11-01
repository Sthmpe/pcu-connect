import 'dart:async';
import 'package:web/web.dart' as web;
import 'connectivity.dart';

Connectivity create() => _BrowserConnectivity();

class _BrowserConnectivity implements Connectivity {
  @override
  bool get online => web.window.navigator.onLine;

  @override
  Stream<bool> get changes => StreamGroupLite.merge([
        web.EventStreamProviders.onlineEvent.forTarget(web.window).map((_) => true),
        web.EventStreamProviders.offlineEvent.forTarget(web.window).map((_) => false),
      ]);
}

/// Merges a few broadcast streams (no extra package).
abstract class StreamGroupLite {
  static Stream<T> merge<T>(List<Stream<T>> streams) {
    late StreamController<T> c;
    final subs = <StreamSubscription<T>>[];
    c = StreamController<T>.broadcast(
      onListen: () {
        for (final s in streams) {
          subs.add(s.listen(c.add));
        }
      },
      onCancel: () {
        for (final s in subs) {
          s.cancel();
        }
        subs.clear();
      },
    );
    return c.stream;
  }
}
