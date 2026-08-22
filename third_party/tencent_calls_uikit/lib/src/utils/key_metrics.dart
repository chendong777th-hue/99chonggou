import 'dart:convert';
import 'dart:io';

import 'package:tencent_calls_uikit/debug/generate_test_user_sig.dart';
import 'package:tencent_calls_uikit/src/call_engine.dart';
import 'package:tencent_calls_uikit/src/data/constants.dart';
import 'package:tencent_calls_uikit/src/impl/call_manager.dart';
import 'package:tencent_calls_uikit/src/impl/call_state.dart';
import 'package:tencent_calls_uikit/src/platform/call_engine_platform_interface.dart';
import 'package:tencent_calls_uikit/src/platform/call_kit_platform_interface.dart';
import 'package:tencent_calls_uikit/src/utils/permission.dart';
import 'package:tencent_cloud_chat_sdk/tencent_im_sdk_plugin.dart';

class KeyMetrics {
  static const String _tag = "KeyMetrics";
  static const String _apiReportRoomEngineEvent = "internal_operation_report_room_engine_event";

  static bool _hasPendingWakeup = false;

  static void countUV(EventId eventId, {String callId = ""}) {
    switch (eventId) {
      case EventId.received:
        _hasPendingWakeup = true;
        _countEvent(eventId, callId: callId);
        break;
      case EventId.wakeup:
        if (_hasPendingWakeup) {
          _hasPendingWakeup = false;
          _countEvent(eventId, callId: callId);
        }
        break;
      case EventId.wakeupByPush:
        _countEvent(eventId, callId: callId);
        break;
    }
  }

  static void reset() {
    _hasPendingWakeup = false;
  }

  static void _countEvent(EventId eventId, {String callId = ""}) async {
    try {
      final extensionJson = await _buildExtensionJson(callId: callId);
      final payload = _buildEventPayload(eventId, jsonEncode(extensionJson));

      TencentImSDKPlugin.v2TIMManager.callExperimentalAPI(
        api: _apiReportRoomEngineEvent,
        param: payload,
      );
    } catch (e) {
      print('$_tag: countUV exception: eventId=$eventId, error=$e');
    }
  }

  static Future<Map<String, dynamic>> _buildExtensionJson({String callId = ""}) async {
    return {
      // Basic Info
      JsonKeys.callId: callId,
      JsonKeys.intRoomId: CallState.instance.roomId.intRoomId ?? 0,
      JsonKeys.strRoomId: CallState.instance.roomId.strRoomId ?? "",
      JsonKeys.uiKitVersion: Constants.pluginVersion,
      // Platform Info
      JsonKeys.platform: Platform.isAndroid ? "android" : "ios",
      JsonKeys.framework: 7,
      JsonKeys.deviceBrand: _getDeviceBrand(),
      JsonKeys.deviceModel: _getDeviceModel(),
      JsonKeys.androidVersion: Platform.isAndroid ? _getAndroidVersion() : "",
      JsonKeys.isForeground: await _isAppInForeground(),
      JsonKeys.isScreenLocked: await _isScreenLocked(),
      JsonKeys.hasFloatingWindowPermission: await _hasFloatingWindowPermission(),
      JsonKeys.hasBackgroundLaunchPermission: _hasBackgroundLaunchPermission(),
      JsonKeys.hasNotificationPermission: await _hasNotificationPermission()
    };
  }

  static Future<bool> _isAppInForeground() async {
    return await TUICallKitPlatform.instance.isAppInForeground();
  }

  static Future<bool> _isScreenLocked() async {
    return await TUICallKitPlatform.instance.isScreenLocked();
  }

  static Future<bool> _hasNotificationPermission() async {
    try {
      return await TUICallKitPlatform.instance.isNotificationEnabled();
    } catch (e) {
      print('$_tag: check notification permission exception: $e');
      return false;
    }
  }

  static Map<String, dynamic> _buildEventPayload(EventId eventId, String extensionMessage) {
    String prefix = "report_room_engine_event_param_";
    return {
      prefix + JsonKeys.eventId: eventId.value(),
      prefix + JsonKeys.eventCode: 0,
      prefix + JsonKeys.eventResult: 0,
      prefix + JsonKeys.eventMessage: Constants.pluginVersion,
      prefix + JsonKeys.moreMessage: "",
      prefix + JsonKeys.extensionMessage: extensionMessage
    };
  }

  static int _getSdkAppId() {
    return CallManager.instance.sdkAppId;
  }

  static String _getDeviceBrand() {
    if (Platform.isAndroid) {
      return Platform.environment['BRAND'] ?? 'Unknown';
    } else if (Platform.isIOS) {
      return 'Apple';
    }
    return 'Unknown';
  }

  static String _getDeviceModel() {
    if (Platform.isAndroid) {
      return Platform.environment['MODEL'] ?? 'Unknown';
    } else if (Platform.isIOS) {
      return 'iPhone';
    }
    return 'Unknown';
  }

  static String _getAndroidVersion() {
    if (Platform.isAndroid) {
      return Platform.environment['VERSION.RELEASE'] ?? 'Unknown';
    }
    return '';
  }

  static bool _hasBackgroundLaunchPermission() {
    return false;
  }

  static Future<bool> _hasFloatingWindowPermission() async {
    return false;
  }
}

enum EventId {
  received,
  wakeup,
  wakeupByPush,
}

const _EventIdEnumMap = {
  EventId.received: 171010,
  EventId.wakeup: 171011,
  EventId.wakeupByPush: 171012,
};

extension EventIdExt on EventId {
  int value() {
    return _EventIdEnumMap[this]!;
  }
}

class JsonKeys {
  // Event Payload Keys
  static const String eventId = "event_id";
  static const String eventCode = "event_code";
  static const String eventResult = "event_result";
  static const String eventMessage = "event_message";
  static const String moreMessage = "more_message";
  static const String extensionMessage = "extension_message";

  // Basic Info Keys
  static const String callId = "call_id";
  static const String intRoomId = "int_room_id";
  static const String strRoomId = "str_room_id";
  static const String uiKitVersion = "ui_kit_version";

  // Platform Info Keys
  static const String platform = "platform";
  static const String framework = "framework";
  static const String deviceBrand = "device_brand";
  static const String deviceModel = "device_model";
  static const String androidVersion = "android_version";
  static const String isForeground = "is_foreground";
  static const String isScreenLocked = "is_screen_locked";
  static const String hasFloatingWindowPermission = "has_floating_window_permission";
  static const String hasBackgroundLaunchPermission = "has_background_launch_permission";
  static const String hasNotificationPermission = "has_notification_permission";
}