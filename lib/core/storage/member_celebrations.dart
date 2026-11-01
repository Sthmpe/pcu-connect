import 'package:shared_preferences/shared_preferences.dart';

/// Guests whose "became a member" moment was already celebrated on this
/// device, so the confetti plays once per guest.
class MemberCelebrations {
  static const key = 'pcu.celebrated.members';
  final SharedPreferences _prefs;

  MemberCelebrations(this._prefs);

  /// True the first time for [guestId]; remembers it.
  Future<bool> claim(String guestId) async {
    final seen = _prefs.getStringList(key) ?? const [];
    if (seen.contains(guestId)) return false;
    await _prefs.setStringList(key, [...seen, guestId]);
    return true;
  }
}
