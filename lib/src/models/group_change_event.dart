import 'package:tencent_cloud_chat_demo/utils/chat_id_format.dart';

class GroupChangeEvent {
  const GroupChangeEvent({
    required this.changeEventId,
    required this.groupId,
    required this.action,
    required this.operatorUserId,
    required this.memberUserIds,
    required this.occurredAt,
    this.timelineRank,
    this.detail = const {},
  });

  final String changeEventId;
  final String groupId;
  final String action;
  final String operatorUserId;
  final List<String> memberUserIds;
  final int occurredAt;
  final int? timelineRank;
  final Map<String, dynamic> detail;

  int? get imMsgSeq {
    final value = detail['imMsgSeq'] ?? detail['im_msg_seq'];
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    return int.tryParse(value?.toString().trim() ?? '');
  }

  int? get imMsgTime {
    final value = detail['imMsgTime'] ?? detail['im_msg_time'];
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    return int.tryParse(value?.toString().trim() ?? '');
  }

  factory GroupChangeEvent.fromJson(Map<String, dynamic> json) {
    final membersRaw = json['memberUserIds'] ?? json['member_user_ids'];
    final members = <String>[];
    if (membersRaw is List) {
      for (final item in membersRaw) {
        final uid = ChatIdFormat.rawUserUid(item?.toString() ?? '');
        if (uid.isNotEmpty) {
          members.add(uid);
        }
      }
    }
    final detailRaw = json['detail'];
    final detail = detailRaw is Map
        ? Map<String, dynamic>.from(detailRaw)
        : const <String, dynamic>{};
    return GroupChangeEvent(
      changeEventId: json['changeEventId']?.toString().trim() ??
          json['change_event_id']?.toString().trim() ??
          '',
      groupId: ChatIdFormat.canonicalGroupStorageId(
        json['groupId']?.toString() ?? json['group_id']?.toString() ?? '',
      ),
      action: json['action']?.toString().trim().toLowerCase() ?? '',
      operatorUserId: ChatIdFormat.rawUserUid(
        json['operatorUserId']?.toString() ??
            json['operator_user_id']?.toString() ??
            '',
      ),
      memberUserIds: members,
      occurredAt: _readTimestampMs(json['occurredAt'] ?? json['occurred_at']) ??
          0,
      timelineRank: _readInt(json['timelineRank'] ?? json['timeline_rank']),
      detail: detail,
    );
  }
}

class GroupChangeEventsPage {
  const GroupChangeEventsPage({
    required this.groupId,
    required this.items,
    required this.nextSince,
    required this.hasMore,
  });

  final String groupId;
  final List<GroupChangeEvent> items;
  final int nextSince;
  final bool hasMore;

  factory GroupChangeEventsPage.fromJson(Map<String, dynamic> json) {
    final itemsRaw = json['items'];
    final items = <GroupChangeEvent>[];
    if (itemsRaw is List) {
      for (final item in itemsRaw) {
        if (item is Map) {
          items.add(
            GroupChangeEvent.fromJson(Map<String, dynamic>.from(item)),
          );
        }
      }
    }
    final nextSince = _readTimestampMs(json['nextSince'] ?? json['next_since']) ??
        items.fold<int>(
          0,
          (max, item) => item.occurredAt > max ? item.occurredAt : max,
        );
    final hasMore = json['hasMore'] == true || json['has_more'] == true;
    return GroupChangeEventsPage(
      groupId: ChatIdFormat.canonicalGroupStorageId(
        json['groupId']?.toString() ?? json['group_id']?.toString() ?? '',
      ),
      items: items,
      nextSince: nextSince,
      hasMore: hasMore,
    );
  }
}

class MyGroupChangeEventsPage {
  const MyGroupChangeEventsPage({
    required this.items,
    required this.nextSince,
    required this.hasMore,
  });

  final List<GroupChangeEvent> items;
  final int nextSince;
  final bool hasMore;

  factory MyGroupChangeEventsPage.fromJson(Map<String, dynamic> json) {
    final itemsRaw = json['items'];
    final items = <GroupChangeEvent>[];
    if (itemsRaw is List) {
      for (final item in itemsRaw) {
        if (item is Map) {
          items.add(
            GroupChangeEvent.fromJson(Map<String, dynamic>.from(item)),
          );
        }
      }
    }
    final nextSince = _readTimestampMs(json['nextSince'] ?? json['next_since']) ??
        items.fold<int>(
          0,
          (max, item) => item.occurredAt > max ? item.occurredAt : max,
        );
    final hasMore = json['hasMore'] == true || json['has_more'] == true;
    return MyGroupChangeEventsPage(
      items: items,
      nextSince: nextSince,
      hasMore: hasMore,
    );
  }
}

int? _readInt(Object? value) {
  if (value == null) {
    return null;
  }
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  return int.tryParse(value.toString().trim());
}

int? _readTimestampMs(Object? value) {
  final parsed = _readInt(value);
  if (parsed == null || parsed <= 0) {
    return null;
  }
  return parsed;
}
