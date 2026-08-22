import 'package:tencent_cloud_chat_demo/utils/chat_id_format.dart';

/// `GET /me/friends/changes` 单条通讯录变更。
class FriendContactChangeEvent {
  const FriendContactChangeEvent({
    required this.seq,
    required this.type,
    required this.peerUserId,
    this.peerNickname = '',
    this.peerAvatarUrl = '',
    this.remark = '',
    this.inMyFriendList = true,
    this.isFriend = true,
    this.peerDeletedMe = false,
    this.canMessage = true,
    this.lastActiveAt,
    this.lastActiveVisibility,
    this.tcpAction = '',
  });

  final int seq;
  final String type;
  final String peerUserId;
  final String peerNickname;
  final String peerAvatarUrl;
  final String remark;
  final bool inMyFriendList;
  final bool isFriend;
  final bool peerDeletedMe;
  final bool canMessage;
  final int? lastActiveAt;
  final String? lastActiveVisibility;
  final String tcpAction;

  String get resolvedTcpAction {
    final explicit = tcpAction.trim().toLowerCase();
    if (explicit.isNotEmpty) {
      return explicit;
    }
    switch (type.trim().toUpperCase()) {
      case 'CONTACT_CREATED':
        return 'added';
      case 'CONTACT_DELETED':
        return 'removed';
      case 'CONTACT_UPDATED':
        return 'updated';
      case 'CONTACT_REMARK_UPDATED':
        return 'remark_updated';
      case 'CONTACT_PROFILE_UPDATED':
        return 'profile_updated';
      default:
        return type.trim().toLowerCase();
    }
  }

  factory FriendContactChangeEvent.fromJson(Map<String, dynamic> json) {
    final peer = ChatIdFormat.rawUserUid(
      (json['peerUserId'] ??
              json['peer_user_id'] ??
              json['friendUserId'] ??
              json['friend_user_id'] ??
              json['userId'] ??
              json['user_id'] ??
              '')
          .toString(),
    );
    return FriendContactChangeEvent(
      seq: _readInt(json['seq']),
      type: (json['type'] ?? json['event'] ?? '').toString().trim(),
      peerUserId: peer,
      peerNickname: (json['peerNickname'] ??
              json['peer_nickname'] ??
              json['friendNickname'] ??
              json['friend_nickname'] ??
              '')
          .toString()
          .trim(),
      peerAvatarUrl: (json['peerAvatarUrl'] ??
              json['peer_avatar_url'] ??
              json['friendAvatarUrl'] ??
              json['friend_avatar_url'] ??
              '')
          .toString()
          .trim(),
      remark: (json['remark'] ?? '').toString(),
      inMyFriendList: _readBool(
        json['inMyFriendList'] ?? json['in_my_friend_list'],
        fallback: true,
      ),
      isFriend: _readBool(json['isFriend'] ?? json['is_friend'], fallback: true),
      peerDeletedMe: _readBool(
        json['peerDeletedMe'] ?? json['peer_deleted_me'],
        fallback: false,
      ),
      canMessage: _readBool(
        json['canMessage'] ?? json['can_message'],
        fallback: true,
      ),
      lastActiveAt: _readOptionalInt(
        json['lastActiveAt'] ?? json['last_active_at'],
      ),
      lastActiveVisibility: _readString(
        json['lastActiveVisibility'] ?? json['last_active_visibility'],
      ),
      tcpAction: (json['tcpAction'] ?? json['tcp_action'] ?? json['action'] ?? '')
          .toString()
          .trim(),
    );
  }

  static int _readInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static int? _readOptionalInt(dynamic value) {
    if (value == null) return null;
    final parsed = _readInt(value);
    return parsed == 0 && value.toString().trim().isEmpty ? null : parsed;
  }

  static bool _readBool(dynamic value, {required bool fallback}) {
    if (value == null) return fallback;
    if (value is bool) return value;
    if (value is num) return value != 0;
    final text = value.toString().trim().toLowerCase();
    if (text == 'true' || text == '1' || text == 'yes') return true;
    if (text == 'false' || text == '0' || text == 'no') return false;
    return fallback;
  }

  static String? _readString(dynamic value) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? null : text;
  }
}

class FriendContactChangesPage {
  const FriendContactChangesPage({
    required this.nextSeq,
    required this.hasMore,
    required this.events,
    this.total = 0,
  });

  final int nextSeq;
  final bool hasMore;
  final List<FriendContactChangeEvent> events;
  final int total;

  factory FriendContactChangesPage.fromJson(Map<String, dynamic> json) {
    final rawEvents = json['events'] ?? json['items'] ?? json['changes'];
    final events = <FriendContactChangeEvent>[];
    if (rawEvents is List) {
      for (final item in rawEvents) {
        if (item is Map) {
          final event = FriendContactChangeEvent.fromJson(
            Map<String, dynamic>.from(item),
          );
          if (event.peerUserId.isNotEmpty || event.seq > 0) {
            events.add(event);
          }
        }
      }
    }
    final nextSeq = FriendContactChangeEvent._readInt(
      json['next_seq'] ?? json['nextSeq'] ?? json['seq'],
    );
    final inferredNext = nextSeq > 0
        ? nextSeq
        : events.fold<int>(0, (max, e) => e.seq > max ? e.seq : max);
    return FriendContactChangesPage(
      nextSeq: inferredNext,
      hasMore: FriendContactChangeEvent._readBool(
        json['has_more'] ?? json['hasMore'],
        fallback: false,
      ),
      events: events,
      total: FriendContactChangeEvent._readInt(json['total']),
    );
  }
}

/// 游标过期：应 Snapshot `/me/friends` 后用 `syncSeq` 重置。
class FriendContactSnapshotRequiredException implements Exception {
  FriendContactSnapshotRequiredException([this.code = 'SNAPSHOT_REQUIRED']);

  final String code;

  @override
  String toString() => 'FriendContactSnapshotRequiredException($code)';
}
