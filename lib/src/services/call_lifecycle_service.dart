import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:tencent_cloud_chat_demo/src/services/call_bubble_insert_service.dart';
import 'package:tencent_cloud_chat_demo/src/services/call_result_enrichment_service.dart';
import 'package:tencent_cloud_chat_demo/src/services/call_result_record.dart';
import 'package:tencent_cloud_chat_demo/src/services/call_result_repository.dart';
import 'package:tencent_cloud_chat_demo/src/services/desktop_call_float_service.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_demo/src/services/desktop_call_float_service_web.dart';
import 'package:tencent_cloud_chat_demo/src/services/incoming_call_coordinator.dart';
import 'package:tencent_cloud_chat_demo/src/services/ios_apns_push_service.dart';
import 'package:tencent_cloud_chat_demo/src/services/livekit_call_ringtone.dart';
import 'package:tencent_cloud_chat_demo/src/services/livekit_call_session.dart';
import 'package:tencent_cloud_chat_demo/src/services/livekit_call_signaling.dart';
import 'package:tencent_cloud_chat_demo/src/services/livekit_call_types.dart';
import 'package:tencent_cloud_chat_demo/src/services/livekit_call_system_ui.dart';
import 'package:tencent_cloud_chat_demo/src/services/livekit_voip_bridge.dart';
import 'package:tencent_cloud_chat_demo/src/utils/call_bubble_dedupe.dart';
import 'package:tencent_cloud_chat_demo/src/utils/call_user_id.dart';
import 'package:tencent_cloud_chat_demo/utils/custom_message/calling_message/calling_message_data_provider.dart';
import 'package:tencent_cloud_chat_uikit/tencent_cloud_chat_uikit.dart';

/// LiveKit call lifecycle: result cache + local bubble insert + history refresh.
class CallLifecycleService {
  CallLifecycleService._();

  static final CallLifecycleService instance = CallLifecycleService._();

  final ValueNotifier<int> chatHistoryRefreshRevision = ValueNotifier<int>(0);

  bool _ready = false;
  final Set<String> _handledEndedCallIds = <String>{};

  bool get isActiveCall => LiveKitCallSession.instance.isInCall;

  bool get isInActiveCall => LiveKitCallSession.instance.isInCall;

  Future<void> ensureObserversAttached() async {
    if (_ready) return;
    LiveKitVoipBridge.instance.ensureInstalled();
    unawaited(CallResultRepository.instance.ensureLoaded());
    await LiveKitCallSignaling.instance.ensureAttached();
    await LiveKitCallRingtone.instance.ensureAttached();
    await LiveKitCallSystemUi.instance.ensureAttached();
    LiveKitCallSession.instance.onCallEnded = _onCallEnded;
    _ready = true;
    if (kDebugMode) {
      debugPrint('CallLifecycleService: LiveKit observers ready');
    }
  }

  Future<void> ensureFloatWindowEnabled() async {
    await DesktopCallFloatService.instance.ensureAttached();
  }

  Future<void> teardown() async {
    LiveKitCallSession.instance.onCallEnded = null;
    await LiveKitCallRingtone.instance.stop();
    await LiveKitCallSignaling.instance.detach();
    if (LiveKitCallSession.instance.isInCall) {
      await LiveKitCallSession.instance.hangup();
    }
    _ready = false;
  }

  void onLifecycleChanged(AppLifecycleState state) {
    unawaited(LiveKitCallSystemUi.instance.onLifecycleChanged(state));
    if (state == AppLifecycleState.resumed) {
      final id = LiveKitCallSession.instance.callId.trim();
      if (id.isNotEmpty) {
        unawaited(CallResultEnrichmentService.instance.reconcileStatus(id));
      }
    }
  }

