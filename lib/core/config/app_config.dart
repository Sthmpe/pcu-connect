import 'package:flutter/foundation.dart';

class AppConfig {
  /// Mock login buttons are shown only in debug builds, or in a build made
  /// with --dart-define=ENABLE_MOCK_LOGIN=true. The backend still refuses
  /// mock tokens unless its ALLOW_MOCK_TOKENS script property is "true".
  static const bool enableMockLogin =
      kDebugMode || bool.fromEnvironment('ENABLE_MOCK_LOGIN');

  /// Local sample data instead of the Apps Script API, for UI work only:
  /// --dart-define=USE_SAMPLE_DATA=true. Never set for a release build, so
  /// the sample repositories are compiled out of it.
  static const bool useSampleData = bool.fromEnvironment('USE_SAMPLE_DATA');

  /// Where guests are read and follow-ups saved: 'api' (Apps Script, the
  /// default) or 'firestore' (--dart-define=DATA_SOURCE=firestore). In
  /// Firestore mode follow-ups are saved straight to Firestore (phase 2) and
  /// reach the sheet with the nightly sync or the HOD's "Sync to sheet".
  static const String dataSource = String.fromEnvironment('DATA_SOURCE', defaultValue: 'api');

  static bool get useFirestore => dataSource == 'firestore' && !useSampleData;

  /// Today shows guests not yet called whose first visit is on or after this
  /// Lagos day: the day the app went live, the same rule as the 6pm reminder
  /// (GO_LIVE in backend/pcu_auto_assign.gs). Older guests were followed up
  /// in the sheet before the app existed.
  static const String chaseFrom = '2026-10-28';

  /// Public VAPID key for Firebase Cloud Messaging web push (project
  /// pcu-workflow). Public by design; a build can override it with
  /// `--dart-define=FCM_VAPID_KEY=...`.
  static const String fcmVapidKey = String.fromEnvironment(
    'FCM_VAPID_KEY',
    defaultValue:
        'BOP_wULolCBYKMhK7ibxnGTX6kxXnrOkbUjBsvpwLK8K5rOQwjjZ0fgXHq9RC40aq4eo0NP1NjCJMJEg5E-FZTo',
  );

  /// Short browser description saved with a push token, so a person can tell
  /// their devices apart. Empty off the web.
  static String get userAgent => _userAgent();
  static String Function() _userAgent = () => '';

  /// Set once at startup on the web (see main.dart).
  static set userAgentSource(String Function() source) => _userAgent = source;
}
