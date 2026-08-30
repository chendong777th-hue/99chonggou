import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:tencent_cloud_chat_demo/src/services/call_result_record.dart';
import 'package:tencent_cloud_chat_demo/src/services/call_result_repository.dart';
import 'package:tencent_cloud_chat_demo/src/services/local_message_overlay_store.dart';
import 'package:tencent_cloud_chat_demo/src/utils/call_bubble_dedupe.dart';
import 'package:tencent_cloud_chat_demo/src/utils/call_user_id.dart';
import 'package:tencent_cloud_chat_demo/utils/custom_message/calling_message/call_bubble_direction.dart';
import 'package:tencent_cloud_chat_demo/utils/custom_message/calling_message/calling_message_data_provider.dart';
import 'package:tencent_cloud_chat_sdk/enum/message_elem_type.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_custom_elem.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_custom_elem.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_message.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_message.dart';
import 'package:tencent_cloud_chat_uikit/tencent_cloud_chat_uikit.dart';

/// Inserts ephemeral local call bubbles into the in-memory chat history so
/// hangup-side UI matches conversation preview (which reads [CallResultRepository]).
class CallBubbleInsertService {
  CallBubbleInsertService._();

  static final CallBubbleInsertService instance = CallBubbleInsertService._();

  static const int _rehydrateMaxRecords = 12;

  /// Insert an ended call or converge existing rows for the same callId.
  bool insertTerminalBubble(CallResultRecord record, {String reason = ''}) {
    final conversationId = record.conversationId.trim();
    final callId = record.callId.trim();
    if (conversationId.isEmpty || callId.isEmpty) {
      return false;
    }
    final canonicalRecord = CallResultRepository.instance.get(callId) ?? record;
    final bubble = buildTerminalBubbleMessage(canonicalRecord);
    if (bubble == null) {
      return false;
    }

    final changed = LocalMessageOverlayStore.instance.upsert(
      conversationId,
      bubble,
    );

    if (changed) {
      CallBubbleDedupe.scheduleDedupeConversation(
        conversationId,
        reason: reason.isEmpty ? 'local_bubble_insert' : reason,
        delay: Duration.zero,
      );
    }
    return changed;
  }

  /// Insert or update the single lifecycle row for a callId. Used for
  /// RINGING/ANSWERED optimistic bubbles as well as terminal projection.
  bool upsertLifecycleBubble(CallResultRecord record, {String reason = ''}) {
    final conversationId = record.conversationId.trim();
    final callId = record.callId.trim();
    if (conversationId.isEmpty || callId.isEmpty) return false;
    // CallResultRepository.save() enforces monotonic lifecycle rank. Project
    // that record so a delayed invite/accept cannot replace an ended row.
    final canonicalRecord = CallResultRepository.instance.get(callId) ?? record;
    final bubble = buildTerminalBubbleMessage(canonicalRecord);
    if (bubble == null) return false;
    final changed = LocalMessageOverlayStore.instance.upsert(
      conversationId,
      bubble,
    );
    if (changed) {
      CallBubbleDedupe.scheduleDedupeConversation(
        conversationId,
        reason: reason.isEmpty ? 'call_lifecycle_upsert' : reason,
        delay: Duration.zero,
      );
    }
    return changed;
  }

  /// Backfill recent terminal bubbles when opening a chat (memory cache / restart).
  void ensureConversationBubbles(String conversationId, {String reason = ''}) {
    final id = conversationId.trim();
    if (id.isEmpty) {
      return;
    }
    final records = CallResultRepository.instance.recordsForConversation(id);
    if (records.isEmpty) {
      return;
    }
    final slice = records.length <= _rehydrateMaxRecords
        ? records
        : records.sublist(0, _rehydrateMaxRecords);
    for (final record in slice) {
      insertTerminalBubble(
        record,
        reason: reason.isEmpty ? 'rehydrate_open' : reason,
      );
    }
  }

  /// True when a history-visible terminal row already exists for [callId].
  @visibleForTesting
  static bool hasTerminalBubbleForCallId(
    List<V2TimMessage> messages, {
    required String callId,
  }) {
    final target = callId.trim();
    if (target.isEmpty) {
      return false;
    }
    for (final message in messages) {
      final inviteId = CallBubbleDedupe.extractInviteId(message).trim();
      if (inviteId != target) {
        continue;
      }
      final raw = message.localCustomData?.trim() ?? '';
      if (raw.contains('localCallBubble')) {
        return true;
      }
      try {
        final provider = CallingMessageDataProvider(message);
        if (provider.isCallingSignal &&
            provider.shouldDisplayInHistory &&
            provider.protocolType != CallProtocolType.send &&
            provider.protocolType != CallProtocolType.accept) {
          return true;
        }
      } catch (_) {}
    }
    return false;
  }

