import 'package:tencent_cloud_chat_sdk/models/v2_tim_friend_application.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_friend_application.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/friend_add_source.dart';

class FriendRequestDirection {
  FriendRequestDirection._();

  static const String incoming = 'incoming';
  static const String outgoing = 'outgoing';
  static const String unknown = 'unknown';
}

class FriendRequestRecord {
  FriendRequestRecord({
    this.id,
    required this.userID,
    required this.nickname,
    required this.faceUrl,
    required this.addWording,
    required this.addSource,
    required this.addTime,
    required this.status,
    this.handledAt = 0,
    this.fromUserId = '',
    this.toUserId = '',
    this.direction = FriendRequestDirection.unknown,
  });

  final int? id;

  /// 当前页面展示的对方用户 ID（优先 API `peerUserId`）。
  final String userID;
  final String nickname;
  final String faceUrl;
  final String addWording;
  final String addSource;
  final int addTime;
  final String status;
  final int handledAt;
  final String fromUserId;
  final String toUserId;
  final String direction;

  factory FriendRequestRecord.fromApplication(
    V2TimFriendApplication application, {
    required String status,
    int? handledAt,
  }) {
    final rawSource = FriendAddSource.resolveRawSource(
      application.addSource,
      application.addWording,
    );
    return FriendRequestRecord(
      userID: application.userID,
      nickname: application.nickname ?? application.userID,
      faceUrl: application.faceUrl ?? '',
      addWording: FriendAddSource.stripFromWording(application.addWording),
      addSource: _normalizeAddSource(rawSource),
      addTime: _asInt(application.addTime),
      status: status.trim().toLowerCase(),
      handledAt: handledAt ?? DateTime.now().millisecondsSinceEpoch,
    );
  }

  factory FriendRequestRecord.fromPendingJson(
    Map<String, dynamic> json, {
    required String direction,
  }) {
    final fromUserId = _asString(json['fromUserId'] ?? json['from_user_id']);
    final toUserId = _asString(json['toUserId'] ?? json['to_user_id']);
    final peerUserId = _asString(
      json['peerUserId'] ??
          json['peer_user_id'] ??
          (direction == FriendRequestDirection.outgoing ? toUserId : fromUserId),
    );
    final nickname = _asString(
      json['peerNickname'] ??
          json['peer_nickname'] ??
          (direction == FriendRequestDirection.outgoing
              ? json['toNickname'] ??
                  json['toNickName'] ??
                  json['targetNickname']
              : json['fromNickname'] ?? json['fromNickName']) ??
          json['nickname'] ??
          json['showName'],
    );
    final avatar = _asString(
      json['peerAvatarUrl'] ??
          json['peer_avatar_url'] ??
          (direction == FriendRequestDirection.outgoing
              ? json['toAvatarUrl'] ?? json['targetAvatarUrl']
              : json['fromAvatarUrl']) ??
          json['avatarUrl'] ??
          json['faceUrl'],
    );
    final addTime = _parseTimestamp(
      json['createdAt'] ?? json['addTime'] ?? json['requestTime'],
    );
    final status = _asString(json['status'], fallback: 'pending').toLowerCase();
    final handledAt = status == 'pending'
        ? 0
        : _parseTimestamp(
            json['updatedAt'] ??
                json['updated_at'] ??
                json['handledAt'] ??
                json['handled_at'] ??
                json['createdAt'],
          );
    return FriendRequestRecord(
      id: _parseOptionalId(json['id'] ?? json['requestId']),
      fromUserId: fromUserId,
      toUserId: toUserId,
      userID: peerUserId,
      nickname: nickname.isNotEmpty ? nickname : peerUserId,
      faceUrl: avatar,
      addWording: FriendAddSource.stripFromWording(
        _asString(json['addWording'] ?? json['verifyMessage']),
      ),
      addSource: _normalizeAddSource(
        _asString(json['addSource'], fallback: 'search'),
      ),
      addTime: addTime,
      status: status,
      handledAt: handledAt,
      direction: direction,
    );
  }

  factory FriendRequestRecord.fromJson(Map<String, dynamic> json) {
    final direction = _normalizeDirection(json['direction']);
    final fromUserId = _asString(json['fromUserId'] ?? json['from_user_id']);
    final toUserId = _asString(json['toUserId'] ?? json['to_user_id']);
    final peerUserId = _asString(
      json['peerUserId'] ??
          json['userID'] ??
          json['userId'] ??
          (direction == FriendRequestDirection.outgoing ? toUserId : fromUserId),
    );
    final addTime = _parseTimestamp(
      json['addTime'] ?? json['requestTime'] ?? json['createdAt'],
    );
    final handledAt = _parseTimestamp(json['handledAt'] ?? json['updatedAt']);
    return FriendRequestRecord(
      userID: peerUserId,
      nickname: _asString(
        json['peerNickname'] ?? json['nickname'] ?? json['showName'],
        fallback: peerUserId,
      ),
      faceUrl: _asString(
        json['peerAvatarUrl'] ??
            json['peer_avatar_url'] ??
            json['peerFaceUrl'] ??
            json['faceUrl'] ??
            json['avatarUrl'],
      ),
      addWording: FriendAddSource.stripFromWording(
        _asString(json['addWording'] ?? json['verifyMessage']),
      ),
      addSource: _normalizeAddSource(
        _asString(json['addSource'], fallback: 'search'),
      ),
      addTime: addTime,
      status: _asString(json['status'], fallback: 'accepted').toLowerCase(),
      handledAt: handledAt > 0 ? handledAt : addTime,
      id: _parseOptionalId(json['id'] ?? json['requestId']),
      fromUserId: fromUserId,
      toUserId: toUserId,
      direction: direction,
    );
  }

