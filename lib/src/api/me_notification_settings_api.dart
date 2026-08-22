import 'package:dio/dio.dart';

import 'package:tencent_cloud_chat_demo/src/models/notification_display_mode.dart';
import 'package:tencent_cloud_chat_demo/utils/api_response_util.dart';

import 'api_client.dart';

class MeNotificationSettingsApi {
  MeNotificationSettingsApi._();

  static final MeNotificationSettingsApi instance = MeNotificationSettingsApi._();

  Dio get _dio => ApiClient.instance.dio;

  Future<MeNotificationSettings> fetch() async {
    final res = await _dio.get('/me/notification-settings');
    return MeNotificationSettings.fromJson(_payloadMap(res.data));
  }

  Future<MeNotificationSettings> update({
    bool? systemMessageNotificationEnabled,
    bool? callNotificationEnabled,
    NotificationDisplayMode? notificationDisplayContent,
  }) async {
    final body = <String, dynamic>{};
    if (systemMessageNotificationEnabled != null) {
      body['systemMessageNotificationEnabled'] = systemMessageNotificationEnabled;
    }
    if (callNotificationEnabled != null) {
      body['callNotificationEnabled'] = callNotificationEnabled;
    }
    if (notificationDisplayContent != null) {
      body['notificationDisplayContent'] = notificationDisplayContent.apiValue;
    }
    final res = await _dio.put('/me/notification-settings', data: body);
    return MeNotificationSettings.fromJson(_payloadMap(res.data));
  }
}

class MeNotificationSettings {
  const MeNotificationSettings({
    required this.systemMessageNotificationEnabled,
    required this.callNotificationEnabled,
    required this.notificationDisplayContent,
  });

  final bool systemMessageNotificationEnabled;
  final bool callNotificationEnabled;
  final NotificationDisplayMode notificationDisplayContent;

  factory MeNotificationSettings.fromJson(Map<String, dynamic> json) {
    return MeNotificationSettings(
      systemMessageNotificationEnabled:
          _readBool(json, const ['systemMessageNotificationEnabled']) ?? true,
      callNotificationEnabled:
          _readBool(json, const ['callNotificationEnabled']) ?? true,
      notificationDisplayContent: NotificationDisplayMode.fromApiValue(
        _readString(json, const ['notificationDisplayContent']),
      ),
    );
  }
}

Map<String, dynamic> _payloadMap(dynamic raw) {
  final payload = unwrapApiPayload(raw);
  if (payload is Map<String, dynamic>) {
    return payload;
  }
  if (payload is Map) {
    return Map<String, dynamic>.from(payload);
  }
  return const <String, dynamic>{};
}

bool? _readBool(Map<String, dynamic> json, List<String> keys) {
  for (final key in keys) {
    final value = json[key];
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      final normalized = value.trim().toLowerCase();
      if (normalized == 'true' || normalized == '1') return true;
      if (normalized == 'false' || normalized == '0') return false;
    }
  }
  return null;
}

String? _readString(Map<String, dynamic> json, List<String> keys) {
  for (final key in keys) {
    final value = json[key];
    if (value is String && value.trim().isNotEmpty) {
      return value.trim();
    }
  }
  return null;
}
