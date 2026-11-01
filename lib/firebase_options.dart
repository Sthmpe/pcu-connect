import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show TargetPlatform, defaultTargetPlatform, kIsWeb;

/// Firebase configuration for the pcu-workflow project: web and Android
/// (from android/app/google-services.json). iOS is not registered yet; see
/// docs/MOBILE.md (run flutterfire configure after registering it).
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    if (defaultTargetPlatform == TargetPlatform.android) return android;
    throw UnsupportedError(
      'Firebase is not set up for this platform yet. See docs/MOBILE.md.',
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

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCBklqK3Gz7p7uOYZdWWomsW604tJtin1M',
    appId: '1:727373224836:android:5b6060542cf9a8983cdbd1',
    messagingSenderId: '727373224836',
    projectId: 'pcu-workflow',
    storageBucket: 'pcu-workflow.firebasestorage.app',
  );
}
