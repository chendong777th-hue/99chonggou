import 'package:tencent_cloud_chat_demo/src/utils/call_user_id.dart';

/// 自建 VoIP / 通话 Push payload 解析（iOS PushKit、Android 极光、路由点击）。
class VoipPushPayload {
  VoipPushPayload._();

  /// Small transport/clock allowance on top of the server ringing timeout.
  static const Duration inviteExpiryGrace = Duration(seconds: 5);

  static const List<String> _callerNameKeys = <String>[
    'callerName',
    'callerNick',
    'nickName',
    'nickname',
    'senderName',
  ];

  static bool isCallPushType(String? type) {
    final normalized = type?.trim().toLowerCase() ?? '';
    // LiveKit cutover: only lk_call enters the call path.
    // Legacy av_call / rtc_call are ignored for answering.
    return normalized == 'lk_call';
  }

  static bool isLegacyTrtcCallPushType(String? type) {
    final normalized = type?.trim().toLowerCase() ?? '';
    return normalized == 'av_call' || normalized == 'rtc_call';
  }

  static bool isCallCancelPushType(String? type) {
    final normalized = type?.trim().toLowerCase() ?? '';
    if (normalized.isEmpty) {
      return false;
    }
    if (normalized.contains('cancel') ||
        normalized.contains('hangup') ||
        normalized.contains('reject') ||
        normalized.contains('end')) {
      return true;
    }
    return const {
      'av_call_cancel',
      'rtc_call_cancel',
      'call_cancel',
      'call_cancelled',
      'call_canceled',
      'call_end',
      'call_hangup',
    }.contains(normalized);
  }

  static bool shouldEndCall(Map<String, dynamic> data) {
    final type = data['type']?.toString().trim().toLowerCase() ?? '';
    if (isCallCancelPushType(type)) {
      return true;
    }
    if (_isTruthyCallEndFlag(data['call_end'] ?? data['callEnd'])) {
      return true;
    }

    String? action;
    for (final key in const [
      'action',
      'event',
      'cmd',
      'command',
      'callAction'
    ]) {
      final value = data[key]?.toString().trim().toLowerCase() ?? '';
      if (value.isNotEmpty) {
        action = value;
        break;
      }
    }
    if (action == null || action.isEmpty) {
      return false;
    }

    // 显式终态（含 answered_elsewhere；勿用 contains('end') 误伤）
    if (_terminalCallActions.contains(action)) {
      return true;
    }

    // lk_call：仅 invite 可展示来电；其它 action 一律停铃
    if (isCallPushType(type) && action != 'invite') {
      return true;
    }
    return false;
  }

  static const Set<String> _terminalCallActions = <String>{
    'answered_elsewhere',
    'reject',
    'rejected',
    'cancel',
    'canceled',
    'cancelled',
    'hangup',
    'hang_up',
    'end',
    'ended',
    'timeout',
    'busy',
  };

  static bool _isTruthyCallEndFlag(Object? raw) {
    if (raw == true || raw == 1) return true;
    final text = raw?.toString().trim().toLowerCase() ?? '';
    return text == '1' || text == 'true' || text == 'yes';
  }

  static bool isCalleeForCurrentUser(
    Map<String, dynamic> data,
    String? loginUserId,
  ) {
    final selfId = normalizeUserId(loginUserId);
    if (selfId.isEmpty) {
      return true;
    }
    final calleeId = normalizeUserId(data['calleeId']?.toString());
    if (calleeId.isEmpty) {
      return true;
    }
    return calleeId == selfId;
  }

  static String normalizeUserId(String? raw) =>
      CallUserId.normalizeCallUserId(raw?.trim() ?? '');

  static String? readInviteId(Map<String, dynamic> data) {
    for (final key in const [
      'inviteId',
      'inviteID',
      'callId',
      'callID',
      'call_id',
    ]) {
      final value = data[key]?.toString().trim() ?? '';
      if (value.isNotEmpty) {
        return value;
      }
    }
    return null;
  }

  /// Whether an incoming invite is already too old to present.
  ///
  /// IM timestamps are passed explicitly by the signaling listener. Native
  /// PushKit also stamps cached payloads with `_receivedAtMs`, so a process
  /// woken for a call cannot replay that invite when the user opens the app
  /// after the call has timed out.
  static bool isExpiredInvite(
    Map<String, dynamic> data, {
    DateTime? receivedAt,
    DateTime? now,
  }) {
    final action = data['action']?.toString().trim().toLowerCase() ?? '';
    if (action.isNotEmpty && action != 'invite') {
      return false;
    }
    final timestamp = receivedAt ?? _readTimestamp(data);
    if (timestamp == null) {
      return false;
    }
    final timeoutRaw = int.tryParse(data['timeoutSec']?.toString() ?? '');
    final timeoutSec =
        (timeoutRaw == null || timeoutRaw <= 0) ? 60 : timeoutRaw.clamp(1, 300);
    final expiresAt = timestamp.add(
      Duration(seconds: timeoutSec) + inviteExpiryGrace,
    );
    return (now ?? DateTime.now()).isAfter(expiresAt);
  }

  static DateTime? _readTimestamp(Map<String, dynamic> data) {
    for (final key in const [
      '_receivedAtMs',
      'sentAtMs',
      'timestampMs',
      'pushTs',
      'timestamp',
      'sentAt',
    ]) {
      final raw = data[key];
      final value =
          raw is num ? raw.toInt() : int.tryParse(raw?.toString() ?? '');
      if (value == null || value <= 0) continue;
      // Current epoch seconds are 10 digits; millisecond values are 13 digits.
      final milliseconds = value < 100000000000 ? value * 1000 : value;
      return DateTime.fromMillisecondsSinceEpoch(milliseconds);
    }
    return null;
  }

  static String readMediaType(Map<String, dynamic> data) {
    final mediaType = data['mediaType']?.toString().trim().toLowerCase() ?? '';
    return mediaType == 'video' ? 'video' : 'audio';
  }

  static String? readGroupId(Map<String, dynamic> data) {
    for (final key in const ['groupId', 'groupID', 'group_id']) {
      final value = data[key]?.toString().trim() ?? '';
      if (value.isNotEmpty) {
        return value;
      }
    }
    return null;
  }

  /// 读取 push 内主叫展示名；不含 `#` 的复合 TRTC ID。
  static String readCallerName(Map<String, dynamic> data) {
    for (final key in _callerNameKeys) {
      final value = data[key]?.toString().trim() ?? '';
      if (_isValidDisplayName(value)) {
        return value;
      }
    }
    return '';
  }

  static bool _isValidDisplayName(String value) {
    final text = value.trim();
    return text.isNotEmpty && !text.contains('#');
  }
}
