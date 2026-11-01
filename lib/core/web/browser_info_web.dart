import 'package:web/web.dart' as web;

/// Trimmed so a token document stays small.
String browserUserAgent() {
  final ua = web.window.navigator.userAgent;
  return ua.length > 300 ? ua.substring(0, 300) : ua;
}
