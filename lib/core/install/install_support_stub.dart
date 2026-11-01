import 'install_support.dart';

InstallSupport create() => _NoInstall();

class _NoInstall implements InstallSupport {
  @override
  bool get isWeb => false;
  @override
  bool get isStandalone => false;
  @override
  bool get canPrompt => false;
  @override
  InstallPlatform get platform => InstallPlatform.other;
  @override
  Stream<void> get installed => const Stream.empty();
  @override
  Future<bool> prompt() async => false;
}
