import 'package:tencent_cloud_chat_demo/src/api/group_notice_api.dart';
import 'package:tencent_cloud_chat_demo/utils/chat_id_format.dart';

/// `GET /me/group-notices/changes` 单条 inbox 事件。
class GroupNoticeInboxChangeEvent {
  const GroupNoticeInboxChangeEvent({
    required this.seq,
    required this.type,
    this.noticeId = '',
    this.groupId = '',
    this.groupName = '',
    this.groupAvatarUrl = '',
    this.noticeType = '',
    this.operatorUserId = '',
    this.operatorNickName = '',
    this.targetUserId = '',
    this.targetNickName = '',
    this.createdAtMs = 0,
    this.lastReadAtMs = 0,
  });

  final int seq;
  final String type;
  final String noticeId;
  final String groupId;
  final String groupName;
  final String groupAvatarUrl;
  final String noticeType;
  final String operatorUserId;
  final String operatorNickName;
  final String targetUserId;
  final String targetNickName;
  final int createdAtMs;
  final int lastReadAtMs;

  bool get isUpserted {
    final t = type.trim().toUpperCase();
    return t == 'NOTICE_UPSERTED' || t == 'NOTICE_CREATED';
  }

  bool get isDeleted {
    final t = type.trim().toUpperCase();
    return t == 'NOTICE_DELETED' || t == 'NOTICE_HIDDEN';
  }

  bool get isReadWatermark {
    return type.trim().toUpperCase() == 'READ_WATERMARK';
  }

  GroupNoticeRecord? toRecord() {
    if (!isUpserted) {
      return null;
    }
    final id = noticeId.trim();
    final gid = groupId.trim();
    if (id.isEmpty || gid.isEmpty) {
      return null;
    }
    final mappedType = noticeType.trim().isNotEmpty
        ? noticeType.trim().toLowerCase()
        : type.trim().toLowerCase();
    return GroupNoticeRecord(
      noticeId: id,
      groupId: gid,
      groupName: groupName,
      groupAvatarUrl: groupAvatarUrl,
      type: mappedType,
      operatorUserId: operatorUserId,
      operatorNickName: operatorNickName,
      targetUserId: targetUserId,
      targetNickName: targetNickName,
      createdAtMs: createdAtMs,
    );
  }

  factory GroupNoticeInboxChangeEvent.fromJson(Map<String, dynamic> json) {
    final type = (json['type'] ?? json['action'] ?? json['event'] ?? '')
        .toString()
        .trim();
    final groupId = ChatIdFormat.normalizeGroupId(
      (json['group_id'] ?? json['groupId'] ?? json['groupID'] ?? '')
          .toString(),
    );
    return GroupNoticeInboxChangeEvent(
      seq: _readInt(json['seq']),
      type: type,
      noticeId: (json['notice_id'] ?? json['noticeId'] ?? json['id'] ?? '')
          .toString()
          .trim(),
      groupId: groupId,
      groupName: (json['group_name'] ?? json['groupName'] ?? '')
          .toString()
          .trim(),
      groupAvatarUrl:
          (json['group_avatar_url'] ?? json['groupAvatarUrl'] ?? '')
              .toString()
              .trim(),
      noticeType: (json['notice_type'] ?? json['noticeType'] ?? '')
          .toString()
          .trim(),
      operatorUserId:
          (json['operator_user_id'] ?? json['operatorUserId'] ?? '')
              .toString()
              .trim(),
      operatorNickName: (json['operator_nick_name'] ??
              json['operatorNickName'] ??
              json['operatorName'] ??
              '')
          .toString()
          .trim(),
      targetUserId: (json['target_user_id'] ?? json['targetUserId'] ?? '')
          .toString()
          .trim(),
      targetNickName: (json['target_nick_name'] ??
              json['targetNickName'] ??
              json['targetName'] ??
              '')
          .toString()
          .trim(),
      createdAtMs: _readInt(
        json['created_at_ms'] ??
            json['createdAtMs'] ??
            json['createdAt'] ??
            json['ts'],
      ),
      lastReadAtMs: _readInt(
        json['last_read_at_ms'] ?? json['lastReadAtMs'],
      ),
    );
  }

  static int _readInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}

class GroupNoticeInboxChangesPage {
  const GroupNoticeInboxChangesPage({
    required this.nextSeq,
    required this.hasMore,
    required this.events,
  });

  final int nextSeq;
  final bool hasMore;
  final List<GroupNoticeInboxChangeEvent> events;

  factory GroupNoticeInboxChangesPage.fromJson(Map<String, dynamic> json) {
    final rawEvents = json['events'] ?? json['items'] ?? json['changes'];
    final events = <GroupNoticeInboxChangeEvent>[];
    if (rawEvents is List) {
      for (final item in rawEvents) {
        if (item is Map) {
          events.add(
            GroupNoticeInboxChangeEvent.fromJson(
              Map<String, dynamic>.from(item),
            ),
          );
        }
      }
    }
    final nextSeq = GroupNoticeInboxChangeEvent._readInt(
      json['next_seq'] ?? json['nextSeq'] ?? json['seq'],
    );
    final hasMore = _readBool(json['has_more'] ?? json['hasMore']);
    final inferredNext = nextSeq > 0
        ? nextSeq
        : events.fold<int>(0, (max, e) => e.seq > max ? e.seq : max);
    return GroupNoticeInboxChangesPage(
      nextSeq: inferredNext,
      hasMore: hasMore,
      events: events,
    );
  }

  static bool _readBool(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    final text = value?.toString().trim().toLowerCase() ?? '';
    return text == 'true' || text == '1' || text == 'yes';
  }
}

/// 游标失效：客户端应快照 `/me/group-notices` 后重置 seq。
class GroupNoticeInboxCursorExpiredException implements Exception {
  GroupNoticeInboxCursorExpiredException([this.code = 'CURSOR_EXPIRED']);

  final String code;

  @override
  String toString() => 'GroupNoticeInboxCursorExpiredException($code)';
}