  @visibleForTesting
  static V2TimMessage? buildTerminalBubbleMessage(CallResultRecord record) {
    final callId = record.callId.trim();
    final conversationId = record.conversationId.trim();
    if (callId.isEmpty || conversationId.isEmpty) {
      return null;
    }
    if (record.protocolType == CallProtocolType.unknown) {
      return null;
    }

    final self = _selfUserId();
    final peer = CallUserId.normalizeCallUserId(record.peerUserId);
    final caller = CallUserId.normalizeCallUserId(record.callerUserId);
    final callee =
        _resolveCalleeId(record, self: self, peer: peer, caller: caller);
    final isOutgoing = record.isOutgoing ??
        (caller.isNotEmpty &&
            self.isNotEmpty &&
            CallUserId.isSameCallUserId(caller, self));
    final callDirection = isOutgoing
        ? CallBubbleDirection.callDirectionOutgoing
        : CallBubbleDirection.callDirectionIncoming;
    final operator = CallUserId.normalizeCallUserId(record.operatorUserId);
    final operatorIsSelf =
        self.isNotEmpty && CallUserId.isSameCallUserId(operator, self);

    final endedSec = record.endedAtMs > 0
        ? record.endedAtMs ~/ 1000
        : DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final duration = record.durationSec < 0 ? 0 : record.durationSec;
    final mediaType =
        record.mediaType.trim().toLowerCase() == 'video' ? 'video' : 'audio';

    final payload = jsonEncode(<String, dynamic>{
      'businessID': 'lk_call',
      'action': _actionForProtocol(record.protocolType),
      'callId': callId,
      'inviteID': callId,
      'duration': duration,
      'call_end': duration,
      'callerId': caller.isNotEmpty ? caller : (isOutgoing ? self : peer),
      'calleeId': callee.isNotEmpty ? callee : (isOutgoing ? peer : self),
      'mediaType': mediaType,
      'media_type': mediaType,
    });

    final marker = jsonEncode(<String, dynamic>{
      'localCallBubble': true,
      'callId': callId,
      'inviteID': callId,
      'conversationID': conversationId,
      'callDirection': callDirection,
      'call_end': duration,
      'durationSec': duration,
      if (operator.isNotEmpty) 'operatorUserId': operator,
    });

    final message = V2TimMessage.fromJson(<String, dynamic>{
      'message_server_time': endedSec,
      'message_is_from_self': operatorIsSelf,
      'message_status': 2,
      'message_custom_str': payload,
      'message_risk_type_identified': 0,
      'message_sender_group_member_info': <String, dynamic>{},
      'message_group_at_user_array': <String>[],
    });
    message.elemType = MessageElemType.V2TIM_ELEM_TYPE_CUSTOM;
    message.customElem = V2TimCustomElem(data: payload);
    message.localCustomData = marker;
    message.timestamp = endedSec;
    message.isSelf = operatorIsSelf;
    message.sender = operatorIsSelf ? self : (peer.isNotEmpty ? peer : caller);
    message.userID = peer.isNotEmpty ? peer : callee;
    message.msgID = 'local_call_bubble_$callId';
    message.id = message.msgID;
    return message;
  }

  static String _selfUserId() {
    try {
      return CallUserId.normalizeCallUserId(
        TIMUIKitCore.getInstance().loginInfo.userID,
      );
    } catch (_) {
      return '';
    }
  }

  static String _resolveCalleeId(
    CallResultRecord record, {
    required String self,
    required String peer,
    required String caller,
  }) {
    if (caller.isNotEmpty && peer.isNotEmpty) {
      if (self.isNotEmpty && CallUserId.isSameCallUserId(caller, self)) {
        return peer;
      }
      if (self.isNotEmpty && CallUserId.isSameCallUserId(peer, self)) {
        return caller;
      }
      return peer;
    }
    return peer.isNotEmpty ? peer : self;
  }

  static String _actionForProtocol(CallProtocolType protocol) {
    switch (protocol) {
      case CallProtocolType.send:
        return 'invite';
      case CallProtocolType.accept:
        return 'accept';
      case CallProtocolType.hangup:
        return 'hangup';
      case CallProtocolType.cancel:
        return 'cancel';
      case CallProtocolType.reject:
        return 'reject';
      case CallProtocolType.timeout:
        return 'timeout';
      case CallProtocolType.lineBusy:
        return 'busy';
      default:
        return 'hangup';
    }
  }
}
