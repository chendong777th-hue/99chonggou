import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:tencent_cloud_chat_demo/src/services/incoming_call_coordinator.dart';
import 'package:tencent_cloud_chat_demo/src/services/incoming_call_push_handler.dart';
import 'package:tencent_cloud_chat_demo/src/services/ios_apns_push_service.dart';
import 'package:tencent_cloud_chat_demo/src/services/livekit_call_navigator.dart';
import 'package:tencent_cloud_chat_demo/src/services/livekit_call_ringtone.dart';
import 'package:tencent_cloud_chat_demo/src/services/livekit_call_session.dart';
import 'package:tencent_cloud_chat_demo/src/services/livekit_call_ui_log.dart';
import 'package:tencent_cloud_chat_demo/src/services/call_result_record.dart';
import 'package:tencent_cloud_chat_demo/src/services/call_result_repository.dart';
import 'package:tencent_cloud_chat_demo/src/services/call_result_enrichment_service.dart';
import 'package:tencent_cloud_chat_demo/src/services/call_bubble_insert_service.dart';
import 'package:tencent_cloud_chat_demo/src/services/notification_settings_service.dart';
import 'package:tencent_cloud_chat_demo/src/utils/call_user_id.dart';
import 'package:tencent_cloud_chat_demo/src/utils/voip_push_payload.dart';
import 'package:tencent_cloud_chat_sdk/enum/V2TimAdvancedMsgListener.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_message.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_message.dart';
import 'package:tencent_cloud_chat_sdk/tencent_im_sdk_plugin.dart';
import 'package:tencent_cloud_chat_uikit/tencent_cloud_chat_uikit.dart';

/// Whether to push the Flutter fullscreen incoming-call page.
///
/// System CallKit / 推送受「通话通知」开关约束；关掉后仍要弹出应用内全屏来电页。
@visibleForTesting
bool shouldOpenInAppIncomingCallPage({
  required bool callNotificationEnabled,
  required bool systemIncomingUiAlreadyPresent,
}) {
  if (!callNotificationEnabled) {
    return true;
  }
  return !systemIncomingUiAlreadyPresent;
}

/// Listens for IM custom messages with businessID=lk_call.
class LiveKitCallSignaling {
  LiveKitCallSignaling._();

  static final LiveKitCallSignaling instance = LiveKitCallSignaling._();

  V2TimAdvancedMsgListener? _listener;
  bool _attached = false;

  Future<void> ensureAttached() async {
    if (_attached) return;
    _listener = V2TimAdvancedMsgListener(
      onRecvNewMessage: (message) {
        unawaited(_onMessage(message));
      },
    );
    await TencentImSDKPlugin.v2TIMManager
        .getMessageManager()
        .addAdvancedMsgListener(listener: _listener!);
    _attached = true;
    if (kDebugMode) {
      debugPrint('LiveKitCallSignaling: attached');
    }
  }

  Future<void> detach() async {
    final listener = _listener;
    _listener = null;
    _attached = false;
    if (listener == null) return;
    try {
      await TencentImSDKPlugin.v2TIMManager
          .getMessageManager()
          .removeAdvancedMsgListener(listener: listener);
    } catch (_) {}
  }

