import 'package:equatable/equatable.dart';
import 'package:intl/intl.dart';
import '../../core/utils/lagos_time.dart';

/// meta/sync in Firestore: when work last reached the sheet and how it went.
class SheetSyncStatus extends Equatable {
  final DateTime? lastSyncedAt;
  final bool running;

  /// False when the last run stopped with an error.
  final bool lastOk;
  final String? lastError;

  /// For "Open the sheet" (SHEET_URL Script Property, shared by Apps Script); '' when not known.
  final String sheetUrl;

  const SheetSyncStatus({
    this.lastSyncedAt,
    this.running = false,
    this.lastOk = true,
    this.lastError,
    this.sheetUrl = '',
  });

  /// "Last synced: today 12:05 AM", in Lagos time.
  String line([DateTime? clock]) {
    final at = lastSyncedAt;
    if (at == null) return 'Not synced to the sheet yet';
    final day = LagosTime.day(at);
    final today = LagosTime.today(clock);
    final time = DateFormat('h:mm a').format(at.toUtc().add(LagosTime.offset));
    if (day == today) return 'Last synced: today $time';
    if (LagosTime.daysBetween(day, today) == 1) return 'Last synced: yesterday $time';
    return 'Last synced: ${DateFormat('d MMM').format(at.toUtc().add(LagosTime.offset))}, $time';
  }

  /// For the Dashboard banner: "Sheet is a day behind. Sync now." when the
  /// last sync was 24 hours ago or more, otherwise null.
  String? behind([DateTime? clock]) {
    final at = lastSyncedAt;
    if (at == null) return null;
    final hours = (clock ?? DateTime.now()).difference(at).inHours;
    if (hours < 24) return null;
    final days = hours ~/ 24;
    return days == 1 ? 'Sheet is a day behind. Sync now.' : 'Sheet is $days days behind. Sync now.';
  }

  /// A gentle warning when the sheet is more than a day behind, otherwise null.
  String? warning([DateTime? clock]) {
    if (!lastOk) return 'The last sync did not finish. Try again.';
    final at = lastSyncedAt;
    if (at == null) return 'Sync now to copy saved work to the sheet.';
    final hours = (clock ?? DateTime.now()).difference(at).inHours;
    if (hours < 24) return null;
    final days = hours ~/ 24;
    return days == 1 ? 'Sheet is a day behind. Sync now.' : 'Sheet is $days days behind. Sync now.';
  }

  @override
  List<Object?> get props => [lastSyncedAt, running, lastOk, lastError, sheetUrl];
}

/// What one "Sync to sheet" did.
class SheetSyncResult extends Equatable {
  final int followUps;

  /// Guest rows updated in the sheet.
  final int guests;

  /// Distinct guests of the follow-ups just added.
  final int followUpGuests;

  final String sheetUrl;

  const SheetSyncResult({required this.followUps, required this.guests, this.followUpGuests = 0, this.sheetUrl = ''});

  static String _n(int n, String one) => '$n ${n == 1 ? one : '${one}s'}';

  /// "Synced 6 follow-ups for 4 guests".
  String get message {
    if (guests == 0 && followUps == 0) return 'The sheet is up to date.';
    if (followUps == 0) return 'Synced ${_n(guests, 'guest')}';
    if (followUpGuests == 0) return 'Synced ${_n(followUps, 'follow-up')}';
    return 'Synced ${_n(followUps, 'follow-up')} for ${_n(followUpGuests, 'guest')}';
  }

  @override
  List<Object?> get props => [followUps, guests, followUpGuests, sheetUrl];
}
