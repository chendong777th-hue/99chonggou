import 'package:tencent_cloud_chat_demo/src/models/me_group_record.dart';
import 'package:tencent_cloud_chat_demo/utils/chat_id_format.dart';
import 'package:tencent_cloud_chat_demo/utils/object_url_normalize.dart';

/// `GET /me/groups/{groupId}/members/changes` 单条成员流事件。
class GroupMemberChangeEvent {
  const GroupMemberChangeEvent({
    required this.seq,
    required this.type,
    required this.groupId,
    this.userId = '',
    this.nickName = '',
    this.avatarUrl = '',
    this.role = 0,
    this.memberCount = 0,
  });

  final int seq;
  final String type;
  final String groupId;
  final String userId;
  final String nickName;
  final String avatarUrl;
  final int role;
  final int memberCount;

  bool get isUpserted {
    final t = type.trim().toUpperCase();
    return t == 'MEMBER_UPSERTED' || t == 'MEMBER_ADDED';
  }

  bool get isRemoved {
    final t = type.trim().toUpperCase();
    return t == 'MEMBER_REMOVED' || t == 'MEMBER_LEFT';
  }

  GroupMemberRecord? toMemberRecord({required String ownerUserId}) {
    if (!isUpserted) {
      return null;
    }
    final uid = ChatIdFormat.rawUserUid(userId);
    if (uid.isEmpty) {
      return null;
    }
    final owner = ChatIdFormat.rawUserUid(ownerUserId);
    return GroupMemberRecord(
      userId: uid,
      nickname: nickName,
      avatarUrl: avatarUrl,
      friendRemark: '',
      nameCard: '',
      role: role,
      joinedAt: 0,
      isSelf: owner.isNotEmpty && uid == owner,
    );
  }

  factory GroupMemberChangeEvent.fromJson(Map<String, dynamic> json) {
    final type = (json['type'] ?? json['action'] ?? json['event'] ?? '')
        .toString()
        .trim();
    final groupId = ChatIdFormat.normalizeGroupId(
      (json['group_id'] ?? json['groupId'] ?? json['groupID'] ?? '')
          .toString(),
    );
    return GroupMemberChangeEvent(
      seq: _readInt(json['seq']),
      type: type,
      groupId: groupId,
      userId: ChatIdFormat.rawUserUid(
        (json['user_id'] ?? json['userId'] ?? '').toString(),
      ),
      nickName: (json['nick_name'] ??
              json['nickName'] ??
              json['nickname'] ??
              '')
          .toString()
          .trim(),
      avatarUrl: normalizeObjectUrl(
        (json['avatar_url'] ?? json['avatarUrl'] ?? json['faceUrl'] ?? '')
            .toString()
            .trim(),
      ),
      role: _readInt(json['role']),
      memberCount: _readInt(
        json['member_count'] ?? json['memberCount'],
      ),
    );
  }

  static int _readInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}

class GroupMemberChangesPage {
  const GroupMemberChangesPage({
    required this.nextSeq,
    required this.hasMore,
    required this.events,
    this.memberCount = 0,
  });

  final int nextSeq;
  final bool hasMore;
  final int memberCount;
  final List<GroupMemberChangeEvent> events;

  factory GroupMemberChangesPage.fromJson(Map<String, dynamic> json) {
    final rawEvents = json['events'] ?? json['items'] ?? json['changes'];
    final events = <GroupMemberChangeEvent>[];
    if (rawEvents is List) {
      for (final item in rawEvents) {
        if (item is Map) {
          events.add(
            GroupMemberChangeEvent.fromJson(
              Map<String, dynamic>.from(item),
            ),
          );
        }
      }
    }
    final nextSeq = GroupMemberChangeEvent._readInt(
      json['next_seq'] ?? json['nextSeq'] ?? json['seq'],
    );
    final hasMore = _readBool(json['has_more'] ?? json['hasMore']);
    final memberCount = GroupMemberChangeEvent._readInt(
      json['member_count'] ?? json['memberCount'],
    );
    final inferredNext = nextSeq > 0
        ? nextSeq
        : events.fold<int>(0, (max, e) => e.seq > max ? e.seq : max);
    return GroupMemberChangesPage(
      nextSeq: inferredNext,
      hasMore: hasMore,
      memberCount: memberCount,
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

class GroupMemberCursorExpiredException implements Exception {
  GroupMemberCursorExpiredException([this.code = 'CURSOR_EXPIRED']);

  final String code;

  @override
  String toString() => 'GroupMemberCursorExpiredException($code)';
}
