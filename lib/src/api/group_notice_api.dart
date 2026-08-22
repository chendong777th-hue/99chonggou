import 'package:dio/dio.dart';
import 'package:tencent_cloud_chat_demo/src/models/group_notice_inbox_change.dart';
import 'package:tencent_cloud_chat_demo/utils/api_response_util.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/view_models/tui_chat_global_model.dart';

import 'api_client.dart';
import 'group_join_api.dart';
import 'me_group_api.dart';

/// 群系统通知（设/撤管理员、转让群主）REST API。
class GroupNoticeApi {
  GroupNoticeApi._();

  static final GroupNoticeApi instance = GroupNoticeApi._();

  Dio get _dio => ApiClient.instance.dio;

  Future<GroupNoticesPage> fetchMyGroupNotices({
    int limit = 50,
    int offset = 0,
    int since = 0,
    bool unreadOnly = false,
  }) async {
    final res = await _dio.get(
      '/me/group-notices',
      queryParameters: <String, dynamic>{
        'limit': limit,
        'offset': offset,
        if (since > 0) 'since': since,
        if (unreadOnly) 'unreadOnly': 'true',
      },
    );
    final payload = unwrapApiPayload(res.data);
    if (payload is! Map) {
      return const GroupNoticesPage(items: []);
    }
    final map = Map<String, dynamic>.from(payload);
    final list = extractApiList(
      map,
      listKeys: const ['items', 'notices', 'results'],
    );
    final items = list
        .whereType<Map>()
        .map(
          (item) => GroupNoticeRecord.fromJson(
            Map<String, dynamic>.from(item),
          ),
        )
        .where((item) => item.noticeId.isNotEmpty && item.groupId.isNotEmpty)
        .toList(growable: false);
    return GroupNoticesPage(
      items: items,
      total: _readInt(map['total']),
      limit: _readInt(map['limit']) ?? limit,
      offset: _readInt(map['offset']) ?? offset,
      unreadCount: _readInt(map['unreadCount']),
      lastReadAtMs: _readInt(map['lastReadAtMs']),
    );
  }

  Future<void> markGroupNoticesRead({required int readAt}) async {
    await _dio.put(
      '/me/group-notices/read',
      data: <String, dynamic>{'readAt': readAt},
    );
  }

  /// DELETE /me/group-notices/{noticeId} — 软删除（仅对当前用户隐藏）。
  Future<void> deleteMyGroupNotice(String noticeId) async {
    final id = noticeId.trim();
    if (id.isEmpty) {
      throw ArgumentError.value(noticeId, 'noticeId', 'empty noticeId');
    }
    await _dio.delete(
      '/me/group-notices/${Uri.encodeComponent(id)}',
    );
  }

  /// Telegram 风格系统通知 inbox 增量：`GET /me/group-notices/changes?since_seq=`
  Future<GroupNoticeInboxChangesPage> fetchGroupNoticeInboxChanges({
    required int sinceSeq,
    int limit = 100,
  }) async {
    final safeLimit = limit.clamp(1, 200);
    final since = sinceSeq < 0 ? 0 : sinceSeq;
    try {
      final res = await _dio.get(
        '/me/group-notices/changes',
        queryParameters: <String, dynamic>{
          'since_seq': since,
          'limit': safeLimit,
        },
      );
      final payload = unwrapApiPayload(res.data);
      if (payload is Map) {
        return GroupNoticeInboxChangesPage.fromJson(
          Map<String, dynamic>.from(payload),
        );
      }
      return const GroupNoticeInboxChangesPage(
        nextSeq: 0,
        hasMore: false,
        events: <GroupNoticeInboxChangeEvent>[],
      );
    } on DioError catch (e) {
      final code = MeGroupApi.readDioCode(e).toUpperCase();
      final status = e.response?.statusCode;
      if (status == 410 ||
          code.contains('CURSOR_EXPIRED') ||
          code.contains('SEQ_EXPIRED') ||
          code.contains('INVALID_CURSOR') ||
          code.contains('CURSOR_INVALID')) {
        throw GroupNoticeInboxCursorExpiredException(code);
      }
      rethrow;
    }
  }

  /// DELETE /me/group-notices — 无 body 隐藏全部；body `{ noticeIds }` 批量隐藏。
  /// 响应 `{ deleted: N }`；404 `NOTICE_NOT_FOUND` 表示不存在或无权隐藏。
  Future<int> deleteMyGroupNotices({List<String>? noticeIds}) async {
    final ids = noticeIds
            ?.map((item) => item.trim())
            .where((item) => item.isNotEmpty)
            .toList(growable: false) ??
        const <String>[];
    final res = await _dio.delete(
      '/me/group-notices',
      data: ids.isNotEmpty
          ? <String, dynamic>{'noticeIds': ids}
          : null,
    );
    final payload = unwrapApiPayload(res.data);
    if (payload is Map) {
      final deleted = _readInt(
        payload['deleted'] ?? payload['deletedCount'] ?? payload['count'],
      );
      if (deleted != null) {
        return deleted;
      }
    }
    return ids.isEmpty ? 0 : ids.length;
  }
}

