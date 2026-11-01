/// The HOD's nudge to a worker with guests waiting (sent by Apps Script).
abstract class Nudge {
  static const title = 'A gentle nudge from your HOD';
  static const maxLine = 200;
  static const every = Duration(hours: 24);

  /// The default body for [n] waiting guests, as the backend sends it.
  static String body(int n) => 'You have $n ${n == 1 ? 'guest' : 'guests'} waiting for a call. '
      'A quick call today makes a big difference. We are cheering you on.';
}

/// What went out.
class NudgeResult {
  final bool inApp;
  final int pushSent;
  final bool emailSent;
  final DateTime? nextAt;
  const NudgeResult({required this.inApp, required this.pushSent, required this.emailSent, this.nextAt});

  /// "David will see it in the app and by email."
  String summary(String firstName) {
    final ways = [
      if (inApp) 'in the app',
      if (pushSent > 0) 'on their phone',
      if (emailSent) 'by email',
    ];
    if (ways.isEmpty) return 'Saved, but it could not be delivered. Try again later.';
    final joined = ways.length == 1 ? ways.first : '${ways.sublist(0, ways.length - 1).join(', ')} and ${ways.last}';
    return '$firstName will see it $joined.';
  }
}