  Future<void> _onMessage(V2TimMessage message) async {
    final data = message.customElem?.data?.trim() ?? '';
    if (data.isEmpty) return;
    Map<String, dynamic>? map;
    try {
      final decoded = jsonDecode(data);
      if (decoded is Map) {
        map = Map<String, dynamic>.from(decoded);
      }
    } catch (_) {
      return;
    }
    if (map == null) return;

    var payload = map;
    final nested = map['data'];
    if (nested is String && nested.trim().startsWith('{')) {
      try {
        final inner = jsonDecode(nested);
        if (inner is Map) {
          payload = Map<String, dynamic>.from(inner);
        }
      } catch (_) {}
    } else if (nested is Map) {
      payload = Map<String, dynamic>.from(nested);
    }

    final businessId =
        (payload['businessID'] ?? map['businessID'] ?? '').toString().trim();
    if (businessId != 'lk_call') {
      return;
    }

    final action = (payload['action'] ?? map['action'] ?? '')
        .toString()
        .trim()
        .toLowerCase();
    final callId = (payload['callId'] ??
            payload['inviteId'] ??
            map['callId'] ??
            map['inviteId'] ??
            '')
        .toString()
        .trim();
    if (callId.isEmpty || action.isEmpty) return;

    final callerId = CallUserId.normalizeCallUserId(
      (payload['callerId'] ?? map['callerId'] ?? '').toString(),
    );
    final calleeId = CallUserId.normalizeCallUserId(
      (payload['calleeId'] ?? map['calleeId'] ?? '').toString(),
    );
    final mediaType =
        (payload['mediaType'] ?? map['mediaType'] ?? 'audio').toString();
    final roomName = (payload['roomName'] ?? map['roomName'] ?? '').toString();
    final timeoutSec = int.tryParse(
          (payload['timeoutSec'] ?? map['timeoutSec'] ?? '60').toString(),
        ) ??
        60;

    liveKitCallUiLog(
      'signaling action=$action callId=$callId '
      'caller=$callerId callee=$calleeId',
    );
    _mergeSignalingState(
      callId: callId,
      action: action,
      callerId: callerId,
      calleeId: calleeId,
      mediaType: mediaType,
      roomName: roomName,
    );
    if (kDebugMode) {
      debugPrint(
        'LiveKitCallSignaling: action=$action callId=$callId '
        'caller=$callerId callee=$calleeId',
      );
    }

    final session = LiveKitCallSession.instance;
    switch (action) {
      case 'invite':
        final callNotifyEnabled =
            NotificationSettingsService.instance.allowsCallNotify;
        if (!callNotifyEnabled) {
          await IosApnsPushService.instance.endVoipCallKit(inviteId: callId);
          if (kDebugMode) {
            debugPrint(
              'LiveKitCallSignaling: call notifications disabled — '
              'still present in-app fullscreen',
            );
          }
        }
        final messageTimestamp = message.timestamp ?? 0;
        if (messageTimestamp > 0 &&
            VoipPushPayload.isExpiredInvite(
              <String, dynamic>{...map, ...payload, 'timeoutSec': timeoutSec},
              receivedAt: DateTime.fromMillisecondsSinceEpoch(
                messageTimestamp * 1000,
              ),
            )) {
          IncomingCallPushHandler.instance.noteInviteHandled(callId);
          await IosApnsPushService.instance.endVoipCallKit();
          if (kDebugMode) {
            debugPrint(
              'LiveKitCallSignaling: discard expired invite callId=$callId '
              'timestamp=$messageTimestamp timeoutSec=$timeoutSec',
            );
          }
          return;
        }
        if (!IncomingCallPushHandler.instance.shouldHandleInvite(callId)) {
          return;
        }
        // 必须在 noteImCallReceived 之前判断：它会清掉 VoIP pending。
        final voipAlreadyPresent =
            IncomingCallCoordinator.instance.hasPendingInvite(callId) ||
                (session.callId == callId && session.isBusy);
        IncomingCallCoordinator.instance.noteImCallReceived(
          inviteId: callId,
          callerId: callerId,
        );
        await LiveKitCallRingtone.instance.ensureAttached();
        await session.presentIncoming(
          callId: callId,
          callerUserId: callerId,
          calleeUserId: calleeId,
          mediaType: mediaType,
          roomName: roomName,
          timeoutSec: timeoutSec,
        );
        // CallKit 已在响时不要再叠 Flutter 来电页；关掉通话通知后必须走全屏页。
        final openInApp = shouldOpenInAppIncomingCallPage(
          callNotificationEnabled: callNotifyEnabled,
          systemIncomingUiAlreadyPresent: voipAlreadyPresent,
        );
        liveKitCallUiLog(
          'signaling invite callId=$callId voipAlreadyPresent=$voipAlreadyPresent '
          'callNotify=$callNotifyEnabled openInApp=$openInApp '
          'pageMounted=${LiveKitCallNavigator.isCallPageMounted}',
        );
        if (openInApp) {
          unawaited(LiveKitCallNavigator.openCallPage());
        }
        break;
      case 'accept':
        if (session.callId.isNotEmpty && session.callId != callId) {
          return;
        }
        await session.handleRemoteAction(action);
        break;
      case 'reject':
      case 'cancel':
      case 'hangup':
      case 'answered_elsewhere':
        if (session.callId.isNotEmpty && session.callId != callId) {
          return;
        }
        if (action == 'answered_elsewhere') {
          IncomingCallPushHandler.instance.noteInviteHandled(callId);
          await LiveKitCallRingtone.instance.stop();
        }
        await session.handleRemoteAction(action);
        try {
          await IosApnsPushService.instance.endVoipCallKit(inviteId: callId);
        } catch (_) {}
        break;
    }
  }

  void _mergeSignalingState({
    required String callId,
    required String action,
    required String callerId,
    required String calleeId,
    required String mediaType,
    required String roomName,
  }) {
    final wasUnknown = CallResultRepository.instance.get(callId) == null;
    final self = _safeSelfUserId();
    final peer = self.isNotEmpty && CallUserId.isSameCallUserId(self, calleeId)
        ? callerId
        : (calleeId.isNotEmpty ? calleeId : callerId);
    final record = CallResultRecord.fromSignaling(
      callId: callId,
      action: action,
      conversationId: peer.isEmpty ? '' : 'c2c_$peer',
      callerUserId: callerId,
      calleeUserId: calleeId,
      peerUserId: peer,
      roomName: roomName,
      mediaType: mediaType,
      isOutgoing:
          self.isNotEmpty && CallUserId.isSameCallUserId(self, callerId),
    );
    CallResultRepository.instance.save(record);
    CallBubbleInsertService.instance.upsertLifecycleBubble(
      record,
      reason: 'signaling_$action',
    );
    if (record.effectiveStatus.isTerminal) {
      unawaited(CallResultEnrichmentService.instance.reconcileStatus(callId));
    } else if (wasUnknown && action != 'invite') {
      unawaited(CallResultEnrichmentService.instance.reconcileStatus(callId));
    }
  }

  String _safeSelfUserId() {
    try {
      return CallUserId.normalizeCallUserId(
        TIMUIKitCore.getInstance().loginInfo.userID,
      );
    } catch (_) {
      return '';
    }
  }
}
