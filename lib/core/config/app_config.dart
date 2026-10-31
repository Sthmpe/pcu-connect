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
}
