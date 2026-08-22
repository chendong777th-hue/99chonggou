import 'package:dio/dio.dart';
import 'package:tencent_cloud_chat_demo/src/api/sangong_game_http.dart';
import 'package:tencent_cloud_chat_demo/src/models/sangong_game_settings.dart';
import 'package:tencent_cloud_chat_demo/src/services/group_game/privileged_game_user_service.dart';
import 'package:tencent_cloud_chat_demo/utils/api_response_util.dart';

class SangongSettingsLoadResult {
  const SangongSettingsLoadResult({
    required this.settings,
    required this.canEdit,
  });

  final SangongGameSettings settings;
  final bool canEdit;
}

/// 三公游戏规则：`GET/PUT /api/v1/settings`（经主服务 `/sangong`）。
/// 读取需 `X-Tenant-Id`；写入另需主服务特权 JWT。
class SangongSettingsApi {
  SangongSettingsApi._();

  static final SangongSettingsApi instance = SangongSettingsApi._();

  static const String settingsPath = '/api/v1/settings';

  Dio get _dio => SangongGameHttp.client;

  static String resolveBaseUrl() => SangongGameHttp.baseUrl;

  static bool get canEdit =>
      SangongGameHttp.canCallAdmin &&
      PrivilegedGameUserService.instance.isPrivileged;

  SangongGameSettings _parseSettings(dynamic raw) {
    var payload = unwrapApiPayload(raw);
    if (payload is Map) {
      final map = Map<String, dynamic>.from(payload);
      final nested = map['settings'];
      if (nested is Map) {
        return SangongGameSettings.fromJson(Map<String, dynamic>.from(nested));
      }
      if (map.containsKey('doorCount') ||
          map.containsKey('door_count') ||
          map.containsKey('points')) {
        return SangongGameSettings.fromJson(map);
      }
    }
    return SangongGameSettings.defaults();
  }

  Future<SangongGameSettings> fetch() async {
    final res = await _dio.get(settingsPath);
    return _parseSettings(res.data);
  }

  Future<SangongSettingsLoadResult> loadForUi() async {
    final settings = await fetch();
    return SangongSettingsLoadResult(
      settings: settings,
      canEdit: canEdit,
    );
  }

  Future<SangongGameSettings> save(SangongGameSettings settings) async {
    if (!SangongGameHttp.hasAuth) {
      throw DioError(
        requestOptions: RequestOptions(path: settingsPath),
        type: DioErrorType.other,
        error: 'UNAUTHORIZED',
      );
    }
    if (!SangongGameHttp.hasTenant) {
      throw DioError(
        requestOptions: RequestOptions(path: settingsPath),
        type: DioErrorType.other,
        error: 'TENANT_REQUIRED',
      );
    }
    final res = await SangongGameHttp.adminClient.put(
      settingsPath,
      data: settings.toJson(),
    );
    return _parseSettings(res.data);
  }
}
