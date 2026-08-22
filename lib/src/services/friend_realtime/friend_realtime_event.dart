import 'package:tencent_cloud_chat_demo/src/api/conversation_pin_api.dart';
import 'package:tencent_cloud_chat_demo/src/utils/group_change_event_metadata.dart';

class FriendRealtimeEvent {
  FriendRealtimeEvent({
    required this.event,
    required this.fromUserId,
    required this.toUserId,
    this.requestId,
    this.addWording,
    this.addSource,
    this.createdAt,
    this.ts,
    this.action,
    this.peerUserId,
    this.peerNickname,
    this.peerAvatarUrl,
    this.remark,
    this.addedAt,
    this.inMyFriendList,
    this.isFriend,
    this.peerDeletedMe,
    this.canMessage,
    this.groupId,
    this.operatorUserId,
    this.memberUserIds = const [],
    this.detail,
    this.callId,
    this.callerUserId,
    this.mediaType,
    this.direction,
    this.result,
    this.durationSec,
    this.occurredAt,
    this.lastActiveAt,
    this.lastActiveVisibility,
    this.online,
    this.packetId,
    this.senderUserId,
    this.packetType,
    this.currency,
    this.packetStatus,
    this.remainingCount,
    this.remainingAmount,
    this.claimerUserId,
    this.claimerNickName,
    this.claimAmount,
    this.changeEventId,
    this.timelineRank,
    this.momentId,
    this.authorUserId,
    this.actorUserId,
    this.liked,
    this.likeCount,
    this.commentId,
    this.replyToCommentId,
    this.commentCount,
    this.archiveChatType,
    this.archivePeerId,
    this.archiveArchived,
    this.archiveArchivedAt,
    this.archiveUpdatedAt,
    this.archiveBatch,
    this.folderId,
    this.folderAction,
    this.folderBatch,
    this.pinItems,
    this.pinUpdatedAt,
    this.pinBatch,
    this.seq,
  });

  final String event;
  final String fromUserId;
  final String toUserId;
  final int? requestId;
  final String? addWording;
  final String? addSource;
  final String? createdAt;
  final int? ts;

  final String? action;
  final String? peerUserId;
  final String? peerNickname;
  final String? peerAvatarUrl;
  final String? remark;
  final String? addedAt;
  final bool? inMyFriendList;
  final bool? isFriend;
  final bool? peerDeletedMe;
  final bool? canMessage;

  final String? groupId;
  final String? operatorUserId;
  final List<String> memberUserIds;
  final Map<String, dynamic>? detail;

  final String? callId;
  final String? callerUserId;
  final String? mediaType;
  final String? direction;
  final String? result;
  final int? durationSec;
  final int? occurredAt;
  final int? lastActiveAt;
  final String? lastActiveVisibility;
  final bool? online;

  final int? packetId;
  final String? senderUserId;
  final String? packetType;
  final String? currency;
  final String? packetStatus;
  final int? remainingCount;
  final int? remainingAmount;
  final String? claimerUserId;
  final String? claimerNickName;
  final int? claimAmount;
  final String? changeEventId;
  final int? timelineRank;

  final String? momentId;
  final String? authorUserId;
  final String? actorUserId;
  final bool? liked;
  final int? likeCount;
  final String? commentId;
  final String? replyToCommentId;
  final int? commentCount;

  final String? archiveChatType;
  final String? archivePeerId;
  final bool? archiveArchived;
  final int? archiveArchivedAt;
  final int? archiveUpdatedAt;
  final bool? archiveBatch;

  final String? folderId;
  final String? folderAction;
  final bool? folderBatch;

  final List<ConversationPinItem>? pinItems;
  final int? pinUpdatedAt;
  final bool? pinBatch;

  /// 通讯录 Versioned Sync：`friend_list_changed` / Difference 同源序号。
  final int? seq;

  int? get resolvedOccurredAtMs {
    if (occurredAt != null && occurredAt! > 0) {
      return occurredAt;
    }
    return GroupChangeEventMetadata.fromMaps(
      topLevel: const <String, dynamic>{},
      detail: detail,
    ).occurredAtMs;
  }

