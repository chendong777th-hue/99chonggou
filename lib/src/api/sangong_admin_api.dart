import 'package:dio/dio.dart';
import 'package:tencent_cloud_chat_demo/src/api/sangong_game_http.dart';
import 'package:tencent_cloud_chat_demo/src/api/sangong_settings_api.dart';
import 'package:tencent_cloud_chat_demo/src/utils/sangong_bet_submit_cutoff.dart';
import 'package:tencent_cloud_chat_demo/src/models/sangong_admin_realtime_state.dart';
import 'package:tencent_cloud_chat_demo/src/models/sangong_admin_models.dart';
import 'package:tencent_cloud_chat_demo/src/models/sangong_game_settings.dart';
import 'package:tencent_cloud_chat_demo/src/models/sangong_my_config.dart';
import 'package:tencent_cloud_chat_demo/utils/api_response_util.dart';

/// 三公运营接口（主服务 JWT + `X-Tenant-Id`）。
class SangongAdminApi {
  SangongAdminApi._();

  static final SangongAdminApi instance = SangongAdminApi._();

  Dio get _dio => SangongGameHttp.adminClient;

  Map<String, dynamic> _asMap(dynamic raw) {
    final payload = unwrapApiPayload(raw);
    if (payload is Map) {
      return Map<String, dynamic>.from(payload);
    }
    return const {};
  }

  SangongAdminSession _parseSession(dynamic raw) {
    final map = _asMap(raw);
    if (map.containsKey('round')) {
      return SangongAdminSession.fromJson(map);
    }
    return const SangongAdminSession();
  }

