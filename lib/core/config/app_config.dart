import 'package:flutter/foundation.dart';

class AppConfig {
  /// Mock login buttons are shown only in debug builds, or in a build made
  /// with --dart-define=ENABLE_MOCK_LOGIN=true. The backend still refuses
  /// mock tokens unless its ALLOW_MOCK_TOKENS script property is "true".
  static const bool enableMockLogin =
      kDebugMode || bool.fromEnvironment('ENABLE_MOCK_LOGIN');
}
