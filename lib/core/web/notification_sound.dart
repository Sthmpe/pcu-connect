// Plays the notification chime (assets/sounds/notify.wav) while the app is
// open. A no-op off the web. Web push cannot use a custom sound when the app
// is closed; the phone plays its own notification sound then.
export 'notification_sound_stub.dart' if (dart.library.js_interop) 'notification_sound_web.dart';
