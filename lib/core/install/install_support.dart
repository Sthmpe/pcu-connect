import 'install_support_stub.dart' if (dart.library.js_interop) 'install_support_web.dart' as impl;

enum InstallPlatform { iphone, android, other }

/// What the browser says about installing the app to the home screen.
abstract class InstallSupport {
  /// Only the web app can be added to the home screen this way.
  bool get isWeb;

  /// Already opened from the home screen (installed).
  bool get isStandalone;

  /// Chrome's own install prompt is available.
  bool get canPrompt;

  InstallPlatform get platform;

  /// Fires when the app is installed.
  Stream<void> get installed;

  /// Shows the browser's install prompt; true when the person accepted.
  Future<bool> prompt();

  factory InstallSupport() => impl.create();
}
