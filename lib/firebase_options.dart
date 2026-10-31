import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show kIsWeb;

/// Firebase configuration for the pcu-workflow project (web only).
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    throw UnsupportedError(
      'DefaultFirebaseOptions are only configured for web.',
    );
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyBcrUS4Y_vyj0Q5D9Xes9Mg96CExhN-E1Q',
    appId: '1:727373224836:web:abce1f0f5a3045a43cdbd1',
    messagingSenderId: '727373224836',
    projectId: 'pcu-workflow',
    authDomain: 'pcu-workflow.firebaseapp.com',
    storageBucket: 'pcu-workflow.firebasestorage.app',
    measurementId: 'G-5R3QJKRP3W',
  );
}
