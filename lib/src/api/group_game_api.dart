import 'package:dio/dio.dart';
import 'package:tencent_cloud_chat_demo/utils/api_response_util.dart';

import 'api_client.dart';

class GroupGameStatus {
  const GroupGameStatus({required this.gameEnabled});

  final bool gameEnabled;

  factory GroupGameStatus.fromJson(Map<String, dynamic> json) {
    return GroupGameStatus(
      gameEnabled: _readBool(json, const [
        'gameEnabled',
        'game_enabled',
        'enabled',
        'isEnabled',
      ]),
    );
  }

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

/// `GET /me/game` — 当前登录用户是否可使用群游戏（特权用户 + 全局总开关）。
class GroupGameApi {
  GroupGameApi._();

  static final GroupGameApi instance = GroupGameApi._();

  static const String _gamePath = '/me/game';

  Dio get _dio => ApiClient.instance.dio;

  GroupGameStatus _parseStatus(dynamic responseData) {
    final payload = unwrapApiPayload(responseData);
    if (payload is Map<String, dynamic>) {
      return GroupGameStatus.fromJson(payload);
    }
    if (payload is Map) {
      return GroupGameStatus.fromJson(Map<String, dynamic>.from(payload));
    }
    return const GroupGameStatus(gameEnabled: false);
  }

  /// 未登录、无特权或其它错误时返回 `gameEnabled: false`。
  Future<GroupGameStatus> fetch() async {
    try {
      final res = await _dio.get(_gamePath);
      return _parseStatus(res.data);
    } on DioError catch (error) {
      final statusCode = error.response?.statusCode;
      if (statusCode == 401 || statusCode == 403 || statusCode == 404) {
        return const GroupGameStatus(gameEnabled: false);
      }
      rethrow;
    }
  }
}
