import 'package:dio/dio.dart';
import 'package:tencent_cloud_chat_demo/src/models/group_change_event.dart';
import 'package:tencent_cloud_chat_demo/utils/api_response_util.dart';
import 'package:tencent_cloud_chat_demo/utils/chat_id_format.dart';

import 'api_client.dart';

/// REST 补拉群成员变动事件（对照 IM GroupTips 历史）。
class GroupChangeEventApi {
  GroupChangeEventApi._();

  static final GroupChangeEventApi instance = GroupChangeEventApi._();

  Dio get _dio => ApiClient.instance.dio;

  String _groupPath(String groupId) =>
      '/group/${Uri.encodeComponent(ChatIdFormat.apiGroupId(groupId))}';

  /// GET /group/{groupId}/change-events
  Future<GroupChangeEventsPage> fetchGroupEvents({
    required String groupId,
    int since = 0,
    int limit = 50,
    List<String>? actions,
  }) async {
    final id = ChatIdFormat.apiGroupId(groupId);
    final query = <String, dynamic>{
      if (since > 0) 'since': since,
      'limit': limit.clamp(1, 200),
    };
    if (actions != null && actions.isNotEmpty) {
      query['actions'] = actions.join(',');
    }
    final res = await _dio.get(
      '${_groupPath(id)}/change-events',
      queryParameters: query,
    );
    final payload = unwrapApiPayload(res.data);
    if (payload is Map) {
      return GroupChangeEventsPage.fromJson(
        Map<String, dynamic>.from(payload),
      );
    }
    return const GroupChangeEventsPage(
      groupId: '',
      items: [],
      nextSince: 0,
      hasMore: false,
    );
  }

  /// GET /me/group-change-events
  Future<MyGroupChangeEventsPage> fetchMyEvents({
    int since = 0,
    int limit = 100,
    List<String>? actions,
  }) async {
    final query = <String, dynamic>{
      if (since > 0) 'since': since,
      'limit': limit.clamp(1, 200),
    };
    if (actions != null && actions.isNotEmpty) {
      query['actions'] = actions.join(',');
    }
    final res = await _dio.get(
      '/me/group-change-events',
      queryParameters: query,
    );
    final payload = unwrapApiPayload(res.data);
    if (payload is Map) {
      return MyGroupChangeEventsPage.fromJson(
        Map<String, dynamic>.from(payload),
      );
    }
    return const MyGroupChangeEventsPage(
      items: [],
      nextSince: 0,
      hasMore: false,
    );
  }
}
