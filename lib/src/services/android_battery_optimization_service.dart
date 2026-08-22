import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class AndroidBatteryOptimizationService {
  AndroidBatteryOptimizationService._();

  static final AndroidBatteryOptimizationService instance =
      AndroidBatteryOptimizationService._();

  static const MethodChannel _channel =
      MethodChannel('android_battery_optimization');

  Future<bool> isIgnoring() async {
    if (!Platform.isAndroid) {
      return true;
    }
    try {
      final result = await _channel.invokeMethod<bool>('isIgnoring');
      return result ?? false;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('AndroidBatteryOptimization: isIgnoring failed ($e)');
      }
      return false;
    }
  }

  Future<bool> requestIgnore() async {
    if (!Platform.isAndroid) {
      return true;
    }
    try {
      final result = await _channel.invokeMethod<bool>('requestIgnore');
      return result ?? false;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('AndroidBatteryOptimization: requestIgnore failed ($e)');
      }
      return false;
    }
  }

  Future<void> openBatterySettings() async {
    if (!Platform.isAndroid) {
      return;
    }
    try {
      await _channel.invokeMethod<void>('openBatterySettings');
    } catch (e) {
      if (kDebugMode) {
        debugPrint('AndroidBatteryOptimization: open settings failed ($e)');
      }
    }
  }
}