  factory FriendRealtimeEvent.fromJson(Map<String, dynamic> json) {
    final payload = _eventPayload(json);
    final merged = <String, dynamic>{...payload, ...json};
    final detail = _readMap(merged, const ['detail']);
    final changeMeta = GroupChangeEventMetadata.fromMaps(
      topLevel: merged,
      detail: detail,
    );
    return FriendRealtimeEvent(
      event: _readString(merged, const ['event']) ?? '',
      fromUserId: _readString(merged, const ['fromUserId', 'from_user_id']) ?? '',
      toUserId: _readString(merged, const ['toUserId', 'to_user_id']) ?? '',
      requestId: _parseOptionalInt(
        merged['requestId'] ?? merged['request_id'],
      ),
      addWording: merged['addWording']?.toString() ??
          merged['add_wording']?.toString(),
      addSource: merged['addSource']?.toString() ??
          merged['add_source']?.toString(),
      createdAt: merged['createdAt']?.toString() ??
          merged['created_at']?.toString(),
      ts: _parseOptionalInt(merged['ts']),
      action: _readString(merged, const ['action']),
      peerUserId: _readString(merged, const [
        'peerUserId',
        'peer_user_id',
      ]),
      peerNickname: _readString(merged, const [
        'peerNickname',
        'peer_nickname',
        'peerName',
        'peer_name',
      ]),
      peerAvatarUrl: _readString(merged, const [
        'peerAvatarUrl',
        'peer_avatar_url',
        'peerAvatar',
        'peer_avatar',
      ]),
      remark: merged['remark']?.toString(),
      addedAt: merged['addedAt']?.toString() ?? merged['added_at']?.toString(),
      inMyFriendList: _parseOptionalBool(
        merged['inMyFriendList'] ?? merged['in_my_friend_list'],
      ),
      isFriend: _parseOptionalBool(merged['isFriend'] ?? merged['is_friend']),
      peerDeletedMe: _parseOptionalBool(
        merged['peerDeletedMe'] ?? merged['peer_deleted_me'],
      ),
      canMessage: _parseOptionalBool(
        merged['canMessage'] ?? merged['can_message'],
      ),
      groupId: _readString(merged, const ['groupId', 'group_id', 'groupID']),
      operatorUserId: _readString(merged, const [
        'operatorUserId',
        'operator_user_id',
      ]),
      memberUserIds: _readStringList(merged, const [
        'memberUserIds',
        'member_user_ids',
      ]),
      detail: detail,
      changeEventId: changeMeta.changeEventId,
      timelineRank: changeMeta.timelineRank,
      callId: _readString(merged, const ['callId', 'call_id', 'callID']),
      callerUserId: _readString(merged, const [
        'callerUserId',
        'caller_user_id',
        'callerUserID',
      ]),
      mediaType: _readString(merged, const ['mediaType', 'media_type']),
      direction: _readString(merged, const ['direction', 'callDirection']),
      result: _readString(merged, const ['result', 'callResult']),
      durationSec: _parseOptionalInt(
        merged['durationSec'] ?? merged['duration_sec'],
      ),
      occurredAt: changeMeta.occurredAtMs,
      lastActiveAt: _parseOptionalInt(
        merged['lastActiveAt'] ?? merged['last_active_at'],
      ),
      lastActiveVisibility: _readString(merged, const [
        'lastActiveVisibility',
        'last_active_visibility',
      ]),
      online: _parseOptionalBool(merged['online']),
      packetId: _parseOptionalInt(merged['packetId'] ?? merged['packet_id']),
      senderUserId: _readString(merged, const [
        'senderUserId',
        'sender_user_id',
      ]),
      packetType: _readString(merged, const [
        'packetType',
        'packet_type',
      ]),
      currency: _readString(merged, const ['currency']),
      packetStatus: _readString(merged, const [
        'packetStatus',
        'packet_status',
      ]),
      remainingCount: _parseOptionalInt(
        merged['remainingCount'] ?? merged['remaining_count'],
      ),
      remainingAmount: _parseOptionalInt(
        merged['remainingAmount'] ?? merged['remaining_amount'],
      ),
      claimerUserId: _readString(merged, const [
        'claimerUserId',
        'claimer_user_id',
      ]),
      claimerNickName: _readString(merged, const [
        'claimerNickName',
        'claimer_nick_name',
        'claimerNickname',
        'claimer_nickname',
      ]),
      claimAmount: _parseOptionalInt(
        merged['claimAmount'] ?? merged['claim_amount'],
      ),
      momentId: _readString(merged, const [
        'momentId',
        'moment_id',
      ]),
      authorUserId: _readString(merged, const [
        'authorUserId',
        'author_user_id',
      ]),
      actorUserId: _readString(merged, const [
        'actorUserId',
        'actor_user_id',
      ]),
      liked: _parseOptionalBool(merged['liked']),
      likeCount: _parseOptionalInt(merged['likeCount'] ?? merged['like_count']),
      commentId: _readString(merged, const [
        'commentId',
        'comment_id',
      ]),
      replyToCommentId: _readString(merged, const [
        'replyToCommentId',
        'reply_to_comment_id',
      ]),
      commentCount: _parseOptionalInt(
        merged['commentCount'] ?? merged['comment_count'],
      ),
      archiveChatType: _readString(merged, const [
        'chatType',
        'chat_type',
      ]),
      archivePeerId: _readString(merged, const [
        'peerId',
        'peer_id',
      ]),
      archiveArchived: _parseOptionalBool(merged['archived']),
      archiveArchivedAt: _parseOptionalInt(
        merged['archivedAt'] ?? merged['archived_at'],
      ),
      archiveUpdatedAt: _parseOptionalInt(
        merged['updatedAt'] ?? merged['updated_at'],
      ),
      archiveBatch: _parseOptionalBool(merged['batch']),
      folderId: _readString(merged, const [
        'folderId',
        'folder_id',
      ]),
      folderAction: _readString(merged, const [
        'action',
        'folderAction',
        'folder_action',
      ]),
      folderBatch: _parseOptionalBool(merged['batch']),
      pinItems: _readPinItems(merged['items']),
      pinUpdatedAt: _parseOptionalInt(
        merged['updatedAt'] ?? merged['updated_at'],
      ),
      pinBatch: _parseOptionalBool(merged['batch']),
      seq: _parseOptionalInt(merged['seq']),
    );
  }
}