  void _onCallEnded({
    required String callId,
    required AppCallMediaType mediaType,
    required AppCallEndReason reason,
    required AppCallRole role,
    required String callerUserId,
    required String calleeUserId,
    required String peerUserId,
    required String operatorUserId,
    required double totalTimeSec,
    required bool isOutgoing,
  }) {
    final id = callId.trim();
    if (id.isNotEmpty) {
      unawaited(IosApnsPushService.instance.endVoipCallKit(inviteId: id));
      unawaited(IosApnsPushService.instance.syncHandledVoipInviteId(id));
    } else {
      unawaited(IosApnsPushService.instance.endVoipCallKit());
    }
    if (id.isEmpty) {
      chatHistoryRefreshRevision.value++;
      return;
    }
    // Debounce duplicate end callbacks for the same callId (refresh only).
    if (_handledEndedCallIds.contains(id)) {
      chatHistoryRefreshRevision.value++;
      return;
    }
    _handledEndedCallIds.add(id);

    var peer = CallUserId.normalizeCallUserId(peerUserId);
    var caller = CallUserId.normalizeCallUserId(callerUserId);
    var callee = CallUserId.normalizeCallUserId(calleeUserId);
    // VoIP cold start may lack caller/callee on session; fill from push pending
    // so CallResultRepository still has a usable conversationId for overlay.
    if (caller.isEmpty) {
      caller = CallUserId.normalizeCallUserId(
        IncomingCallCoordinator.instance.pendingCallerId(id) ?? '',
      );
    }
    if (callee.isEmpty) {
      callee = CallUserId.normalizeCallUserId(
        IncomingCallCoordinator.instance.pendingCalleeId(id) ?? '',
      );
    }
    if (peer.isEmpty) {
      var self = '';
      try {
        self = CallUserId.normalizeCallUserId(
          TIMUIKitCore.getInstance().loginInfo.userID,
        );
      } catch (_) {}
      if (role == AppCallRole.caller || isOutgoing) {
        peer = callee.isNotEmpty
            ? callee
            : (caller.isNotEmpty && caller != self ? caller : '');
      } else {
        peer = caller.isNotEmpty
            ? caller
            : (callee.isNotEmpty && callee != self ? callee : '');
      }
    }
    final conversationId = peer.isEmpty ? '' : 'c2c_$peer';
    final protocol = _protocolFromReason(reason);
    final endedAtMs = DateTime.now().millisecondsSinceEpoch;
    final record = CallResultRecord(
      callId: id,
      conversationId: conversationId,
      callerUserId: caller,
      operatorUserId: CallUserId.normalizeCallUserId(operatorUserId),
      peerUserId: peer,
      protocolType: protocol,
      durationSec: totalTimeSec.round(),
      endedAtMs: endedAtMs,
      isOutgoing: isOutgoing,
      source: CallResultSource.device,
      mediaType: mediaType == AppCallMediaType.video ? 'video' : 'audio',
    );
    CallResultRepository.instance.save(record);
    CallBubbleInsertService.instance.insertTerminalBubble(
      record,
      reason: 'livekit_call_end',
    );
    unawaited(CallResultEnrichmentService.instance.ensureServerResult(id));

    chatHistoryRefreshRevision.value++;
    if (conversationId.isNotEmpty) {
      CallBubbleDedupe.scheduleDedupeConversation(
        conversationId,
        reason: 'livekit_call_end',
      );
    }
  }

  CallProtocolType _protocolFromReason(AppCallEndReason reason) {
    switch (reason) {
      case AppCallEndReason.hangup:
        return CallProtocolType.hangup;
      case AppCallEndReason.reject:
      case AppCallEndReason.otherDeviceReject:
        return CallProtocolType.reject;
      case AppCallEndReason.canceled:
      case AppCallEndReason.otherDeviceAccepted:
        return CallProtocolType.cancel;
      case AppCallEndReason.noResponse:
      case AppCallEndReason.offline:
        return CallProtocolType.timeout;
      case AppCallEndReason.lineBusy:
        return CallProtocolType.lineBusy;
      default:
        return CallProtocolType.cancel;
    }
  }
}
