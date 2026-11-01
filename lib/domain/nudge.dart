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

/// One logged nudge: the friendly one ('app': in-app, push, email) or WhatsApp.
class NudgeLog {
  final String worker;
  final DateTime at;
  final String channel;
  const NudgeLog({required this.worker, required this.at, required this.channel});

  bool get isWhatsApp => channel == 'whatsapp';
}

/// Recent nudges, newest first.
class NudgeHistory {
  final List<NudgeLog> logs;
  const NudgeHistory(this.logs);

  static const empty = NudgeHistory([]);

  /// The latest nudge to [email] on any channel ("Last nudged").
  NudgeLog? last(String email) {
    for (final l in logs) {
      if (l.worker == email) return l;
    }
    return null;
  }

  /// When [email] got the friendly nudge within the last 24 hours (one per 24 hours), else null.
  DateTime? friendlyWithin24h(String email, DateTime now) {
    for (final l in logs) {
      if (l.worker == email && !l.isWhatsApp && now.difference(l.at) < Nudge.every) return l.at;
    }
    return null;
  }
}
