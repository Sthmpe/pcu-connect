import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'package:web/web.dart' as web;
import 'install_support.dart';

InstallSupport create() => _BrowserInstall();

/// Reads window.__pcuInstall, set up in web/index.html.
class _BrowserInstall implements InstallSupport {
  JSObject? get _state => web.window.getProperty<JSObject?>('__pcuInstall'.toJS);

  JSObject? get _promptEvent => _state?.getProperty<JSObject?>('prompt'.toJS);

  @override
  bool get isWeb => true;

  @override
  bool get isStandalone {
    final iosStandalone = web.window.navigator.getProperty<JSBoolean?>('standalone'.toJS)?.toDart ?? false;
    return iosStandalone ||
        web.window.matchMedia('(display-mode: standalone)').matches ||
        (_state?.getProperty<JSBoolean?>('installed'.toJS)?.toDart ?? false);
  }

  @override
  bool get canPrompt => _promptEvent != null;

  @override
  InstallPlatform get platform {
    final ua = web.window.navigator.userAgent;
    final touchMac = ua.contains('Macintosh') && web.window.navigator.maxTouchPoints > 1;
    if (RegExp('iPhone|iPad|iPod').hasMatch(ua) || touchMac) return InstallPlatform.iphone;
    if (ua.contains('Android')) return InstallPlatform.android;
    return InstallPlatform.other;
  }

  @override
  Stream<void> get installed => const web.EventStreamProvider<web.Event>('pcu-installed').forTarget(web.window);

  @override
  Future<bool> prompt() async {
    final event = _promptEvent;
    if (event == null) return false;
    try {
      event.callMethod<JSAny?>('prompt'.toJS);
      final choice = await event.getProperty<JSPromise<JSObject>>('userChoice'.toJS).toDart;
      final accepted = choice.getProperty<JSString?>('outcome'.toJS)?.toDart == 'accepted';
      // The offer can be used once.
      _state?.setProperty('prompt'.toJS, null);
      return accepted;
    } catch (_) {
      return false;
    }
  }
}
