import 'package:equatable/equatable.dart';

/// One saved follow-up, from the `history` of the Apps Script `guest` action.
class FollowUpEntry extends Equatable {
  final String id;
  final String date; // yyyy-MM-dd
  final String outcome;
  final String note;
  final bool attendedSunday;
  final bool attendedWednesday;
  final String team;
  final String workerName;
  final String loggedByName;

  /// True when an admin saved it on behalf of the assigned worker.
  final bool loggedByAdmin;

  const FollowUpEntry({
    required this.id,
    required this.date,
    required this.outcome,
    required this.note,
    required this.attendedSunday,
    required this.attendedWednesday,
    required this.team,
    required this.workerName,
    required this.loggedByName,
    required this.loggedByAdmin,
  });

  factory FollowUpEntry.fromJson(Map<String, dynamic> json) => FollowUpEntry(
        id: json['id']?.toString() ?? '',
        date: json['date']?.toString() ?? '',
        outcome: json['outcome']?.toString() ?? '',
        note: json['note']?.toString() ?? '',
        attendedSunday: json['attendedSunday'] == true,
        attendedWednesday: json['attendedWednesday'] == true,
        team: json['team']?.toString() ?? '',
        workerName: json['workerName']?.toString() ?? '',
        loggedByName: json['loggedByName']?.toString() ?? '',
        loggedByAdmin: json['loggedByAdmin'] == true,
      );

  @override
  List<Object?> get props => [
        id, date, outcome, note, attendedSunday, attendedWednesday, team,
        workerName, loggedByName, loggedByAdmin,
      ];
}
