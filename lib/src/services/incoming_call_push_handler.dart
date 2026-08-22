import 'package:flutter/foundation.dart';

/// 音视频 inviteId 去重（PushKit 与 IM av_call 信令双通道，§10.3 / §12.1）。
class IncomingCallPushHandler {
  IncomingCallPushHandler._();

  static final IncomingCallPushHandler instance = IncomingCallPushHandler._();

  final Map<String, DateTime> _handledInvites = <String, DateTime>{};
  static const Duration _ttl = Duration(minutes: 10);

  bool shouldHandleInvite(String? inviteId) {
    final id = inviteId?.trim() ?? '';
    if (id.isEmpty) {
      return true;
    }
    _purgeExpired();
    if (_handledInvites.containsKey(id)) {
      if (kDebugMode) {
        debugPrint('IncomingCallPush: skip duplicate inviteId=$id');
      }
      return false;
    }
    _handledInvites[id] = DateTime.now();
    return true;
  }

  void noteInviteHandled(String? inviteId) {
    final id = inviteId?.trim() ?? '';
    if (id.isEmpty) {
      return;
    }
    _handledInvites[id] = DateTime.now();
  }

  void clear() {
    _handledInvites.clear();
  }

  void _purgeExpired() {
    final now = DateTime.now();
    _handledInvites.removeWhere((_, at) => now.difference(at) > _ttl);
  }
}
