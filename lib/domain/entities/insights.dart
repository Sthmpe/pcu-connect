import 'package:equatable/equatable.dart';

int _int(dynamic v) => (v as num?)?.toInt() ?? 0;

/// One row of the monthly leaderboard (Apps Script `ranking`).
class RankingEntry extends Equatable {
  final String email;
  final String name;
  final int points;
  final int rank;

  const RankingEntry({
    required this.email,
    required this.name,
    required this.points,
    required this.rank,
  });

  factory RankingEntry.fromJson(Map<String, dynamic> json) => RankingEntry(
        email: json['email']?.toString() ?? '',
        name: json['name']?.toString() ?? '',
        points: _int(json['points']),
        rank: _int(json['rank']),
      );

  @override
  List<Object?> get props => [email, name, points, rank];
}

class Ranking extends Equatable {
  final String month;
  final List<RankingEntry> entries;
  final RankingEntry? me;

  const Ranking({required this.month, required this.entries, this.me});

  factory Ranking.fromJson(Map<String, dynamic> json) => Ranking(
        month: json['month']?.toString() ?? '',
        entries: (json['entries'] as List? ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(RankingEntry.fromJson)
            .toList(),
        me: json['me'] is Map<String, dynamic>
            ? RankingEntry.fromJson(json['me'] as Map<String, dynamic>)
            : null,
      );

  @override
  List<Object?> get props => [month, entries, me];
}

/// A month's ranking plus where each worker stood the month before.
class RankingView extends Equatable {
  final Ranking ranking;

  /// Email to rank in the previous month. Empty when unknown.
  final Map<String, int> previousRanks;

  const RankingView({required this.ranking, this.previousRanks = const {}});

  /// Places gained since last month (positive is up), or null when the
  /// worker was not ranked last month.
  int? movement(RankingEntry e) {
    final before = previousRanks[e.email];
    return before == null ? null : before - e.rank;
  }

  @override
  List<Object?> get props => [ranking, previousRanks];
}

class TopWorker extends Equatable {
  final String email;
  final String name;
  final int members;
  final int points;

  /// Calls logged in the month; null where the source does not say (Apps Script).
  final int? calls;

  const TopWorker({
    required this.email,
    required this.name,
    required this.members,
    required this.points,
    this.calls,
  });

  /// "40 pts · 5 calls · 1 member" (calls only when known).
  String get record => [
        '$points pts',
        if (calls != null) '$calls ${calls == 1 ? 'call' : 'calls'}',
        '$members ${members == 1 ? 'member' : 'members'}',
      ].join(' · ');

  factory TopWorker.fromJson(Map<String, dynamic> json) => TopWorker(
        email: json['email']?.toString() ?? '',
        name: json['name']?.toString() ?? '',
        members: _int(json['members']),
        points: _int(json['points']),
      );

  @override
  List<Object?> get props => [email, name, members, points, calls];
}

/// Church-wide numbers for one month (Apps Script `dashboard`).
class DashboardSummary extends Equatable {
  final String month;
  final int guests;
  final int called;
  final int members;
  final int inTeam;
  final int followUps;
  final List<TopWorker> topWorkers;

  const DashboardSummary({
    required this.month,
    required this.guests,
    required this.called,
    required this.members,
    required this.inTeam,
    required this.followUps,
    required this.topWorkers,
  });

  int get notCalled => guests - called;

  double get calledRate => guests == 0 ? 0 : called / guests;

  factory DashboardSummary.fromJson(Map<String, dynamic> json) {
    final totals = json['totals'] is Map<String, dynamic>
        ? json['totals'] as Map<String, dynamic>
        : const <String, dynamic>{};
    return DashboardSummary(
      month: json['month']?.toString() ?? '',
      guests: _int(totals['guests']),
      called: _int(totals['called']),
      members: _int(totals['members']),
      inTeam: _int(totals['inTeam']),
      followUps: _int(totals['followUps']),
      topWorkers: (json['topWorkers'] as List? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(TopWorker.fromJson)
          .toList(),
    );
  }

  @override
  List<Object?> get props =>
      [month, guests, called, members, inTeam, followUps, topWorkers];
}