class GroupNoticesPage {
  const GroupNoticesPage({
    required this.items,
    this.total,
    this.limit,
    this.offset,
    this.unreadCount,
    this.lastReadAtMs,
  });

  final List<GroupNoticeRecord> items;
  final int? total;
  final int? limit;
  final int? offset;
  final int? unreadCount;
  final int? lastReadAtMs;
}

class GroupNoticeRecord {
  const GroupNoticeRecord({
    required this.noticeId,
    required this.groupId,
    required this.type,
    required this.createdAtMs,
    this.groupName = '',
    this.groupAvatarUrl = '',
    this.operatorUserId = '',
    this.operatorNickName = '',
    this.targetUserId = '',
    this.targetNickName = '',
  });

  final String noticeId;
  final String groupId;
  final String groupName;
  final String groupAvatarUrl;
  final String type;
  final String operatorUserId;
  final String operatorNickName;
  final String targetUserId;
  final String targetNickName;
  final int createdAtMs;

  factory GroupNoticeRecord.fromJson(Map<String, dynamic> json) {
    final noticeType = (json['noticeType'] ?? json['notice_type'])
        ?.toString()
        .trim()
        .toLowerCase();
    final rawType = json['type']?.toString().trim().toLowerCase() ?? '';
    final mappedType = (noticeType != null && noticeType.isNotEmpty)
        ? noticeType
        : (rawType == 'notice_upserted' ||
                rawType == 'notice_created' ||
                rawType == 'notice_deleted' ||
                rawType == 'notice_hidden' ||
                rawType == 'read_watermark')
            ? ''
            : rawType;
    return GroupNoticeRecord(
      noticeId: json['noticeId']?.toString().trim() ??
          json['notice_id']?.toString().trim() ??
          json['id']?.toString().trim() ??
          '',
      groupId: json['groupId']?.toString().trim() ??
          json['group_id']?.toString().trim() ??
          '',
      groupName: json['groupName']?.toString().trim() ??
          json['group_name']?.toString().trim() ??
          '',
      groupAvatarUrl: json['groupAvatarUrl']?.toString().trim() ??
          json['group_avatar_url']?.toString().trim() ??
          '',
      type: mappedType,
      operatorUserId: json['operatorUserId']?.toString().trim() ??
          json['operator_user_id']?.toString().trim() ??
          '',
      operatorNickName: json['operatorNickName']?.toString().trim() ??
          json['operator_nick_name']?.toString().trim() ??
          json['operatorName']?.toString().trim() ??
          '',
      targetUserId: json['targetUserId']?.toString().trim() ??
          json['target_user_id']?.toString().trim() ??
          '',
      targetNickName: json['targetNickName']?.toString().trim() ??
          json['target_nick_name']?.toString().trim() ??
          json['targetName']?.toString().trim() ??
          '',
      createdAtMs: GroupJoinApplicationRecord.readTimestampMs(
            json['createdAt'] ??
                json['createdAtMs'] ??
                json['created_at_ms'] ??
                json['ts'],
          ) ??
          0,
    );
  }

  GroupSystemNoticeItem toUIKitNotice() {
    return GroupSystemNoticeItem(
      id: noticeId,
      groupID: groupId,
      groupName: groupName.isNotEmpty ? groupName : groupId,
      groupFaceUrl: groupAvatarUrl,
      type: _mapNoticeType(type),
      operatorUserID: operatorUserId,
      operatorName: operatorNickName,
      targetUserID: targetUserId,
      targetName: targetNickName,
      timestamp: createdAtMs,
    );
  }

  static GroupSystemNoticeType _mapNoticeType(String raw) {
    switch (raw.trim().toLowerCase()) {
      case 'revoke_administrator':
        return GroupSystemNoticeType.revokeAdministrator;
      case 'transfer_owner':
        return GroupSystemNoticeType.transferOwner;
      case 'grant_administrator':
      default:
        return GroupSystemNoticeType.grantAdministrator;
    }
  }

  static GroupNoticeRecord? fromDetail(Map<String, dynamic>? detail) {
    if (detail == null || detail.isEmpty) {
      return null;
    }
    final record = GroupNoticeRecord.fromJson(detail);
    if (record.noticeId.isEmpty || record.groupId.isEmpty) {
      return null;
    }
    return record;
  }
}

int? _readInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '');
}
