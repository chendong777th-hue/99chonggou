import 'package:dio/dio.dart';
import 'package:tencent_cloud_chat_demo/utils/api_response_util.dart';

import 'api_client.dart';

/// 自建后端归档状态 API。
///
/// 历史消息查询已移除，聊天历史统一由腾讯 IM SDK 本地/云端分页提供。
/// 这里只保留清空历史后的服务端水位同步。
class MessageArchiveApi {
  MessageArchiveApi._();
  static final MessageArchiveApi instance = MessageArchiveApi._();

  Dio get _dio => ApiClient.instance.dio;

  /// 清空当前用户对单聊会话的归档历史水位（不删归档表，仅对本用户生效）。
  Future<int?> clearC2c({required String peerUserId}) {
    return _clear('/me/messages/c2c', <String, dynamic>{
      'peerUserId': peerUserId,
    });
  }

  /// 清空当前用户对群聊会话的归档历史水位（不删归档表，仅对本用户生效）。
  Future<int?> clearGroup({required String groupId}) {
    return _clear('/me/messages/group', <String, dynamic>{
      'groupId': groupId,
    });
  }

  Future<int?> _clear(
    String path,
    Map<String, dynamic> query,
  ) async {
    final res = await _dio.delete(path, queryParameters: query);
    final payload = unwrapApiPayload(res.data);
    if (payload is! Map) {
      return null;
    }
    return _asInt(Map<String, dynamic>.from(payload)['clearedBeforeMs']);
  }

  int? _asInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v);
    return null;
  }
}
