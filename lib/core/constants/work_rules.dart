// The names below are the ones the church uses for these settings.
// ignore_for_file: constant_identifier_names

/// The worker's daily to-do list (Today). Every day count is in whole
/// Africa/Lagos calendar days. Changing a number here changes Today, the
/// Today tab badge, the daily goal ring and the HOD's "Needs attention".
abstract class WorkRules {
  /// A guest never called becomes Outstanding when more than this many days
  /// have passed since their first visit (3: day 3 is New, day 4 Outstanding).
  static const int OUTSTANDING_AFTER_DAYS = 3;

  /// After a call with no answer, try again once this many days have passed.
  static const int RETRY_AFTER_DAYS = 1;

  /// Stop asking for retries once a guest has had this many calls.
  static const int MAX_RETRIES = 3;

  /// A guest who was called is due another call after this many days without one.
  static const int FOLLOWUP_DUE_AFTER_DAYS = 7;

  /// The HOD's "Needs attention" counts a worker whose oldest outstanding guest
  /// has waited at least this many days.
  static const int ATTENTION_AFTER_DAYS = 7;

  /// Call outcomes that mean "no answer" for Retry: the person was not reached
  /// and trying again makes sense. "Wrong number" is not retried, "Reached"
  /// was answered, and "Not interested" is handled by its status.
  static const Set<String> NO_ANSWER_OUTCOMES = {'No answer', 'Busy', 'Switched off'};

  /// Statuses that never appear under Follow-up due.
  static const Set<String> NO_FOLLOWUP_STATUSES = {'Member', 'Not interested', 'Unreachable'};
}
