// Group live session models (aligned with group-live-service v1.0).

enum GroupLiveStatus {
  scheduled,
  authorized,
  live,
  ended,
  banned,
  unknown;

  static GroupLiveStatus parse(String? raw) {
    switch (raw?.trim().toUpperCase()) {
      case 'SCHEDULED':
        return GroupLiveStatus.scheduled;
      case 'AUTHORIZED':
        return GroupLiveStatus.authorized;
      case 'LIVE':
        return GroupLiveStatus.live;
      case 'ENDED':
        return GroupLiveStatus.ended;
      case 'BANNED':
        return GroupLiveStatus.banned;
      default:
        return GroupLiveStatus.unknown;
    }
  }

  String get wire => name.toUpperCase();

  bool get isActiveSlot =>
      this == GroupLiveStatus.scheduled ||
      this == GroupLiveStatus.authorized ||
      this == GroupLiveStatus.live;
}

enum GroupLiveEndReason {
  normal,
  ownerStop,
  adminStop,
  disconnect,
  scheduleExpired,
  revoked,
  adminBan,
  unknown;

  static GroupLiveEndReason parse(String? raw) {
    switch (raw?.trim().toUpperCase()) {
      case 'NORMAL':
        return GroupLiveEndReason.normal;
      case 'OWNER_STOP':
        return GroupLiveEndReason.ownerStop;
      case 'ADMIN_STOP':
        return GroupLiveEndReason.adminStop;
      case 'DISCONNECT':
        return GroupLiveEndReason.disconnect;
      case 'SCHEDULE_EXPIRED':
        return GroupLiveEndReason.scheduleExpired;
      case 'REVOKED':
        return GroupLiveEndReason.revoked;
      case 'ADMIN_BAN':
        return GroupLiveEndReason.adminBan;
      default:
        return GroupLiveEndReason.unknown;
    }
  }
}

class GroupLiveSession {
  const GroupLiveSession({
    required this.liveSessionId,
    required this.groupId,
    required this.roomName,
    required this.anchorUserId,
    required this.status,
    this.scheduledStartAt,
    this.expireAt,
    this.startedAt,
    this.endedAt,
    this.endReason,
  });

  final String liveSessionId;
  final String groupId;
  final String roomName;
  final String anchorUserId;
  final GroupLiveStatus status;
  final DateTime? scheduledStartAt;
  final DateTime? expireAt;
  final DateTime? startedAt;
  final DateTime? endedAt;
  final GroupLiveEndReason? endReason;

  bool get isLive => status == GroupLiveStatus.live;

  factory GroupLiveSession.fromJson(Map<String, dynamic> json) {
    return GroupLiveSession(
      liveSessionId: _str(json, const ['liveSessionId']),
      groupId: _str(json, const ['groupId']),
      roomName: _str(json, const ['roomName']),
      anchorUserId: _str(json, const ['anchorUserId']),
      status: GroupLiveStatus.parse(_str(json, const ['status'])),
      scheduledStartAt: _date(json['scheduledStartAt']),
      expireAt: _date(json['expireAt']),
      startedAt: _date(json['startedAt']),
      endedAt: _date(json['endedAt']),
      endReason: json['endReason'] == null
          ? null
          : GroupLiveEndReason.parse(json['endReason']?.toString()),
    );
  }
}

class GroupLiveCurrentSnapshot {
  const GroupLiveCurrentSnapshot.inactive()
      : active = false,
        session = null;

  const GroupLiveCurrentSnapshot.active(this.session) : active = true;

  final bool active;
  final GroupLiveSession? session;

  factory GroupLiveCurrentSnapshot.fromJson(Map<String, dynamic> json) {
    final activeRaw = json['active'];
    final isActive = activeRaw == true ||
        activeRaw?.toString().trim().toLowerCase() == 'true';
    final nested = json['session'];
    final sessionJson =
        nested is Map ? Map<String, dynamic>.from(nested) : json;
    final sessionId = sessionJson['liveSessionId']?.toString().trim() ?? '';
    if (!isActive && sessionId.isEmpty) {
      return const GroupLiveCurrentSnapshot.inactive();
    }
    if (!isActive) {
      return const GroupLiveCurrentSnapshot.inactive();
    }
    final session = GroupLiveSession.fromJson(sessionJson);
    if (session.liveSessionId.trim().isEmpty) {
      return const GroupLiveCurrentSnapshot.inactive();
    }
    return GroupLiveCurrentSnapshot.active(session);
  }
}

class GroupLivePushInfo {
  const GroupLivePushInfo({
    required this.liveSessionId,
    required this.roomName,
    required this.streamId,
    required this.rtmpServer,
    required this.streamKey,
    this.expiresAt,
    this.obsHint = '',
  });

  final String liveSessionId;
  final String roomName;
  final String streamId;
  final String rtmpServer;
  final String streamKey;
  final DateTime? expiresAt;
  final String obsHint;

