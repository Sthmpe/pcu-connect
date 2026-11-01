import 'package:web/web.dart' as web;

/// Flutter web serves assets under assets/, so the asset path appears twice.
const _src = 'assets/assets/sounds/notify.wav';

web.HTMLAudioElement? _audio;

/// Plays the chime. Browsers may block sound until the person has tapped the
/// page once; then it is skipped quietly.
void playNotificationSound() {
  try {
    final audio = _audio ??= (web.HTMLAudioElement()
      ..src = _src
      ..preload = 'auto'
      ..volume = 0.8);
    audio.currentTime = 0;
    audio.play();
  } catch (_) {
    // No sound is better than an error.
  }
}
