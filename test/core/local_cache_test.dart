import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workflow/core/storage/local_cache.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late LocalCache cache;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    cache = LocalCache(prefs);
  });

  group('LocalCache', () {
    test('writes and reads cached entries scoped by email', () async {
      cache.setScope('david@example.com');
      await cache.write('guests.2026-10', [{'id': 'G1', 'name': 'Ada Obi'}]);

      final entry = cache.read('guests.2026-10');
      expect(entry, isNotNull);
      expect((entry!.data as List).length, 1);
      expect((entry.data as List).first['name'], 'Ada Obi');

      // Different user scope should not see this data
      cache.setScope('other@example.com');
      expect(cache.read('guests.2026-10'), isNull);
    });

    test('clearAll removes all pcu cache keys', () async {
      cache.setScope('david@example.com');
      await cache.write('key1', 'value1');

      cache.setScope('ruth@example.com');
      await cache.write('key2', 'value2');

      await cache.clearAll();

      cache.setScope('david@example.com');
      expect(cache.read('key1'), isNull);

      cache.setScope('ruth@example.com');
      expect(cache.read('key2'), isNull);
    });
  });
}
