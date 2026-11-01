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

  const SheetSyncStatus({
    this.lastSyncedAt,
    this.running = false,
    this.lastOk = true,
    this.lastError,
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
  List<Object?> get props => [lastSyncedAt, running, lastOk, lastError];
}

/// What one "Sync to sheet" did.
class SheetSyncResult extends Equatable {
  final int followUps;
  final int guests;

  const SheetSyncResult({required this.followUps, required this.guests});

  String get message {
    if (guests == 0 && followUps == 0) return 'The sheet is up to date.';
    if (guests == 0) return 'Synced $followUps ${followUps == 1 ? 'follow-up' : 'follow-ups'}';
    return 'Synced $guests ${guests == 1 ? 'guest' : 'guests'}';
  }

  @override
  List<Object?> get props => [followUps, guests];
}
