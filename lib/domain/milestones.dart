import 'entities/guest_entity.dart';

/// Celebrations: a guest becoming a member through the worker's follow-ups.
abstract class Milestones {
  static const member = 'Member';

  /// This save made the guest a member.
  static bool becameMember({required String before, required String after}) => before != member && after == member;

  /// The worker's guests who became members in [month] ('yyyy-MM', Lagos).
  static int membersHelped(Iterable<GuestEntity> guests, String month) =>
      guests.where((g) => g.status == member && g.memberSince.startsWith(month)).length;

  /// "You helped 3 guests become members".
  static String helpedLine(int n) =>
      n == 1 ? 'You helped 1 guest become a member' : 'You helped $n guests become members';
}
