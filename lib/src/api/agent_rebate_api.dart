import 'package:dio/dio.dart';
import 'package:tencent_cloud_chat_demo/src/api/agent_rebate_http.dart';
import 'package:tencent_cloud_chat_demo/src/api/api_client.dart';
import 'package:tencent_cloud_chat_demo/src/models/agent_rebate_models.dart';
import 'package:tencent_cloud_chat_demo/src/utils/agent_rebate_date_range.dart';
import 'package:tencent_cloud_chat_demo/utils/api_response_util.dart';
import 'package:tencent_cloud_chat_demo/utils/chat_id_format.dart';

class AgentRebateApi {
  AgentRebateApi({Dio? dio}) : _dio = dio ?? ApiClient.instance.dio;

  static final AgentRebateApi instance = AgentRebateApi();

  final Dio _dio;

  Options get _groupOptions => AgentRebateHttp.options();

  Options get _skipGroupOptions => AgentRebateHttp.options(skipGroup: true);

  /// 群绑定状态（只需 JWT，path 内群 ID 需 encode）。
  Future<RobotGroupBindingDto> fetchRobotGroup(String groupId) async {
    final id = _encodeGroupId(groupId);
    final response = await _dio.get(
      '/me/robot/groups/$id',
      options: _skipGroupOptions,
    );
    return RobotGroupBindingDto.fromJson(_unwrapMap(response.data));
  }

  /// 与 Windows「配对」等价（联调用）。
  Future<RobotGroupBindingDto> bindRobotGroup({
    required String groupId,
    required String machineCode,
  }) async {
    final id = _encodeGroupId(groupId);
    final response = await _dio.post(
      '/me/robot/groups/$id/bind',
      data: <String, dynamic>{'machineCode': machineCode.trim()},
      options: _skipGroupOptions,
    );
    return RobotGroupBindingDto.fromJson(_unwrapMap(response.data));
  }

  /// 开启群机器人（联调用）。
  Future<RobotGroupBindingDto> enableRobotGroup({
    required String groupId,
    required String robotId,
  }) async {
    final id = _encodeGroupId(groupId);
    final response = await _dio.post(
      '/me/robot/groups/$id/enable',
      data: <String, dynamic>{'robotId': robotId.trim()},
      options: _skipGroupOptions,
    );
    return RobotGroupBindingDto.fromJson(_unwrapMap(response.data));
  }

  Future<AgentPlayerDto> fetchPlayer() async {
    final response = await _dio.get(
      '/me/agent/player',
      options: _groupOptions,
    );
    return AgentPlayerDto.fromJson(_unwrapMap(response.data));
  }

  Future<AgentRebateCurrentDto> fetchCurrent() async {
    final response = await _dio.get(
      '/me/agent/rebate/current',
      options: _groupOptions,
    );
    return AgentRebateCurrentDto.fromJson(_unwrapMap(response.data));
  }

  Future<AgentRebateApplyDto> submitAgentRebateApply() async {
    final response = await _dio.post(
      '/me/agent/rebate/apply',
      options: _groupOptions,
    );
    return AgentRebateApplyDto.fromJson(_unwrapMap(response.data));
  }

  Future<AgentRebateApplyDto> fetchAgentRebateApplyStatus() async {
    final response = await _dio.get(
      '/me/agent/rebate/apply/status',
      options: _groupOptions,
    );
    return AgentRebateApplyDto.fromJson(_unwrapMap(response.data));
  }

  /// 申请个人待反水结算（`remainingFlow` 维度）。
  Future<AgentRebateApplyDto> submitPersonalRebateApply() async {
    final response = await _dio.post(
      '/me/rebate/apply',
      options: _groupOptions,
    );
    return AgentRebateApplyDto.fromJson(_unwrapMap(response.data));
  }

  Future<AgentRebateApplyDto> fetchPersonalRebateApplyStatus() async {
    final response = await _dio.get(
      '/me/rebate/apply/status',
      options: _groupOptions,
    );
    return AgentRebateApplyDto.fromJson(_unwrapMap(response.data));
  }

  Future<AgentRebateHistoryDto> fetchHistory(AgentRebateDateRange range) async {
    final response = await _dio.get(
      '/me/agent/rebate/history',
      queryParameters: {
        'startDate': range.startApiValue,
        'endDate': range.endApiValue,
      },
      options: _groupOptions,
    );
    return AgentRebateHistoryDto.fromJson(_unwrapMap(response.data));
  }

