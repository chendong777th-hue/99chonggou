import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:vibration/vibration.dart';

/// 应用内消息提示震动（Android 马达 / iOS 系统震动）。
class InAppNotificationVibration {
  InAppNotificationVibration._();

  static int _lastVibratedAtMs = 0;

  /// 双短震，贴近常见 IM 新消息体感。
  static Future<void> playMessageReceived() async {
    if (kIsWeb) {
      return;
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastVibratedAtMs < 800) {
      return;
    }
    _lastVibratedAtMs = now;

    try {
      final hasVibrator = await Vibration.hasVibrator();
      if (hasVibrator != true) {
        await _fallbackHaptic();
        return;
      }

      if (defaultTargetPlatform == TargetPlatform.android) {
        await Vibration.vibrate(pattern: [0, 80, 100, 80]);
        return;
      }

      if (defaultTargetPlatform == TargetPlatform.iOS) {
        await Vibration.vibrate(duration: 400);
        return;
      }

      await Vibration.vibrate(duration: 200);
    } catch (error, stack) {
      if (kDebugMode) {
        debugPrint('InAppNotificationVibration fallback: $error\n$stack');
      }
      await _fallbackHaptic();
    }
  }

  static Future<void> _fallbackHaptic() async {
    await HapticFeedback.heavyImpact();
    await Future<void>.delayed(const Duration(milliseconds: 100));
    await HapticFeedback.heavyImpact();
  }
}
