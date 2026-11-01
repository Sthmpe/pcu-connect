import 'connectivity_stub.dart' if (dart.library.js_interop) 'connectivity_web.dart' as impl;

/// Whether the device is online. On the web it follows the browser's online
/// and offline events; elsewhere it always reports online.
abstract class Connectivity {
  bool get online;
  Stream<bool> get changes;

  factory Connectivity() => impl.create();
}
