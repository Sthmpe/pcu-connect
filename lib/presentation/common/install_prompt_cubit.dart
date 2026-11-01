import 'dart:async';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/install/install_support.dart';

class InstallPromptState extends Equatable {
  final bool show;
  final bool canPrompt;
  final InstallPlatform platform;
  final bool busy;

  const InstallPromptState({
    this.show = false,
    this.canPrompt = false,
    this.platform = InstallPlatform.other,
    this.busy = false,
  });

  @override
  List<Object?> get props => [show, canPrompt, platform, busy];
}

/// The "Add to Home Screen" card: web only, not when already opened from the
/// home screen, shown after the first successful save on this device, and
/// gone for good once dismissed or installed. Both flags are per device.
class InstallPromptCubit extends Cubit<InstallPromptState> {
  static const readyKey = 'pcu.install.afterFirstSave';
  static const doneKey = 'pcu.install.done';

  final SharedPreferences _prefs;
  final InstallSupport _support;
  StreamSubscription<void>? _installed;

  InstallPromptCubit({required SharedPreferences prefs, required InstallSupport support})
      : _prefs = prefs,
        _support = support,
        super(const InstallPromptState()) {
    _installed = _support.installed.listen((_) => _finish());
    _refresh();
  }

  bool get _eligible =>
      _support.isWeb &&
      !_support.isStandalone &&
      (_prefs.getBool(readyKey) ?? false) &&
      !(_prefs.getBool(doneKey) ?? false);

  void _refresh() {
    if (isClosed) return;
    emit(InstallPromptState(show: _eligible, canPrompt: _support.canPrompt, platform: _support.platform));
  }

  /// A follow-up was saved: the card may appear from now on.
  Future<void> saved() async {
    if (_prefs.getBool(readyKey) ?? false) return;
    await _prefs.setBool(readyKey, true);
    _refresh();
  }

  /// "Not now": never shown again on this device.
  Future<void> dismiss() => _finish();

  /// The browser's own install prompt (Chrome on Android).
  Future<void> install() async {
    if (!_support.canPrompt) return;
    emit(InstallPromptState(show: true, canPrompt: true, platform: state.platform, busy: true));
    final accepted = await _support.prompt();
    if (accepted) {
      await _finish();
    } else {
      _refresh();
    }
  }

  Future<void> _finish() async {
    await _prefs.setBool(doneKey, true);
    _refresh();
  }

  @override
  Future<void> close() async {
    await _installed?.cancel();
    return super.close();
  }
}
