import 'package:tencent_cloud_chat_sdk/models/v2_tim_conversation.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_conversation.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_message.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_message.dart';

/// Stable anchor used by search jump. It intentionally contains only immutable
/// identifiers from the search result, so every entry point can pass the same
/// semantics to chat without depending on the current visible message list.
class MessageAnchor {
  const MessageAnchor({
    required this.conversationID,
    required this.convType,
    this.msgID,
    this.localID,
    this.seq,
    this.timestamp,
    this.sender,
    this.elemType,
  });

  final String conversationID;
  final int convType;
  final String? msgID;
  final String? localID;
  final String? seq;
  final int? timestamp;
  final String? sender;
  final int? elemType;

  static String? _clean(String? value) {
    final text = value?.trim();
    if (text == null || text.isEmpty) {
      return null;
    }
    return text;
  }

  static String conversationIDOf(V2TimConversation conversation) {
    final raw = _clean(conversation.conversationID);
    if (raw != null) {
      return raw;
    }
    final groupID = _clean(conversation.groupID);
    if (groupID != null) {
      return 'group_$groupID';
    }
    final userID = _clean(conversation.userID);
    if (userID != null) {
      return 'c2c_$userID';
    }
    return '';
  }

  factory MessageAnchor.fromConversationMessage(
    V2TimConversation conversation,
    V2TimMessage message,
  ) {
    return MessageAnchor(
      conversationID: conversationIDOf(conversation),
      convType: conversation.type ?? 1,
      msgID: _clean(message.msgID),
      localID: _clean(message.id),
      seq: _clean(message.seq),
      timestamp: message.timestamp,
      sender: _clean(message.sender) ?? _clean(message.userID),
      elemType: message.elemType,
    );
  }

  int? get seqInt {
    final value = seq;
    if (value == null || value.isEmpty) {
      return null;
    }
    return int.tryParse(value);
  }

  String get stableKey {
    final msg = msgID;
    if (msg != null && msg.isNotEmpty) return 'msg_$msg';
    final local = localID;
    if (local != null && local.isNotEmpty) return 'id_$local';
    final seqValue = seq;
    if (seqValue != null && seqValue.isNotEmpty) return 'seq_$seqValue';
    return '${sender ?? ''}_${timestamp ?? ''}_${elemType ?? ''}';
  }

  bool matches(V2TimMessage? message) {
    if (message == null) {
      return false;
    }
    final targetMsgID = msgID;
    final currentMsgID = _clean(message.msgID);
    if (targetMsgID != null &&
        currentMsgID != null &&
        targetMsgID == currentMsgID) {
      return true;
    }

    final targetLocalID = localID;
    final currentLocalID = _clean(message.id);
    if (targetLocalID != null &&
        currentLocalID != null &&
        targetLocalID == currentLocalID) {
      return true;
    }

    final targetSeq = seq;
    final currentSeq = _clean(message.seq);
    if (targetSeq != null && currentSeq != null) {
      if (targetSeq == currentSeq) {
        return true;
      }
      final targetSeqInt = int.tryParse(targetSeq);
      final currentSeqInt = int.tryParse(currentSeq);
      if (targetSeqInt != null &&
          currentSeqInt != null &&
          targetSeqInt == currentSeqInt) {
        return true;
      }
    }

    if ((targetMsgID != null &&
            currentMsgID != null &&
            targetMsgID != currentMsgID) ||
        (targetLocalID != null &&
            currentLocalID != null &&
            targetLocalID != currentLocalID) ||
        (targetSeq != null && currentSeq != null && targetSeq != currentSeq)) {
      return false;
    }

    if (timestamp != null && timestamp == message.timestamp) {
      final targetSender = sender;
      final currentSender = _clean(message.sender) ?? _clean(message.userID);
      final targetElemType = elemType;
      final currentElemType = message.elemType;
      return targetSender != null &&
          currentSender != null &&
          targetSender == currentSender &&
          targetElemType != null &&
          currentElemType != null &&
          targetElemType == currentElemType;
    }
    return false;
  }

  /// Max |Δseq| treated as “present” for around-window near hits
  /// (aligned with `loadListForSpecificMessage` ±20 rule).
  static const int aroundSeqNearTolerance = 20;

  /// True when [message] is the search target or an around-load near hit
  /// (exact seqInt or within [aroundSeqNearTolerance]), matching
  /// `loadListForSpecificMessage` success rules.
  bool isPresentIn(Iterable<V2TimMessage?> messages) {
    final want = seqInt;
    var bestDelta = 1 << 30;
    for (final message in messages) {
      if (matches(message)) {
        return true;
      }
      if (want == null || want <= 0 || message == null) {
        continue;
      }
      final s = int.tryParse(message.seq?.trim() ?? '') ?? 0;
      if (s <= 0) {
        continue;
      }
      if (s == want) {
        return true;
      }
      final d = (s - want).abs();
      if (d < bestDelta) {
        bestDelta = d;
      }
    }
    return want != null &&
        want > 0 &&
        bestDelta <= aroundSeqNearTolerance;
  }
}
