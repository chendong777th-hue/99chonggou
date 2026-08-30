import 'account_scoped_conversation_key.dart';

enum ImMessageMutationKind {
  edit,
  reaction,
  receipt,
  businessCard,
  revoke,
  delete,
  status,
}

/// A mutation of an existing formal message. Replies, forwards and new cards
/// are outbound message operations, not mutations of the source message.
class ImMessageMutation {
  factory ImMessageMutation({
    required String eventId,
    required AccountScopedConversationKey scope,
    required String serverMessageId,
    required ImMessageMutationKind kind,
    required int accountGeneration,
    required int domainGeneration,
    required int sourceRevision,
    Map<String, Object?> values = const <String, Object?>{},
  }) {
    if (eventId.trim().isEmpty || serverMessageId.trim().isEmpty) {
      throw ArgumentError('eventId and serverMessageId are required');
    }
    if (accountGeneration < 0 || domainGeneration < 0 || sourceRevision < 0) {
      throw ArgumentError(
          'mutation generations and sourceRevision must be non-negative');
    }
    return ImMessageMutation._(
      eventId: eventId.trim(),
      scope: scope,
      serverMessageId: serverMessageId.trim(),
      kind: kind,
      accountGeneration: accountGeneration,
      domainGeneration: domainGeneration,
      sourceRevision: sourceRevision,
      values: Map<String, Object?>.unmodifiable(values),
    );
  }

  const ImMessageMutation._({
    required this.eventId,
    required this.scope,
    required this.serverMessageId,
    required this.kind,
    required this.accountGeneration,
    required this.domainGeneration,
    required this.sourceRevision,
    required this.values,
  });

  final String eventId;
  final AccountScopedConversationKey scope;
  final String serverMessageId;
  final ImMessageMutationKind kind;
  final int accountGeneration;
  final int domainGeneration;
  final int sourceRevision;
  final Map<String, Object?> values;

  bool isCurrent({
    required String ownerUserId,
    required int accountGeneration,
    required int domainGeneration,
  }) =>
      scope.belongsTo(ownerUserId) &&
      this.accountGeneration == accountGeneration &&
      this.domainGeneration == domainGeneration;
}
