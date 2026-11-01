import 'connectivity.dart';

Connectivity create() => _AlwaysOnline();

class _AlwaysOnline implements Connectivity {
  @override
  bool get online => true;

  @override
  Stream<bool> get changes => const Stream.empty();
}
