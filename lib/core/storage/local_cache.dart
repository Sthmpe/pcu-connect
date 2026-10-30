import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// A cached JSON payload and the time it was saved.
class CachedEntry {
  const CachedEntry({required this.data, required this.savedAt});
  final Object? data;
  final DateTime savedAt;

  bool isFresherThan(Duration maxAge) =>
      DateTime.now().difference(savedAt) < maxAge;
}

/// Saves the last successful API responses on the device so screens open
/// instantly and still show something when the connection drops.
///
/// Keys are scoped to the signed-in email so two people sharing a browser
/// never see each other's data.
class LocalCache {
  LocalCache(this._prefs);

  final SharedPreferences _prefs;
  static const String _prefix = 'pcu.cache.';
  String _scope = 'anonymous';

  void setScope(String email) => _scope = email.trim().toLowerCase();

  String _key(String key) => '$_prefix$_scope.$key';

  CachedEntry? read(String key) {
    final raw = _prefs.getString(_key(key));
    if (raw == null) return null;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      final savedAt = DateTime.tryParse(map['savedAt'] as String? ?? '');
      if (savedAt == null) return null;
      return CachedEntry(data: map['data'], savedAt: savedAt);
    } on Object {
      return null;
    }
  }

  Future<void> write(String key, Object? data) async {
    final payload = jsonEncode({
      'savedAt': DateTime.now().toIso8601String(),
      'data': data,
    });
    await _prefs.setString(_key(key), payload);
  }

  /// Removes every cached response for every user.
  Future<void> clearAll() async {
    final keys = _prefs.getKeys().where((k) => k.startsWith(_prefix)).toList();
    for (final key in keys) {
      await _prefs.remove(key);
    }
  }
}
