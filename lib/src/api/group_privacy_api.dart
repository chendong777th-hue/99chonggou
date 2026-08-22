import 'package:dio/dio.dart';
import 'package:tencent_cloud_chat_demo/utils/chat_id_format.dart';

import 'api_client.dart';

class GroupPrivacySettings {
  GroupPrivacySettings({required this.privacyProtectionEnabled});

  final bool privacyProtectionEnabled;

  factory GroupPrivacySettings.fromJson(Map<String, dynamic> json) {
    return GroupPrivacySettings(
      privacyProtectionEnabled: _readBool(json, const [
        'privacyProtectionEnabled',
        'privacy_protection_enabled',
        'privacyEnabled',
        'privacy_enabled',
        'enabled',
        'isEnabled',
        'value',
      ]),
    );
  }

  Map<String, dynamic> toJson() => {
        'privacyProtectionEnabled': privacyProtectionEnabled,
      };

  static bool _readBool(Map<String, dynamic> json, List<String> keys) {
    for (final key in keys) {
      if (!json.containsKey(key)) continue;
      final value = json[key];
      if (value is bool) return value;
      if (value is num) return value != 0;
      final text = value?.toString().trim().toLowerCase() ?? '';
      if (text == 'true' || text == '1' || text == 'yes' || text == 'on') {
        return true;
      }
      if (text == 'false' || text == '0' || text == 'no' || text == 'off') {
        return false;
      }
    }
    return false;
  }
}

class GroupPrivacyApi {
  GroupPrivacyApi._();
  static final GroupPrivacyApi instance = GroupPrivacyApi._();

  Dio get _dio => ApiClient.instance.dio;

  String _privacyPath(String groupId) =>
      '/group/${Uri.encodeComponent(ChatIdFormat.apiGroupId(groupId))}/privacy';

  GroupPrivacySettings _parseSettings(dynamic responseData) {
    if (responseData is Map<String, dynamic>) {
      final data = responseData['data'];
      if (data is Map<String, dynamic>) {
        return GroupPrivacySettings.fromJson(data);
      }
      if (data is Map) {
        return GroupPrivacySettings.fromJson(Map<String, dynamic>.from(data));
      }
      return GroupPrivacySettings.fromJson(responseData);
    }
    if (responseData is Map) {
      final typed = Map<String, dynamic>.from(responseData);
      final data = typed['data'];
      if (data is Map) {
        return GroupPrivacySettings.fromJson(Map<String, dynamic>.from(data));
      }
      return GroupPrivacySettings.fromJson(typed);
    }
    return GroupPrivacySettings(privacyProtectionEnabled: false);
  }

  Future<GroupPrivacySettings> fetch(String groupId) async {
    final id = groupId.trim();
    if (id.isEmpty) {
      return GroupPrivacySettings(privacyProtectionEnabled: false);
    }
    final res = await _dio.get(_privacyPath(id));
    return _parseSettings(res.data);
  }

  Future<GroupPrivacySettings> save(String groupId, bool enabled) async {
    final id = groupId.trim();
    if (id.isEmpty) {
      return GroupPrivacySettings(privacyProtectionEnabled: enabled);
    }
    final res = await _dio.put(
      _privacyPath(id),
      data: {'privacyProtectionEnabled': enabled},
    );
    return _parseSettings(res.data);
  }
}
