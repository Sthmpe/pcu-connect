import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/errors/failures.dart';
import '../../core/network/api_result.dart';
import '../../core/utils/read_errors.dart';

/// One month on the twelve-month trend: guests who first came that month,
/// and how many of them are members now (as the Dashboard counts them).
class MonthCount {
  final String month; // 'yyyy-MM'
  final int guests;
  final int members;
  const MonthCount(this.month, this.guests, this.members);
}

abstract class ITrendRepository {
  /// [months] oldest first.
  Future<ApiResult<List<MonthCount>>> load(List<String> months);
}

/// Firestore count queries (admins can read every guest): two per month,
/// no guest documents downloaded.
class FirestoreTrendRepository implements ITrendRepository {
  final FirebaseFirestore _db;
  FirestoreTrendRepository(this._db);

  @override
  Future<ApiResult<List<MonthCount>>> load(List<String> months) async {
    try {
      final guests = _db.collection('guests');
      final counts = await Future.wait(months.map((m) async {
        final all = guests.where('month', isEqualTo: m);
        final results = await Future.wait([
          all.count().get(),
          all.where('membershipStatus', isEqualTo: 'Member').count().get(),
        ]);
        return MonthCount(m, results[0].count ?? 0, results[1].count ?? 0);
      }));
      return ApiResult.success(counts);
    } on FirebaseException catch (e) {
      logReadError('trend', e);
      return const ApiResult.failure(NetworkFailure('We could not load the last 12 months. Try again.'));
    }
  }
}
