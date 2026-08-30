import 'account_scoped_conversation_key.dart';

/// Domain-level commit summary. TUIKit's existing synchronous
/// `MessageCommitResult` remains the UI compatibility boundary; this type adds
/// account/scope identity for Mailbox, Journal and projection consumers.
class ImMessageCommitResult {
  const ImMessageCommitResult({
    required this.scope,
    required this.accountGeneration,
    required this.domainGeneration,
    required this.commitId,
    required this.projectionRevision,
    required this.acceptedMessageIds,
    this.firstMessageId,
    this.lastMessageId,
    this.coverageRevision,
    this.unreadChanged = false,
    this.structureChanged = false,
  });

  final AccountScopedConversationKey scope;
  final int accountGeneration;
  final int domainGeneration;
  final String commitId;
  final int projectionRevision;
  final List<String> acceptedMessageIds;
  final String? firstMessageId;
  final String? lastMessageId;
  final int? coverageRevision;
  final bool unreadChanged;
  final bool structureChanged;

  Map<String, Object?> toMetadataJson() => <String, Object?>{
        'scope': scope.toJson(),
        'accountGeneration': accountGeneration,
        'domainGeneration': domainGeneration,
        'commitId': commitId,
        'projectionRevision': projectionRevision,
        'acceptedMessageIds': acceptedMessageIds,
        'firstMessageId': firstMessageId,
        'lastMessageId': lastMessageId,
        'coverageRevision': coverageRevision,
        'unreadChanged': unreadChanged,
        'structureChanged': structureChanged,
      };
}
