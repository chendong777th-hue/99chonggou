import 'dart:io';

import 'package:flutter/services.dart';

/// Opens system cast / AirPlay UI for group live playback.
class GroupLiveCastService {
  GroupLiveCastService._();

  static const MethodChannel _channel = MethodChannel('group_live_cast');

  static Future<bool> openCastPicker() async {
    if (Platform.isIOS) {
      // iOS uses embedded AVRoutePickerView; nothing to open here.
      return true;
    }
    if (!Platform.isAndroid) {
      return false;
    }
    try {
      final result = await _channel.invokeMethod<bool>('openCastSettings');
      return result ?? false;
    } catch (_) {
      return false;
    }
  }
}