  List<SangongAdminUserReport> _parseUserReports(dynamic raw) {
    final payload = unwrapApiPayload(raw);
    final list = extractApiList(
      payload,
      listKeys: const ['users', 'items', 'reports'],
    );
    return list
        .whereType<Map>()
        .map((e) => SangongAdminUserReport.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  SangongBalanceMutationResult _parseBalanceResult(dynamic raw) {
    return SangongBalanceMutationResult.fromResponse(_asMap(raw));
  }

  SangongGameSettings _parseSettings(dynamic raw) {
    final map = _asMap(raw);
    final nested = map['settings'];
    if (nested is Map) {
      return SangongGameSettings.fromJson(Map<String, dynamic>.from(nested));
    }
    if (map.containsKey('doorCount') || map.containsKey('minBet')) {
      return SangongGameSettings.fromJson(map);
    }
    return SangongGameSettings.defaults();
  }

  Future<SangongAdminSession> fetchSession() async {
    final res = await _dio.get('/api/v1/admin/session');
    return _parseSession(res.data);
  }

  /// 开机：创建新会话，期数从第 1 期开始。
  Future<SangongSessionMutationResult> startSession() async {
    final res = await _dio.post(
      '/api/v1/admin/session/start',
      data: const <String, dynamic>{},
    );
    return SangongSessionMutationResult.fromJson(_asMap(res.data));
  }

  /// 关机：未结算当前局会作废并退款；有已结算局时发送最终管理账单。
  Future<SangongSessionMutationResult> stopSession() async {
    final res = await _dio.post(
      '/api/v1/admin/session/stop',
      data: const <String, dynamic>{},
    );
    return SangongSessionMutationResult.fromJson(_asMap(res.data));
  }

  /// 拉取管理端实时状态快照（首屏或断线重连）。
  Future<SangongAdminRealtimeState> fetchEventsSnapshot() async {
    final res = await _dio.get('/api/v1/admin/events/snapshot');
    final map = _asMap(res.data);
    final stateRaw = map['state'] ?? map;
    if (stateRaw is Map) {
      return SangongAdminRealtimeState.fromJson(
        Map<String, dynamic>.from(stateRaw),
      );
    }
    return SangongAdminRealtimeState();
  }

  Future<List<SangongAdminUserReport>> fetchUserReports({int? groupId}) async {
    final query = <String, dynamic>{};
    if (groupId != null) {
      query['groupId'] = groupId;
    }
    final res = await _dio.get(
      '/api/v1/admin/reports/users',
      queryParameters: query.isEmpty ? null : query,
    );
    return _parseUserReports(res.data);
  }

  /// 租户列表（不要求 `X-Tenant-Id`）。
  Future<List<SangongTenantInfo>> fetchTenants() async {
    final res = await _dio.get(
      '/api/v1/admin/tenants',
      options: Options(
        extra: const {SangongGameHttp.extraSkipTenant: true},
      ),
    );
    final payload = unwrapApiPayload(res.data);
    final list = extractApiList(
      payload,
      listKeys: const ['tenants', 'items', 'data'],
    );
    return list
        .whereType<Map>()
        .map((e) => SangongTenantInfo.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  /// 当前账号的三公配置（不要求 `X-Tenant-Id`）。
  Future<SangongMyConfig> fetchMyConfig() async {
    final res = await _dio.get(
      '/api/v1/admin/my-config',
      options: Options(
        extra: const {SangongGameHttp.extraSkipTenant: true},
      ),
    );
    return SangongMyConfig.fromJson(_asMap(res.data));
  }

  /// 群主保存 / 认领下注群配置（不要求 `X-Tenant-Id`）。
  Future<SangongMyConfig> saveMyConfig({
    required String name,
    required String imGroupGameId,
    required String imGroupAdminStatsId,
    required String imBotUserId,
    String imGroupWaterId = '',
  }) async {
    final body = <String, dynamic>{
      'name': name.trim(),
      'imGroupGameId': imGroupGameId.trim(),
      'imGroupAdminStatsId': imGroupAdminStatsId.trim(),
      'imBotUserId': imBotUserId.trim(),
    };
    final water = imGroupWaterId.trim();
    if (water.isNotEmpty) {
      body['imGroupWaterId'] = water;
    }
    final res = await _dio.put(
      '/api/v1/admin/my-config',
      data: body,
      options: Options(
        extra: const {SangongGameHttp.extraSkipTenant: true},
      ),
    );
    return SangongMyConfig.fromJson(_asMap(res.data));
  }

  /// 当前账号绑定下注群的成员列表（不拼群 ID，避免 `@TGS#` 被锚点截断）。
  ///
  /// `GET /api/v1/admin/my-config/members`，不要求 `X-Tenant-Id`。
  Future<List<SangongTenantAccessMember>> fetchMyConfigMembers() async {
    final res = await _dio.get(
      '/api/v1/admin/my-config/members',
      options: Options(
        extra: const {SangongGameHttp.extraSkipTenant: true},
      ),
    );
    final payload = unwrapApiPayload(res.data);
    final list = extractApiList(
      payload,
      listKeys: const ['members', 'items', 'access', 'data'],
    );
    return list
        .whereType<Map>()
        .map(
          (e) => SangongTenantAccessMember.fromJson(
            Map<String, dynamic>.from(e),
          ),
        )
        .toList();
  }

  /// 群主添加 / 修改帮工。`role` 一般为 `admin`。
  ///
  /// `POST /api/v1/admin/my-config/members`
  Future<void> upsertMyConfigMember({
    required String imUserId,
    String role = 'admin',
  }) async {
    final userId = imUserId.trim();
    final normalizedRole = role.trim().toLowerCase();
    if (userId.isEmpty) {
      throw ArgumentError('imUserId required');
    }
    await _dio.post(
      '/api/v1/admin/my-config/members',
      data: <String, dynamic>{
        'imUserId': userId,
        'role': normalizedRole.isEmpty ? 'admin' : normalizedRole,
      },
      options: Options(
        extra: const {SangongGameHttp.extraSkipTenant: true},
      ),
    );
  }

  /// 群主移除成员。
  ///
  /// `DELETE /api/v1/admin/my-config/members/{imUserId}`
  Future<void> removeMyConfigMember({
    required String imUserId,
  }) async {
    final userId = Uri.encodeComponent(imUserId.trim());
    if (userId.isEmpty) {
      throw ArgumentError('imUserId required');
    }
    await _dio.delete(
      '/api/v1/admin/my-config/members/$userId',
      options: Options(
        extra: const {SangongGameHttp.extraSkipTenant: true},
      ),
    );
  }

  /// 无本地租户时：单租户自动选中；多租户需先进入游戏群。
  Future<bool> ensureTenantSelected() async {
    await SangongGameHttp.hydrateTenant();
    if (SangongGameHttp.hasTenant) {
      return true;
    }
    if (!SangongGameHttp.hasAuth) {
      return false;
    }
    try {
      final tenants = await fetchTenants();
      if (tenants.length == 1) {
        final id = tenants.first.tenantId;
        if (id.isNotEmpty) {
          SangongGameHttp.setTenantId(id);
          return true;
        }
      }
    } catch (_) {}
    return SangongGameHttp.hasTenant;
  }

  Future<SangongAdminUserReport?> findUserReport(String imUserId) async {
    final target = imUserId.trim();
    if (target.isEmpty) {
      return null;
    }
    final reports = await fetchUserReports();
    for (final report in reports) {
      if (report.imUserId.trim() == target) {
        return report;
      }
    }
    return null;
  }

  /// 用户详细流水：支持 `userId` / `imUserId` / `sessionId`（最多 500 条）。
  ///
  /// `GET /api/v1/admin/reports/user-flow`
  Future<SangongUserFlowReport> fetchUserFlow({
    String? imUserId,
    int? userId,
    int? sessionId,
  }) async {
    final query = <String, dynamic>{};
    final im = imUserId?.trim() ?? '';
    if (im.isNotEmpty) {
      query['imUserId'] = im;
    } else if (userId != null && userId > 0) {
      query['userId'] = userId;
    }
    if (sessionId != null && sessionId > 0) {
      query['sessionId'] = sessionId;
    }
    final res = await _dio.get(
      '/api/v1/admin/reports/user-flow',
      queryParameters: query,
      options: Options(receiveTimeout: 60000),
    );
    return SangongUserFlowReport.fromJson(_asMap(res.data));
  }

  Future<SangongBalanceMutationResult> credit({
    required String imUserId,
    required int amount,
    String? operator,
    String? note,
  }) async {
    final op = operator?.trim() ?? '';
    final res = await _dio.post(
      '/api/v1/admin/users/credit',
      data: {
        'imUserId': imUserId.trim(),
        'amount': amount,
        if (op.isNotEmpty) 'operator': op,
        if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
      },
    );
    return _parseBalanceResult(res.data);
  }

  Future<SangongBalanceMutationResult> debit({
    required String imUserId,
    required int amount,
    String? operator,
    String? note,
  }) async {
    final op = operator?.trim() ?? '';
    final res = await _dio.post(
      '/api/v1/admin/users/debit',
      data: {
        'imUserId': imUserId.trim(),
        'amount': amount,
        if (op.isNotEmpty) 'operator': op,
        if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
      },
    );
    return _parseBalanceResult(res.data);
  }

  /// [group] 分组编号，如 `1`、`A`；`0` 或空字符串表示取消分组。
  Future<SangongBalanceMutationResult> setUserGroup({
    required String imUserId,
    required String group,
  }) async {
    final res = await _dio.put(
      '/api/v1/admin/users/group',
      data: {
        'imUserId': imUserId.trim(),
        'group': group.trim(),
      },
    );
    return _parseBalanceResult(res.data);
  }

  /// 设庄（全局门数 2～10），仅传 [door]，不传用户。
  Future<SangongGameSettings> setDoorCount(int door) async {
    final res = await _dio.post(
      '/api/v1/admin/banker/setup',
      data: {'door': door},
    );
    return _parseSettings(res.data);
  }

  /// 定庄：指定用户、庄门与展示限额（写入 round.bankerLimit，不自动合庄出资）。
  Future<SangongAdminSession> assignBanker({
    required String imUserId,
    required int door,
    int? limit,
    String? nickname,
  }) async {
    final res = await _dio.post(
      '/api/v1/admin/banker/setup',
      data: {
        'imUserId': imUserId.trim(),
        'door': door,
        if (limit != null) 'limit': limit,
        if (nickname != null && nickname.trim().isNotEmpty)
          'nickname': nickname.trim(),
      },
    );
    return _parseSession(res.data);
  }

  Future<void> sendBankerNotification() async {
    await _dio.post('/api/v1/admin/banker/send');
  }

  /// 快速定庄：解析消息文本、定庄并发送群通知（等同 setup-banker + banker/send）。
  Future<SangongQuickSetupBankerResult> quickSetupBanker({
    int? messageId,
    String? text,
    String? imUserId,
    String? nickname,
    int? door,
    int? limit,
  }) async {
    final body = <String, dynamic>{
      if (messageId != null && messageId > 0) 'messageId': messageId,
      if (text != null && text.trim().isNotEmpty) 'text': text.trim(),
      if (imUserId != null && imUserId.trim().isNotEmpty)
        'imUserId': imUserId.trim(),
      if (nickname != null && nickname.trim().isNotEmpty)
        'nickname': nickname.trim(),
      if (door != null && door > 0) 'door': door,
      if (limit != null) 'limit': limit,
    };
    final res = await _dio.post(
      '/api/v1/admin/banker/quick-setup',
      data: body,
    );
    return SangongQuickSetupBankerResult.fromJson(_asMap(res.data));
  }

  Future<SangongAdminSession> addCoBank({
    int? roundId,
    required int userId,
    required int amount,
  }) async {
    final path = roundId != null && roundId > 0
        ? '/api/v1/admin/rounds/$roundId/co-bank'
        : '/api/v1/admin/rounds/current/co-bank';
    final res = await _dio.post(
      path,
      data: {
        'userId': userId,
        'amount': amount,
      },
    );
    return _parseSession(res.data);
  }

  Future<void> sendCoBankNotification() async {
    await _dio.post('/api/v1/admin/co-bank/send');
  }

  /// 取消指定用户在当前局的合庄。
  Future<SangongAdminSession> removeCoBank({required int userId}) async {
    final res = await _dio.post(
      '/api/v1/admin/rounds/current/co-bank/remove',
      data: {'userId': userId},
    );
    return _parseSession(res.data);
  }

  /// 关闭合庄窗口。
  Future<SangongAdminSession> closeCoBank({int? roundId}) async {
    final path = roundId != null && roundId > 0
        ? '/api/v1/admin/rounds/$roundId/co-bank/close'
        : '/api/v1/admin/rounds/current/co-bank/close';
    final res = await _dio.post(path, data: const <String, dynamic>{});
    return _parseSession(res.data);
  }

  /// 截止 / 重新截止下注。
  ///
  /// [cutoff] 为空时截止到本局最新 IM 消息；长按消息截止请传
  /// `untilMessageId` / `untilMsgSeq`（优先级同上）。
  /// 优先使用 [roundId] 路径 `/rounds/{id}/betting/submit`。
  Future<SangongBetSubmitResult> submitBets({
    SangongBetSubmitCutoff? cutoff,
    int? roundId,
  }) async {
    final body = cutoff?.toJson() ?? const <String, dynamic>{};
    final path = roundId != null && roundId > 0
        ? '/api/v1/admin/rounds/$roundId/betting/submit'
        : '/api/v1/admin/betting/submit';
    final res = await _dio.post(path, data: body);
    return SangongBetSubmitResult.fromJson(_asMap(res.data));
  }

  /// 下注预览：截止提交前按消息顺序统计，不落注、不扣款、不关窗。
  ///
  /// 不支持 `send:true`；发送下注图请用 [sendBetReportImage]。
  Future<SangongBetPreviewResult> previewBets({
    SangongBetSubmitCutoff? cutoff,
    int? roundId,
  }) async {
    final body = cutoff?.toJson() ?? const <String, dynamic>{};
    final path = roundId != null && roundId > 0
        ? '/api/v1/admin/rounds/$roundId/betting/preview'
        : '/api/v1/admin/betting/preview';
    final res = await _dio.post(path, data: body);
    return SangongBetPreviewResult.fromJson(_asMap(res.data));
  }

  /// 群发统计清单图片（预览或正式，按截止点；与 betting/preview 同一套 cutoff）。
  ///
  /// `POST /api/v1/admin/reports/bet-image`
  Future<SangongReportImageResult> sendBetReportImage({
    SangongBetSubmitCutoff? cutoff,
    int? roundId,
  }) async {
    final body = <String, dynamic>{
      ...?cutoff?.toJson(),
      if (roundId != null && roundId > 0) 'roundId': roundId,
    };
    final res = await _dio.post(
      '/api/v1/admin/reports/bet-image',
      data: body,
      options: Options(receiveTimeout: 60000),
    );
    return SangongReportImageResult.fromJson(_asMap(res.data));
  }

  /// 群发结算明细图片到游戏群。
  ///
  /// `POST /api/v1/admin/reports/settle-image`
  /// [roundId] 须已结算；省略则取本会话最近已结算局。
  Future<SangongReportImageResult> sendSettleReportImage({int? roundId}) async {
    final body = <String, dynamic>{
      if (roundId != null && roundId > 0) 'roundId': roundId,
    };
    final res = await _dio.post(
      '/api/v1/admin/reports/settle-image',
      data: body,
      options: Options(receiveTimeout: 60000),
    );
    return SangongReportImageResult.fromJson(_asMap(res.data));
  }

  /// 群发流水/抽水账单到管理统计群（非游戏群结算明细）。
  ///
  /// `POST /api/v1/admin/reports/settle-bill`
  Future<SangongReportImageResult> sendSettleBillImage({int? roundId}) async {
    final body = <String, dynamic>{
      if (roundId != null && roundId > 0) 'roundId': roundId,
    };
    final res = await _dio.post(
      '/api/v1/admin/reports/settle-bill',
      data: body,
      options: Options(receiveTimeout: 60000),
    );
    return SangongReportImageResult.fromJson(_asMap(res.data));
  }

  /// 群发用户积分图（当前各用户积分一览 PNG）。
  ///
  /// `POST /api/v1/admin/reports/users/points-image`
  /// [imGroupId] 可选，默认当前游戏群；[groupId] 可选分组，`0` 表示未分组。
  Future<SangongReportImageResult> sendPointsReportImage({
    String? imGroupId,
    int? groupId,
  }) async {
    final body = <String, dynamic>{};
    final group = imGroupId?.trim() ?? '';
    if (group.isNotEmpty) {
      body['imGroupId'] = group;
    }
    if (groupId != null) {
      body['groupId'] = groupId;
    }
    final res = await _dio.post(
      '/api/v1/admin/reports/users/points-image',
      data: body,
      options: Options(receiveTimeout: 60000),
    );
    return SangongReportImageResult.fromJson(_asMap(res.data));
  }

  /// 群发走势图到游戏群（各庄门历史走势 JPEG）。
  Future<SangongReportImageResult> sendTrendReportImage() async {
    final res = await _dio.post(
      '/api/v1/admin/reports/trend-image',
      data: const <String, dynamic>{},
      options: Options(receiveTimeout: 60000),
    );
    return SangongReportImageResult.fromJson(_asMap(res.data));
  }

  /// 一键尝试发送下注图、结算图、积分图和走势图。
  Future<SangongReportImageResult> sendPreviewImages() async {
    final res = await _dio.post(
      '/api/v1/admin/reports/preview-images/send',
      data: const <String, dynamic>{},
      options: Options(receiveTimeout: 60000),
    );
    return SangongReportImageResult.fromJson(_asMap(res.data));
  }

  /// 查询当前局开彩录入状态。
  Future<SangongDrawFetchResult> fetchCurrentDraws() async {
    final res = await _dio.get('/api/v1/admin/rounds/current/draws');
    return SangongDrawFetchResult.fromJson(_asMap(res.data));
  }

  /// 批量录入开彩金额。
  Future<SangongDrawMutationResult> submitDraws(
    List<SangongDrawInput> draws,
  ) async {
    final res = await _dio.post(
      '/api/v1/admin/draws',
      data: {
        'draws': draws.map((e) => e.toJson()).toList(),
      },
    );
    return SangongDrawMutationResult.fromJson(_asMap(res.data));
  }

  /// 本局结算（须先录满开彩，`draw.complete === true`）。
  Future<SangongAdminRound> settleRound(int roundId) async {
    final res = await _dio.post('/api/v1/admin/rounds/$roundId/settle');
    final map = _asMap(res.data);
    final roundRaw = map['round'];
    if (roundRaw is Map) {
      return SangongAdminRound.fromJson(Map<String, dynamic>.from(roundRaw));
    }
    throw DioError(
      requestOptions: res.requestOptions,
      response: res,
      type: DioErrorType.other,
      error: 'INVALID_SETTLE_RESPONSE',
    );
  }

  /// 冲正结算：撤销分账并清空开彩，下注/合庄保留。
  Future<SangongVoidSettlementResult> voidSettlement(int roundId) async {
    final res = await _dio.post(
      '/api/v1/admin/rounds/$roundId/void-settlement',
    );
    return SangongVoidSettlementResult.fromJson(_asMap(res.data));
  }

  /// 一步冲正重结：必须带新开奖 `draws`。
  Future<SangongResettleResult> resettleRound({
    required int roundId,
    required List<SangongDrawInput> draws,
  }) async {
    if (draws.isEmpty) {
      throw DioError(
        requestOptions: RequestOptions(
          path: '/api/v1/admin/rounds/$roundId/resettle',
        ),
        type: DioErrorType.other,
        error: 'RESETTLE_DRAWS_REQUIRED',
      );
    }
    final res = await _dio.post(
      '/api/v1/admin/rounds/$roundId/resettle',
      data: {
        'draws': draws.map((e) => e.toJson()).toList(),
      },
    );
    return SangongResettleResult.fromJson(_asMap(res.data));
  }

  Future<SangongGameSettings> updateMaxBet(int maxBet) async {
    if (!SangongGameHttp.hasAuth) {
      throw DioError(
        requestOptions: RequestOptions(path: SangongSettingsApi.settingsPath),
        type: DioErrorType.other,
        error: 'UNAUTHORIZED',
      );
    }
    if (!SangongGameHttp.hasTenant) {
      throw DioError(
        requestOptions: RequestOptions(path: SangongSettingsApi.settingsPath),
        type: DioErrorType.other,
        error: 'TENANT_REQUIRED',
      );
    }
    final res = await _dio.put(
      SangongSettingsApi.settingsPath,
      data: {'maxBet': maxBet},
    );
    return _parseSettings(res.data);
  }
}