Map<String, dynamic> _eventPayload(Map<String, dynamic> json) {
  final nested = json['data'] ?? json['payload'];
  if (nested is Map) {
    return Map<String, dynamic>.from(nested);
  }
  return const <String, dynamic>{};
}

String? _readString(Map<String, dynamic> json, List<String> keys) {
  for (final key in keys) {
    final value = json[key]?.toString().trim();
    if (value != null && value.isNotEmpty) {
      return value;
    }
  }
  return null;
}

int? _parseOptionalInt(Object? value) {
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

List<String> _readStringList(Map<String, dynamic> json, List<String> keys) {
  for (final key in keys) {
    final value = json[key];
    if (value is! List) {
      continue;
    }
    return value
        .map((item) => item?.toString().trim() ?? '')
        .where((item) => item.isNotEmpty)
        .toList();
  }
  return const [];
}

Map<String, dynamic>? _readMap(Map<String, dynamic> json, List<String> keys) {
  for (final key in keys) {
    final value = json[key];
    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }
  }
  return null;
}

bool? _parseOptionalBool(Object? value) {
  if (value == null) {
    return null;
  }
  if (value is bool) {
    return value;
  }
  if (value is num) {
    return value != 0;
  }
  final text = value.toString().trim().toLowerCase();
  if (text.isEmpty) {
    return null;
  }
  if (text == 'true' || text == '1' || text == 'yes' || text == 'y') {
    return true;
  }
  if (text == 'false' || text == '0' || text == 'no' || text == 'n') {
    return false;
  }
  return null;
}

List<ConversationPinItem>? _readPinItems(Object? raw) {
  if (raw == null) {
    return null;
  }
  if (raw is! List) {
    return null;
  }
  final items = <ConversationPinItem>[];
  for (final entry in raw) {
    if (entry is! Map) {
      continue;
    }
    final item = ConversationPinItem.fromJson(
      Map<String, dynamic>.from(entry),
    );
    if (item.chatType.isEmpty || item.peerId.isEmpty) {
      continue;
    }
    if (item.chatType != 'c2c' && item.chatType != 'group') {
      continue;
    }
    items.add(item);
  }
  return items;
}
