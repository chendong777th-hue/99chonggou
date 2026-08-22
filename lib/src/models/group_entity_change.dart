import 'package:tencent_cloud_chat_demo/utils/chat_id_format.dart';
import 'package:tencent_cloud_chat_demo/utils/object_url_normalize.dart';

/// `GET /me/groups/changes` 单条群资料变更（展示 Entity）。
class GroupEntityChangeEvent {
  const GroupEntityChangeEvent({
    required this.seq,
    required this.type,
    required this.groupId,
    this.groupName = '',
    this.avatarUrl = '',
    this.notice = '',
    this.avatarVersion = 0,
    this.updatedAt = 0,
  });

  final int seq;
  final String type;
  final String groupId;
  final String groupName;
  final String avatarUrl;
  final String notice;
  final int avatarVersion;
  final int updatedAt;

  bool get isInfoUpdated {
    final t = type.trim().toUpperCase();
    return t == 'GROUP_INFO_UPDATED' ||
        t == 'GROUP_NAME_CHANGED' ||
        t == 'GROUP_AVATAR_CHANGED' ||
        t == 'GROUP_NOTICE_CHANGED' ||
        type.trim().toLowerCase() == 'group_name_changed' ||
        type.trim().toLowerCase() == 'group_avatar_changed' ||
        type.trim().toLowerCase() == 'group_notice_changed';
  }

  factory GroupEntityChangeEvent.fromJson(Map<String, dynamic> json) {
    final type = (json['type'] ?? json['action'] ?? json['event'] ?? '')
        .toString()
        .trim();
    final groupId = ChatIdFormat.normalizeGroupId(
      (json['group_id'] ??
              json['groupId'] ??
              json['groupID'] ??
              '')
          .toString(),
    );
    return GroupEntityChangeEvent(
      seq: _readInt(json['seq'] ?? json['group_seq'] ?? json['groupSeq']),
      type: type,
      groupId: groupId,
      groupName: (json['group_name'] ?? json['groupName'] ?? json['name'] ?? '')
          .toString()
          .trim(),
      avatarUrl: normalizeObjectUrl(
        (json['avatar_url'] ??
                json['avatarUrl'] ??
                json['groupFaceUrl'] ??
                json['faceUrl'] ??
                '')
            .toString()
            .trim(),
      ),
      notice: (json['notice'] ?? json['notification'] ?? '').toString().trim(),
      avatarVersion: _readInt(
        json['avatar_version'] ?? json['avatarVersion'],
      ),
      updatedAt: _readInt(json['updated_at'] ?? json['updatedAt']),
    );
  }

  static int _readInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}

class GroupEntityChangesPage {
  const GroupEntityChangesPage({
    required this.nextSeq,
    required this.hasMore,
    required this.events,
  });

  final int nextSeq;
  final bool hasMore;
  final List<GroupEntityChangeEvent> events;

  factory GroupEntityChangesPage.fromJson(Map<String, dynamic> json) {
    final rawEvents = json['events'] ?? json['items'] ?? json['changes'];
    final events = <GroupEntityChangeEvent>[];
    if (rawEvents is List) {
      for (final item in rawEvents) {
        if (item is Map) {
          final event = GroupEntityChangeEvent.fromJson(
            Map<String, dynamic>.from(item),
          );
          if (event.groupId.isNotEmpty) {
            events.add(event);
          }
        }
      }
    }
    final nextSeq = GroupEntityChangeEvent._readInt(
      json['next_seq'] ?? json['nextSeq'] ?? json['seq'],
    );
    final hasMore = _readBool(json['has_more'] ?? json['hasMore']);
    final inferredNext = nextSeq > 0
        ? nextSeq
        : events.fold<int>(0, (max, e) => e.seq > max ? e.seq : max);
    return GroupEntityChangesPage(
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

/// 游标失效：客户端应快照 `/me/groups` 后重置 seq。
class GroupEntityCursorExpiredException implements Exception {
  GroupEntityCursorExpiredException([this.code = 'CURSOR_EXPIRED']);

  final String code;

  @override
  String toString() => 'GroupEntityCursorExpiredException($code)';
}
