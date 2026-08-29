import 'package:tencent_cloud_chat_demo/src/utils/message_conversation_id.dart';

enum ConversationMutationKind { upsert, patch, delete, recreate }

enum ConversationMutationSource {
  sdkRealtime,
  sdkPage,
  sdkDelete,
  snapshot,
  localIntent,
  userExplicitMetadata,
  sdkMetadata,
  remoteMetadata,
  localCache,
  membershipExplicit,
}

enum ConversationMutationField {
  lastMessage,
  unread,
  order,
  draft,
  pin,
  name,
  avatar,
  membership,
  archive,
  folder,
  mute,
}

enum ConversationMutationConversationType { c2c, group }

class ConversationShadowLastMessage {
  const ConversationShadowLastMessage({
    required this.messageId,
    required this.timestamp,
    required this.status,
    this.sequence = 0,
    this.statusRank = 0,
    this.isSelf = false,
    this.isPeerRead = false,
    this.isRevoked = false,
    this.isWeakCustom = false,
    this.isSending = false,
    this.contentFingerprint = '',
    this.source = ConversationMutationSource.localCache,
    this.arrivalSequence = 0,
  });

  final String messageId;
  final int timestamp;
  final int sequence;
  final int status;
  final int statusRank;
  final bool isSelf;
  final bool isPeerRead;
  final bool isRevoked;
  final bool isWeakCustom;
  final bool isSending;
  /// Lightweight payload identity used when the SDK enriches a message with
  /// text/custom/group-tip data without changing its message ID.
  final String contentFingerprint;
  final ConversationMutationSource source;
  final int arrivalSequence;

  @override
  bool operator ==(Object other) {
    return other is ConversationShadowLastMessage &&
        other.messageId == messageId &&
        other.timestamp == timestamp &&
        other.sequence == sequence &&
        other.status == status &&
        other.isPeerRead == isPeerRead &&
        other.isRevoked == isRevoked &&
        other.contentFingerprint == contentFingerprint;
  }

  @override
  int get hashCode => Object.hash(
        messageId,
        timestamp,
        sequence,
        status,
        isPeerRead,
        isRevoked,
        contentFingerprint,
      );
}

/// Immutable input for the shadow conversation mutation reducer.
///
/// This type deliberately carries no SDK or SQLite object. Production sources
/// will eventually translate their updates into field patches at the boundary,
/// which prevents an older whole conversation object from overwriting newer
/// fields owned by another source.
class ConversationMutationEvent {
  const ConversationMutationEvent({
    required this.eventId,
    required this.ownerUserId,
    required this.conversationId,
    required this.conversationType,
    required this.kind,
    required this.source,
    required this.ownerGeneration,
    required this.conversationGeneration,
    required this.sourceVersion,
    required this.values,
    this.fieldVersions = const <ConversationMutationField, int>{},
  });

  final String eventId;
  final String ownerUserId;
  final String conversationId;
  final ConversationMutationConversationType conversationType;
  final ConversationMutationKind kind;
  final ConversationMutationSource source;
  final int ownerGeneration;
  final int conversationGeneration;
  final int sourceVersion;
  final Map<ConversationMutationField, Object?> values;
  final Map<ConversationMutationField, int> fieldVersions;

  int versionFor(ConversationMutationField field) =>
      fieldVersions[field] ?? sourceVersion;

  Set<ConversationMutationField> get fields => values.keys.toSet();

  String get canonicalConversationId => canonicalizeConversationMutationId(
        conversationId,
        conversationType,
      );
}

String canonicalizeConversationMutationId(
  String raw,
  ConversationMutationConversationType type,
) {
  final normalized = MessageConversationId.normalizeComparableKey(raw);
  if (normalized.isEmpty) {
    return '';
  }
  return switch (type) {
    ConversationMutationConversationType.c2c => 'c2c_$normalized',
    ConversationMutationConversationType.group => 'group_$normalized',
  };
}
