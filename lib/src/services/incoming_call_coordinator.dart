import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:tencent_cloud_chat_demo/src/services/incoming_call_push_handler.dart';
import 'package:tencent_cloud_chat_demo/src/services/ios_apns_push_service.dart';
import 'package:tencent_cloud_chat_demo/src/services/livekit_call_navigator.dart';
import 'package:tencent_cloud_chat_demo/src/services/livekit_call_session.dart';
import 'package:tencent_cloud_chat_demo/src/services/notification_settings_service.dart';
import 'package:tencent_cloud_chat_demo/src/utils/voip_push_payload.dart';
import 'package:tencent_cloud_chat_sdk/tencent_im_sdk_plugin.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/services/display_name_store.dart';

/// iOS 自建 VoIP Push 与 IM lk_call 信令协同。
class IncomingCallCoordinator {
  IncomingCallCoordinator._();

  static final IncomingCallCoordinator instance = IncomingCallCoordinator._();

  final Map<String, _PendingIncomingCall> _pending =
      <String, _PendingIncomingCall>{};
  static const Duration _pendingTtl = Duration(minutes: 2);

  Future<void> handleVoipPush(Map<String, dynamic> data) async {
    if (!Platform.isIOS) {
      return;
    }
    final allowSystemCallUi =
        await NotificationSettingsService.instance.resolveAllowsCallNotify();
    final type = data['type']?.toString().trim().toLowerCase() ?? '';
    if (!VoipPushPayload.isCallPushType(type)) {
      // Ignore legacy TRTC VoIP payloads in LiveKit cutover.
      return;
    }
    // 终态 VoIP：只停铃，禁止再 presentIncoming / 弹 CallKit。
    if (VoipPushPayload.shouldEndCall(data)) {
      final inviteId = VoipPushPayload.readInviteId(data);
      if (inviteId != null && inviteId.isNotEmpty) {
        final session = LiveKitCallSession.instance;
        if (session.callId.isEmpty || session.callId == inviteId) {
          await session.handleRemoteAction(
            (data['action'] ?? 'hangup').toString(),
          );
        }
        _pending.remove(inviteId);
      }
      await IosApnsPushService.instance.endVoipCallKit();
      return;
    }
    final inviteId = VoipPushPayload.readInviteId(data);
    if (inviteId == null) {
      return;
    }
    if (VoipPushPayload.isExpiredInvite(data)) {
      IncomingCallPushHandler.instance.noteInviteHandled(inviteId);
      await IosApnsPushService.instance.endVoipCallKit();
      if (kDebugMode) {
        debugPrint(
          'IncomingCallCoordinator: discard expired inviteId=$inviteId',
        );
      }
      return;
    }
    if (!IncomingCallPushHandler.instance.shouldHandleInvite(inviteId)) {
      return;
    }

    final callerId =
        VoipPushPayload.normalizeUserId(data['callerId']?.toString());
    final calleeId =
        VoipPushPayload.normalizeUserId(data['calleeId']?.toString());
    final groupId = VoipPushPayload.readGroupId(data) ?? '';
    final mediaType = VoipPushPayload.readMediaType(data);
    final callerName = VoipPushPayload.readCallerName(data);
    final roomName = (data['roomName'] ?? data['roomId'] ?? '').toString();
    if (callerId.isNotEmpty && callerName.isNotEmpty) {
      DisplayNameStore.instance.setC2C(callerId, callerName);
    }

    _pending[inviteId] = _PendingIncomingCall(
      inviteId: inviteId,
      callerId: callerId,
      calleeId: calleeId,
      groupId: groupId,
      mediaType: mediaType,
      receivedAt: DateTime.now(),
    );
    _purgeExpired();

    if (kDebugMode) {
      debugPrint(
        'IncomingCallCoordinator: voip push inviteId=$inviteId '
        'callerId=$callerId callerName=$callerName mediaType=$mediaType',
      );
    }

    unawaited(
      LiveKitCallSession.instance.presentIncoming(
        callId: inviteId,
        callerUserId: callerId,
        calleeUserId: calleeId,
        mediaType: mediaType,
        roomName: roomName,
      ),
    );
    if (!allowSystemCallUi) {
      await IosApnsPushService.instance.endVoipCallKit(inviteId: inviteId);
      unawaited(LiveKitCallNavigator.openCallPage());
      if (kDebugMode) {
        debugPrint(
          'IncomingCallCoordinator: call notifications disabled — '
          'present in-app fullscreen inviteId=$inviteId',
        );
      }
    }
    unawaited(_ensureImReadyForIncomingCall());
  }

  void noteImCallReceived({
    required String inviteId,
    required String callerId,
  }) {
    final id = inviteId.trim();
    if (id.isEmpty) {
      return;
    }
    IncomingCallPushHandler.instance.noteInviteHandled(id);
    _pending.remove(id);
    if (kDebugMode) {
      debugPrint(
        'IncomingCallCoordinator: IM call received inviteId=$id callerId=$callerId',
      );
    }
  }

  bool hasPendingInvite(String? inviteId) {
    final id = inviteId?.trim() ?? '';
    if (id.isEmpty) {
      return false;
    }
    _purgeExpired();
    return _pending.containsKey(id);
  }

  /// Best-effort peer for bubble conversation id when session creds lack ids.
  String? pendingCallerId(String? inviteId) {
    final id = inviteId?.trim() ?? '';
    if (id.isEmpty) {
      return null;
    }
    _purgeExpired();
    final pending = _pending[id];
    final caller = pending?.callerId.trim() ?? '';
    return caller.isEmpty ? null : caller;
  }

  String? pendingCalleeId(String? inviteId) {
    final id = inviteId?.trim() ?? '';
    if (id.isEmpty) {
      return null;
    }
    _purgeExpired();
    final pending = _pending[id];
    final callee = pending?.calleeId.trim() ?? '';
    return callee.isEmpty ? null : callee;
  }

  /// VoIP push media type for CallKit accept before IM lk_call arrives.
  String? pendingMediaType(String? inviteId) {
    final id = inviteId?.trim() ?? '';
    if (id.isEmpty) {
      return null;
    }
    _purgeExpired();
    final media = _pending[id]?.mediaType.trim() ?? '';
    return media.isEmpty ? null : media;
  }

  Future<void> _ensureImReadyForIncomingCall() async {
    try {
      final loginRes = await TencentImSDKPlugin.v2TIMManager.getLoginUser();
      final userId = loginRes.data?.trim() ?? '';
      if (userId.isNotEmpty) {
        unawaited(IosApnsPushService.instance.syncLoginUserId(userId));
        return;
      }
      if (kDebugMode) {
        debugPrint(
          'IncomingCallCoordinator: IM not logged in when VoIP push arrived',
        );
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('IncomingCallCoordinator: IM readiness check failed ($e)');
      }
    }
  }

  void clear() {
    _pending.clear();
  }

  void _purgeExpired() {
    final now = DateTime.now();
    _pending.removeWhere(
      (_, value) => now.difference(value.receivedAt) > _pendingTtl,
    );
  }
}

class _PendingIncomingCall {
  _PendingIncomingCall({
    required this.inviteId,
    required this.callerId,
    required this.calleeId,
    required this.groupId,
    required this.mediaType,
    required this.receivedAt,
  });

  final String inviteId;
  final String callerId;
  final String calleeId;
  final String groupId;
  final String mediaType;
  final DateTime receivedAt;
}