  factory GroupLivePushInfo.fromJson(Map<String, dynamic> json) {
    return GroupLivePushInfo(
      liveSessionId: _str(json, const ['liveSessionId']),
      roomName: _str(json, const ['roomName']),
      streamId: _str(json, const ['streamId']),
      rtmpServer: _str(json, const ['rtmpServer']),
      streamKey: _str(json, const ['streamKey']),
      expiresAt: _date(json['expiresAt']),
      obsHint: _str(json, const ['obsHint']),
    );
  }
}

class GroupLivePlayInfo {
  const GroupLivePlayInfo({
    required this.liveSessionId,
    required this.roomName,
    required this.protocol,
    required this.playUrl,
    required this.anchorUserId,
    this.latencyMode = '',
    this.webrtcPlayUrl = '',
    this.playerSdk = '',
    this.fallbackFlvUrl = '',
    this.fallbackHlsUrl = '',
  });

  final String liveSessionId;
  final String roomName;
  final String protocol;
  final String playUrl;
  final String latencyMode;
  final String webrtcPlayUrl;
  final String playerSdk;
  final String fallbackFlvUrl;
  final String fallbackHlsUrl;
  final String anchorUserId;

  bool get usesTencentWebRtc {
    final sdk = playerSdk.trim();
    if (sdk.isNotEmpty && sdk != 'V2TXLivePlayer') {
      return false;
    }
    return primaryWebRtcUrl.isNotEmpty;
  }

  /// Primary ultra-low-latency WebRTC/LEB URL from play-info.
  String get primaryWebRtcUrl {
    final explicit = webrtcPlayUrl.trim();
    if (explicit.isNotEmpty) {
      return explicit;
    }
    final primary = playUrl.trim();
    if (_isWebRtcUrl(primary)) {
      return primary;
    }
    return '';
  }

  /// Ordered playback attempts: WebRTC → FLV → HLS.
  List<GroupLivePlaybackAttempt> get playbackAttempts {
    final attempts = <GroupLivePlaybackAttempt>[];
    final webrtc = primaryWebRtcUrl;
    if (webrtc.isNotEmpty) {
      attempts.add(
        GroupLivePlaybackAttempt(
          mode: GroupLivePlaybackMode.webrtc,
          url: webrtc,
        ),
      );
    }
    final flv = fallbackFlvUrl.trim();
    if (_isHttpUrl(flv)) {
      attempts.add(
        GroupLivePlaybackAttempt(
          mode: GroupLivePlaybackMode.flv,
          url: flv,
        ),
      );
    }
    final hls = fallbackHlsUrl.trim();
    if (_isHttpUrl(hls)) {
      attempts.add(
        GroupLivePlaybackAttempt(
          mode: GroupLivePlaybackMode.hls,
          url: hls,
        ),
      );
    }
    if (attempts.isEmpty) {
      final primary = playUrl.trim();
      if (_isHttpUrl(primary)) {
        attempts.add(
          GroupLivePlaybackAttempt(
            mode: primary.contains('.flv')
                ? GroupLivePlaybackMode.flv
                : GroupLivePlaybackMode.hls,
            url: primary,
          ),
        );
      }
    }
    return attempts;
  }

  static bool _isWebRtcUrl(String url) =>
      url.startsWith('webrtc://') || url.startsWith('trtc://');

  static bool _isHttpUrl(String url) =>
      url.startsWith('http://') || url.startsWith('https://');

  factory GroupLivePlayInfo.fromJson(Map<String, dynamic> json) {
    return GroupLivePlayInfo(
      liveSessionId: _str(json, const ['liveSessionId']),
      roomName: _str(json, const ['roomName']),
      protocol: _str(json, const ['protocol']),
      playUrl: _str(json, const ['playUrl']),
      latencyMode: _str(json, const ['latencyMode']),
      webrtcPlayUrl: _str(json, const ['webrtcPlayUrl']),
      playerSdk: _str(json, const ['playerSdk']),
      fallbackFlvUrl: _str(json, const ['fallbackFlvUrl']),
      fallbackHlsUrl: _str(json, const ['fallbackHlsUrl']),
      anchorUserId: _str(json, const ['anchorUserId']),
    );
  }
}

enum GroupLivePlaybackMode {
  webrtc,
  flv,
  hls,
}

class GroupLivePlaybackAttempt {
  const GroupLivePlaybackAttempt({
    required this.mode,
    required this.url,
  });

  final GroupLivePlaybackMode mode;
  final String url;
}

/// One row from `GET /me/live-index` or TCP `group_live_changed` detail.
class GroupLiveIndexItem {
  const GroupLiveIndexItem({
    required this.groupId,
    required this.liveSessionId,
    required this.status,
    required this.version,
    this.roomName = '',
    this.anchorUserId = '',
    this.scheduledStartAt,
    this.startedAt,
  });

  final String groupId;
  final String liveSessionId;
  final GroupLiveStatus status;
  final int version;
  final String roomName;
  final String anchorUserId;
  final DateTime? scheduledStartAt;
  final DateTime? startedAt;

  bool get isLive => status == GroupLiveStatus.live;