  Future<AgentDescendantsDto> fetchDescendants({
    AgentDescendantScope scope = AgentDescendantScope.all,
  }) async {
    final response = await _dio.get(
      '/me/agent/descendants',
      queryParameters: <String, dynamic>{'scope': scope.apiValue},
      options: _groupOptions,
    );
    return AgentDescendantsDto.fromJson(_unwrapMap(response.data));
  }

  Future<AgentFirstLevelAgentsDto> fetchFirstLevelAgents() async {
    final response = await _dio.get(
      '/me/agent/first-level-agents',
      options: _groupOptions,
    );
    return AgentFirstLevelAgentsDto.fromJson(_unwrapMap(response.data));
  }

  Future<AgentDescendantDetailDto> fetchDescendantDetail(String userId) async {
    final id = userId.trim();
    if (id.isEmpty) {
      throw ArgumentError.value(userId, 'userId', 'must not be empty');
    }
    final response = await _dio.get(
      '/me/agent/descendants/${Uri.encodeComponent(id)}',
      options: _groupOptions,
    );
    return AgentDescendantDetailDto.fromJson(_unwrapMap(response.data));
  }

  Future<AgentDescendantsHistoryDto> fetchDescendantsHistory(
    AgentRebateDateRange range, {
    String? userId,
  }) async {
    final target = userId?.trim() ?? '';
    final response = await _dio.get(
      '/me/agent/descendants/history',
      queryParameters: <String, dynamic>{
        'startDate': range.startApiValue,
        'endDate': range.endApiValue,
        if (target.isNotEmpty) 'userId': target,
      },
      options: _groupOptions,
    );
    return AgentDescendantsHistoryDto.fromJson(_unwrapMap(response.data));
  }

  Future<AgentRebateExportTaskDto> submitHistoryExport(
    AgentRebateDateRange range,
  ) async {
    final response = await _dio.post(
      '/me/agent/rebate/history/export',
      data: <String, dynamic>{
        'startDate': range.startApiValue,
        'endDate': range.endApiValue,
        'fileType': 'CSV',
        'includeDetail': true,
      },
      options: _groupOptions,
    );
    return AgentRebateExportTaskDto.fromJson(_unwrapMap(response.data));
  }

  Future<AgentRebateExportTaskDto> fetchHistoryExportTask(
    String taskNo,
  ) async {
    final response = await _dio.get(
      '/me/agent/rebate/history/export/${Uri.encodeComponent(taskNo)}',
      options: _groupOptions,
    );
    return AgentRebateExportTaskDto.fromJson(_unwrapMap(response.data));
  }

  Future<AgentRebateDownload> downloadHistoryExport(
    String taskNo, {
    required String fallbackFileName,
  }) async {
    final response = await _dio.get<List<int>>(
      '/me/agent/rebate/history/export/${Uri.encodeComponent(taskNo)}/download',
      options: AgentRebateHttp.options(responseType: ResponseType.bytes),
    );
    return AgentRebateDownload(
      bytes: response.data ?? const <int>[],
      fileName: _downloadFileName(
        response.headers.value('content-disposition'),
        fallback: fallbackFileName,
      ),
    );
  }

  String _encodeGroupId(String groupId) {
    final normalized = ChatIdFormat.normalizeGroupId(groupId.trim());
    final id = normalized.isNotEmpty ? normalized : groupId.trim();
    if (id.isEmpty) {
      throw ArgumentError.value(groupId, 'groupId', 'must not be empty');
    }
    return Uri.encodeComponent(id);
  }

  String _downloadFileName(String? disposition, {required String fallback}) {
    final raw = disposition?.trim() ?? '';
    final encoded = RegExp(
      r'''filename\*\s*=\s*UTF-8''([^;]+)''',
      caseSensitive: false,
    ).firstMatch(raw)?.group(1);
    if (encoded != null && encoded.isNotEmpty) {
      try {
        return Uri.decodeComponent(encoded.trim());
      } catch (_) {}
    }
    final plain = RegExp(
      r'''filename\s*=\s*"?([^";]+)"?''',
      caseSensitive: false,
    ).firstMatch(raw)?.group(1);
    return plain?.trim().isNotEmpty == true ? plain!.trim() : fallback;
  }

  Map<String, dynamic> _unwrapMap(dynamic raw) {
    final payload = unwrapApiPayload(raw);
    if (payload is Map) {
      return Map<String, dynamic>.from(payload);
    }
    throw const FormatException('Agent rebate response data must be an object');
  }
}
