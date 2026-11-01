import 'package:flutter/foundation.dart';

/// Logs a failed read to the console (the browser console on the web) with
/// where it happened, so a friendly "Try again" on screen still leaves a
/// technical trail.
void logReadError(String where, Object error, [StackTrace? stack]) {
  debugPrint('PCU read failed [$where]: $error');
  if (stack != null) debugPrint(stack.toString());
}