  GroupLiveSession toSession() {
    return GroupLiveSession(
      liveSessionId: liveSessionId,
      groupId: groupId,
      roomName: roomName,
      anchorUserId: anchorUserId,
      status: status,
      scheduledStartAt: scheduledStartAt,
      startedAt: startedAt,
    );
  }

  factory GroupLiveIndexItem.fromJson(Map<String, dynamic> json) {
    return GroupLiveIndexItem(
      groupId: _str(json, const ['groupId']),
      liveSessionId: _str(json, const ['liveSessionId']),
      status: GroupLiveStatus.parse(_str(json, const ['status'])),
      version: _int(json, const ['version']),
      roomName: _str(json, const ['roomName']),
      anchorUserId: _str(json, const ['anchorUserId']),
      scheduledStartAt: _date(json['scheduledStartAt']),
      startedAt: _date(json['startedAt']),
    );
  }

  factory GroupLiveIndexItem.fromTcpDetail(
    Map<String, dynamic> detail, {
    required String groupId,
  }) {
    return GroupLiveIndexItem(
      groupId: groupId,
      liveSessionId: _str(detail, const ['liveSessionId']),
      status: GroupLiveStatus.parse(_str(detail, const ['status'])),
      version: _int(detail, const ['version']),
      roomName: _str(detail, const ['roomName']),
      anchorUserId: _str(detail, const ['anchorUserId']),
      scheduledStartAt: _date(detail['scheduledStartAt']),
      startedAt: _date(detail['startedAt']),
    );
  }
}

class GroupLiveIndexSnapshot {
  const GroupLiveIndexSnapshot({
    required this.revision,
    required this.items,
    this.updatedAt,
  });

  final int revision;
  final DateTime? updatedAt;
  final List<GroupLiveIndexItem> items;

  factory GroupLiveIndexSnapshot.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'];
    final items = <GroupLiveIndexItem>[];
    if (rawItems is List) {
      for (final entry in rawItems) {
        if (entry is! Map) {
          continue;
        }
        final item = GroupLiveIndexItem.fromJson(
          Map<String, dynamic>.from(entry),
        );
        if (item.groupId.trim().isEmpty) {
          continue;
        }
        if (!item.status.isActiveSlot) {
          continue;
        }
        items.add(item);
      }
    }
    return GroupLiveIndexSnapshot(
      revision: _int(json, const ['revision']),
      updatedAt: _date(json['updatedAt']),
      items: items,
    );
  }
}

enum GroupLiveIndexFetchStatus {
  updated,
  notModified,
}

class GroupLiveIndexFetchResult {
  const GroupLiveIndexFetchResult._({
    required this.status,
    this.snapshot,
    this.etag,
  });

  const GroupLiveIndexFetchResult.updated({
    required GroupLiveIndexSnapshot snapshot,
    required String etag,
  }) : this._(
          status: GroupLiveIndexFetchStatus.updated,
          snapshot: snapshot,
          etag: etag,
        );

  const GroupLiveIndexFetchResult.notModified()
      : this._(status: GroupLiveIndexFetchStatus.notModified);

  final GroupLiveIndexFetchStatus status;
  final GroupLiveIndexSnapshot? snapshot;
  final String? etag;
}

class GroupLiveTipResult {
  const GroupLiveTipResult({
    required this.tipId,
    required this.liveSessionId,
    required this.fromUserId,
    required this.toUserId,
    required this.currency,
    required this.amount,
    required this.feeAmount,
    this.memo = '',
    this.createdAt,
  });

  final int tipId;
  final String liveSessionId;
  final String fromUserId;
  final String toUserId;
  final String currency;
  final int amount;
  final int feeAmount;
  final String memo;
  final DateTime? createdAt;

  factory GroupLiveTipResult.fromJson(Map<String, dynamic> json) {
    return GroupLiveTipResult(
      tipId: _int(json, const ['tipId']),
      liveSessionId: _str(json, const ['liveSessionId']),
      fromUserId: _str(json, const ['fromUserId']),
      toUserId: _str(json, const ['toUserId']),
      currency: _str(json, const ['currency']),
      amount: _int(json, const ['amount']),
      feeAmount: _int(json, const ['feeAmount']),
      memo: _str(json, const ['memo']),
      createdAt: _date(json['createdAt']),
    );
  }
}

String _str(Map<String, dynamic> json, List<String> keys,
    {String fallback = ''}) {
  for (final key in keys) {
    final value = json[key]?.toString().trim() ?? '';
    if (value.isNotEmpty && value != 'null') {
      return value;
    }
  }
  return fallback;
}

int _int(Map<String, dynamic> json, List<String> keys, {int fallback = 0}) {
  for (final key in keys) {
    final raw = json[key];
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    final parsed = int.tryParse(raw?.toString() ?? '');
    if (parsed != null) return parsed;
  }
  return fallback;
}

DateTime? _date(dynamic raw) {
  if (raw == null) return null;
  final text = raw.toString().trim();
  if (text.isEmpty || text == 'null') return null;
  return DateTime.tryParse(text);
}
