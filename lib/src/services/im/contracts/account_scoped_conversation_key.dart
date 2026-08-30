import 'package:tencent_cloud_chat_demo/utils/chat_id_format.dart';

/// The only conversation identity allowed to cross the IM domain boundary.
///
/// The owner is part of the key on purpose. A raw Tencent conversation ID is
/// not sufficient to keep two logged-in accounts from sharing projections.
enum ImConversationType { c2c, group }

class AccountScopedConversationKey {
  factory AccountScopedConversationKey({
    required String ownerUserId,
    required ImConversationType conversationType,
    required String conversationId,
  }) {
    final owner = ChatIdFormat.rawUserUid(ownerUserId);
    if (owner.isEmpty) {
      throw ArgumentError.value(
          ownerUserId, 'ownerUserId', 'must not be empty');
    }
    final canonical = _canonicalConversationId(
      conversationId,
      conversationType,
    );
    if (canonical.isEmpty) {
      throw ArgumentError.value(
        conversationId,
        'conversationId',
        'is empty or does not match conversationType',
      );
    }
    return AccountScopedConversationKey._(
      ownerUserId: owner,
      conversationType: conversationType,
      canonicalConversationId: canonical,
    );
  }

  const AccountScopedConversationKey._({
    required this.ownerUserId,
    required this.conversationType,
    required this.canonicalConversationId,
  });

  final String ownerUserId;
  final ImConversationType conversationType;
  final String canonicalConversationId;

  /// Stable storage key. It is scoped by account and cannot collide between
  /// C2C and group conversations that happen to share a raw ID.
  String get storageKey => '$ownerUserId|$canonicalConversationId';

  String get conversationId => canonicalConversationId;

  static AccountScopedConversationKey? tryParse({
    required String ownerUserId,
    required ImConversationType conversationType,
    required String conversationId,
  }) {
    try {
      return AccountScopedConversationKey(
        ownerUserId: ownerUserId,
        conversationType: conversationType,
        conversationId: conversationId,
      );
    } on ArgumentError {
      return null;
    }
  }

  bool belongsTo(String owner) =>
      ownerUserId == ChatIdFormat.rawUserUid(owner) && ownerUserId.isNotEmpty;

  Map<String, Object?> toJson() => <String, Object?>{
        'ownerUserId': ownerUserId,
        'conversationType': conversationType.name,
        'canonicalConversationId': canonicalConversationId,
      };

  @override
  String toString() => storageKey;

  @override
  bool operator ==(Object other) {
    return other is AccountScopedConversationKey &&
        other.ownerUserId == ownerUserId &&
        other.conversationType == conversationType &&
        other.canonicalConversationId == canonicalConversationId;
  }

  @override
  int get hashCode => Object.hash(
        ownerUserId,
        conversationType,
        canonicalConversationId,
      );
}

String _canonicalConversationId(
  String raw,
  ImConversationType type,
) {
  var value = raw.trim();
  if (value.isEmpty) return '';
  final lower = value.toLowerCase();

  switch (type) {
    case ImConversationType.c2c:
      if (lower.startsWith('group_') ||
          ChatIdFormat.isIMGroupOrCommunityId(value)) {
        return '';
      }
      if (lower.startsWith('c2c_')) {
        value = value.substring(4).trim();
      }
      final peer = ChatIdFormat.rawUserUid(value);
      return peer.isEmpty ? '' : 'c2c_$peer';
    case ImConversationType.group:
      if (lower.startsWith('c2c_')) return '';
      if (lower.startsWith('group_')) {
        value = value.substring(6).trim();
      }
      if (value.toLowerCase().startsWith('c2c_')) return '';
      final group = ChatIdFormat.canonicalGroupStorageId(value);
      return group.isEmpty ? '' : 'group_$group';
  }
}