  bool get hasServerId => id != null && id! > 0;

  bool get isIncoming => direction == FriendRequestDirection.incoming;
  bool get isOutgoing => direction == FriendRequestDirection.outgoing;
  bool get isPending => status == 'pending';

  int get displayTimestamp => handledAt > 0 ? handledAt : addTime;

  String get identityKey {
    if (hasServerId) {
      return 'id_$id';
    }
    return '${direction}_${userID}_${addTime}_$status';
  }

  Map<String, dynamic> toLocalJson() => {
        if (hasServerId) 'id': id,
        'userID': userID,
        'nickname': nickname,
        'faceUrl': faceUrl,
        'addWording': addWording,
        'addSource': addSource,
        'addTime': addTime,
        'status': status,
        'handledAt': handledAt,
        'fromUserId': fromUserId,
        'toUserId': toUserId,
        'direction': direction,
      };

  Map<String, dynamic> toActionJson() => {
        if (hasServerId) 'id': id,
        'peerUserId': userID,
        'addTime': DateTime.fromMillisecondsSinceEpoch(
          addTime,
          isUtc: true,
        ).toIso8601String(),
        if (addWording.trim().isNotEmpty) 'addWording': addWording.trim(),
        'addSource': addSource,
      };

  FriendRequestRecord copyWith({
    int? id,
    String? userID,
    String? nickname,
    String? faceUrl,
    String? addWording,
    String? addSource,
    int? addTime,
    String? status,
    int? handledAt,
    String? fromUserId,
    String? toUserId,
    String? direction,
  }) {
    return FriendRequestRecord(
      id: id ?? this.id,
      userID: userID ?? this.userID,
      nickname: nickname ?? this.nickname,
      faceUrl: faceUrl ?? this.faceUrl,
      addWording: addWording ?? this.addWording,
      addSource: addSource ?? this.addSource,
      addTime: addTime ?? this.addTime,
      status: status ?? this.status,
      handledAt: handledAt ?? this.handledAt,
      fromUserId: fromUserId ?? this.fromUserId,
      toUserId: toUserId ?? this.toUserId,
      direction: direction ?? this.direction,
    );
  }
}

String _asString(Object? value, {String fallback = ''}) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? fallback : text;
}

int _asInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

int? _parseOptionalId(Object? value) {
  if (value == null) {
    return null;
  }
  if (value is int) {
    return value > 0 ? value : null;
  }
  if (value is num) {
    final parsed = value.toInt();
    return parsed > 0 ? parsed : null;
  }
  final parsed = int.tryParse(value.toString().trim());
  return parsed != null && parsed > 0 ? parsed : null;
}

int _parseTimestamp(Object? value) {
  if (value == null) return 0;
  if (value is int) {
    return value < 1000000000000 ? value * 1000 : value;
  }
  if (value is num) {
    final intValue = value.toInt();
    return intValue < 1000000000000 ? intValue * 1000 : intValue;
  }
  final text = value.toString().trim();
  if (text.isEmpty) return 0;
  final numeric = int.tryParse(text);
  if (numeric != null) {
    return numeric < 1000000000000 ? numeric * 1000 : numeric;
  }
  final dt = DateTime.tryParse(text);
  if (dt == null) return 0;
  return dt.toUtc().millisecondsSinceEpoch;
}

String _normalizeDirection(Object? raw) {
  final value = raw?.toString().trim().toLowerCase() ?? '';
  if (value == 'incoming' || value == 'in' || value == 'come_in') {
    return FriendRequestDirection.incoming;
  }
  if (value == 'outgoing' || value == 'out' || value == 'send_out') {
    return FriendRequestDirection.outgoing;
  }
  return FriendRequestDirection.unknown;
}

String _normalizeAddSource(String? raw) {
  final value = (raw ?? '').trim();
  if (value.isEmpty) {
    return 'search';
  }
  final normalized = value
      .toLowerCase()
      .replaceAll('-', '_')
      .replaceAll('addsource_type_', '')
      .replaceAll('addsource_', '')
      .replaceAll('_', '');
  switch (normalized) {
    case 'qrcode':
    case 'qr':
      return 'qr_code';
    case 'phone':
    case 'mobile':
    case 'contact':
      return 'phone';
    case 'nearby':
      return 'nearby';
    case 'card':
    case 'contactcard':
      return 'card';
    case 'group':
      return 'group';
    case 'search':
    case 'chat':
    case 'android':
    case 'ios':
    case 'iphone':
    case 'web':
    case 'h5':
    case 'unknown':
    case 'unknow':
      return 'search';
    default:
      if (normalized.startsWith('group')) {
        return 'group';
      }
      return 'search';
  }
}
