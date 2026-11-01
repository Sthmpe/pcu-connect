import 'dart:js_interop';
import 'dart:js_interop_unsafe';

/// Waits for window.pcuFirebaseReady (set in web/index.html). If it is missing
/// or failed, FlutterFire loads the SDK from its CDN as usual.
Future<void> waitForBundledFirebase() async {
  final ready = globalContext.getProperty<JSAny?>('pcuFirebaseReady'.toJS);
  if (ready == null || !ready.isA<JSPromise>()) return;
  try {
    await (ready as JSPromise).toDart;
  } catch (_) {
    // The SDK did not load from this site; the CDN fallback takes over.
  }
}
