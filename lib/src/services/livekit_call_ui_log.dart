import 'package:flutter/foundation.dart';

/// Always-on LiveKit call UI diagnostics (works in profile/release too).
///
/// Prefer this over `kDebugMode` + `debugPrint` when diagnosing missing call UI.
void liveKitCallUiLog(String message) {
  // ignore: avoid_print — must surface in Xcode console for profile/release runs
  print('[LK_CALL_UI] $message');
  if (kDebugMode) {
    debugPrint('[LK_CALL_UI] $message');
  }
}
