import 'package:dio/dio.dart';
import 'package:tencent_cloud_chat_demo/utils/chat_id_format.dart';

/// 代理反水群租户上下文：`/me/agent/**`、`/me/rebate/**` 必须带 `X-Group-Id`。
class AgentRebateHttp {
  AgentRebateHttp._();

  static const String groupHeader = 'X-Group-Id';

  /// Dio `Options.extra`：为 true 时不附带 `X-Group-Id`（如 robot groups 查询）。
  static const String extraSkipGroup = 'agentRebateSkipGroup';

  static String? _groupId;

  static String? get groupId => _groupId;

  static bool get hasGroup {
    final id = _groupId?.trim() ?? '';
    return id.isNotEmpty;
  }

  /// 进入群聊时设置；空字符串清除。
  static void setGroupId(String? groupId) {
    final raw = groupId?.trim() ?? '';
    if (raw.isEmpty) {
      _groupId = null;
      return;
    }
    final normalized = ChatIdFormat.normalizeGroupId(raw);
    _groupId = normalized.isNotEmpty ? normalized : raw;
  }

  static void clearGroup() {
    _groupId = null;
  }

  /// 给反水业务请求附带群头；`skipGroup: true` 用于 `/me/robot/groups/**`。
  static Options options({
    bool skipGroup = false,
    ResponseType? responseType,
  }) {
    final headers = <String, dynamic>{};
    if (!skipGroup && hasGroup) {
      headers[groupHeader] = _groupId;
    }
    return Options(
      headers: headers.isEmpty ? null : headers,
      responseType: responseType,
      extra: <String, dynamic>{
        if (skipGroup) extraSkipGroup: true,
      },
    );
  }
}
