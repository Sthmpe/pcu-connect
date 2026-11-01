// Waits for the Firebase JS SDK that web/index.html loads from this site, so
// FlutterFire does not fetch it from www.gstatic.com. A no-op off the web.
export 'bundled_firebase_stub.dart' if (dart.library.js_interop) 'bundled_firebase_web.dart';
