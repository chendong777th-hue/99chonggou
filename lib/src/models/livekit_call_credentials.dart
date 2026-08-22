class LiveKitCallCredentials {
  const LiveKitCallCredentials({
    required this.callId,
    required this.roomName,
    required this.url,
    required this.token,
    required this.mediaType,
    required this.callerUserId,
    required this.calleeUserId,
    this.expiresAt = 0,
    this.timeoutSec = 60,
  });

  final String callId;
  final String roomName;
  final String url;
  final String token;
  final String mediaType;
  final String callerUserId;
  final String calleeUserId;
  final int expiresAt;
  final int timeoutSec;

  bool get isVideo => mediaType.trim().toLowerCase() == 'video';

  factory LiveKitCallCredentials.fromJson(Map<String, dynamic> json) {
    return LiveKitCallCredentials(
      callId: _str(json, const ['callId', 'call_id', 'inviteId', 'inviteID']),
      roomName: _str(json, const ['roomName', 'room_name', 'roomId', 'room_id']),
      url: _str(json, const ['url', 'wsUrl', 'serverUrl']),
      token: _str(json, const ['token', 'accessToken']),
      mediaType: _str(json, const ['mediaType', 'media_type'], fallback: 'audio')
          .toLowerCase(),
      callerUserId: _str(json, const ['callerUserId', 'callerId', 'caller_id']),
      calleeUserId: _str(json, const ['calleeUserId', 'calleeId', 'callee_id']),
      expiresAt: _int(json, const ['expiresAt', 'expires_at']),
      timeoutSec: _int(json, const ['timeoutSec', 'timeout_sec'], fallback: 60),
    );
  }

  static String _str(
    Map<String, dynamic> json,
    List<String> keys, {
    String fallback = '',
  }) {
    for (final key in keys) {
      final value = json[key]?.toString().trim() ?? '';
      if (value.isNotEmpty) return value;
    }
    return fallback;
  }

  static int _int(
    Map<String, dynamic> json,
    List<String> keys, {
    int fallback = 0,
  }) {
    for (final key in keys) {
      final raw = json[key];
      if (raw is int) return raw;
      if (raw is num) return raw.toInt();
      final parsed = int.tryParse(raw?.toString() ?? '');
      if (parsed != null) return parsed;
    }
    return fallback;
  }
}
