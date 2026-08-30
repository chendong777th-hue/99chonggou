import 'account_scoped_conversation_key.dart';
import 'package:tencent_cloud_chat_demo/utils/chat_id_format.dart';

enum ImEventKind {
  realtimeMessage,
  historyPage,
  sendReceipt,
  outgoingAdoption,
  messageMutation,
  conversationMutation,
  readReceipt,
  searchResult,
  notification,
  uiProjection,
}

enum ImEventSource {
  sdkListener,
  sdkHistory,
  sdkSend,
  webSdk,
  push,
  localStore,
  userCommand,
  system,
}

enum ImEventAuthority { provider, application, localProjection, unknown }

/// An immutable event boundary shared by SDK, persistence and UI adapters.
///
/// [accountIngressSequence] and [scopeIngressSequence] are app-owned input
/// order only. They must never be presented as Tencent message sequence.
class EventEnvelope<T> {
  factory EventEnvelope({
    required String eventId,
    required String eventNamespace,
    required ImEventKind kind,
    required String ownerUserId,
    required int accountGeneration,
    required int domainGeneration,
    required int clearEpoch,
    required int accountIngressSequence,
    required int scopeIngressSequence,
    required ImEventSource source,
    required ImEventAuthority authority,
    required int observedAtMs,
    AccountScopedConversationKey? scope,
    String? viewInstanceId,
    String? surfaceId,
    int? viewSessionGeneration,
    int? historyRequestGeneration,
    int? sendOperationGeneration,
    int? providerSequence,
    int? sourceRevision,
    int? membershipRevision,
    String? operationId,
    ImHistoryProofReference? proof,
    ImCursorReference? cursor,
    T? payload,
  }) {
    final id = eventId.trim();
    final namespace = eventNamespace.trim();
    final owner = ChatIdFormat.rawUserUid(ownerUserId);
    if (id.isEmpty || namespace.isEmpty || owner.isEmpty) {
      throw ArgumentError(
          'eventId, eventNamespace and ownerUserId are required');
    }
    _requireNonNegative('accountGeneration', accountGeneration);
    _requireNonNegative('domainGeneration', domainGeneration);
    _requireNonNegative('clearEpoch', clearEpoch);
    _requirePositive('accountIngressSequence', accountIngressSequence);
    if (scope != null) {
      if (scope.ownerUserId != owner) {
        throw ArgumentError('scope ownerUserId must match event ownerUserId');
      }
      _requirePositive('scopeIngressSequence', scopeIngressSequence);
    } else if (scopeIngressSequence != 0) {
      throw ArgumentError(
        'scopeIngressSequence must be zero for an account-scoped event',
      );
    }
    _requireOptionalNonNegative('viewSessionGeneration', viewSessionGeneration);
    _requireOptionalNonNegative(
      'historyRequestGeneration',
      historyRequestGeneration,
    );
    _requireOptionalNonNegative(
      'sendOperationGeneration',
      sendOperationGeneration,
    );
    _requireOptionalNonNegative('providerSequence', providerSequence);
    _requireOptionalNonNegative('sourceRevision', sourceRevision);
    _requireOptionalNonNegative('membershipRevision', membershipRevision);
    _requireNonNegative('observedAtMs', observedAtMs);
    _validateKindRequirements(
      kind: kind,
      scope: scope,
      viewInstanceId: viewInstanceId,
      surfaceId: surfaceId,
      viewSessionGeneration: viewSessionGeneration,
      historyRequestGeneration: historyRequestGeneration,
      sendOperationGeneration: sendOperationGeneration,
      operationId: operationId,
    );
    return EventEnvelope._(
      eventId: id,
      eventNamespace: namespace,
      kind: kind,
      scope: scope,
      ownerUserId: owner,
      accountGeneration: accountGeneration,
      domainGeneration: domainGeneration,
      viewInstanceId: _optional(viewInstanceId),
      surfaceId: _optional(surfaceId),
      viewSessionGeneration: viewSessionGeneration,
      historyRequestGeneration: historyRequestGeneration,
      sendOperationGeneration: sendOperationGeneration,
      clearEpoch: clearEpoch,
      accountIngressSequence: accountIngressSequence,
      scopeIngressSequence: scopeIngressSequence,
      providerSequence: providerSequence,
      sourceRevision: sourceRevision,
      membershipRevision: membershipRevision,
      operationId: _optional(operationId),
      source: source,
      authority: authority,
      proof: proof,
      cursor: cursor,
      observedAtMs: observedAtMs,
      payload: payload,
    );
  }

  const EventEnvelope._({
    required this.eventId,
    required this.eventNamespace,
    required this.kind,
    required this.scope,
    required this.ownerUserId,
    required this.accountGeneration,
    required this.domainGeneration,
    required this.viewInstanceId,
    required this.surfaceId,
    required this.viewSessionGeneration,
    required this.historyRequestGeneration,
    required this.sendOperationGeneration,
    required this.clearEpoch,
    required this.accountIngressSequence,
    required this.scopeIngressSequence,
    required this.providerSequence,
    required this.sourceRevision,
    required this.membershipRevision,
    required this.operationId,
    required this.source,
    required this.authority,
    required this.proof,
    required this.cursor,
    required this.observedAtMs,
    required this.payload,
  });

  final String eventId;
  final String eventNamespace;
  final ImEventKind kind;
  final AccountScopedConversationKey? scope;
  final String ownerUserId;
  final int accountGeneration;
  final int domainGeneration;
  final String? viewInstanceId;
  final String? surfaceId;
  final int? viewSessionGeneration;
  final int? historyRequestGeneration;
  final int? sendOperationGeneration;
  final int clearEpoch;
  final int accountIngressSequence;
  final int scopeIngressSequence;
  final int? providerSequence;
  final int? sourceRevision;
  final int? membershipRevision;
  final String? operationId;
  final ImEventSource source;
  final ImEventAuthority authority;
  final ImHistoryProofReference? proof;
  final ImCursorReference? cursor;
  final int observedAtMs;
  final T? payload;

  /// Event Inbox primary key. Namespace is intentionally part of the key so
  /// call signaling and ordinary chat may reuse provider event IDs safely.
  String get inboxKey => '$ownerUserId|$eventNamespace|$eventId';

  bool belongsToAccount({
    required String ownerUserId,
    required int accountGeneration,
  }) =>
      this.ownerUserId == ChatIdFormat.rawUserUid(ownerUserId) &&
      this.accountGeneration == accountGeneration;

  bool belongsToDomain({
    required String ownerUserId,
    required int accountGeneration,
    required int domainGeneration,
  }) =>
      belongsToAccount(
        ownerUserId: ownerUserId,
        accountGeneration: accountGeneration,
      ) &&
      this.domainGeneration == domainGeneration;

  Map<String, Object?> toMetadataJson() => <String, Object?>{
        'eventId': eventId,
        'eventNamespace': eventNamespace,
        'kind': kind.name,
        'ownerUserId': ownerUserId,
        'scope': scope?.toJson(),
        'accountGeneration': accountGeneration,
        'domainGeneration': domainGeneration,
        'viewInstanceId': viewInstanceId,
        'surfaceId': surfaceId,
        'viewSessionGeneration': viewSessionGeneration,
        'historyRequestGeneration': historyRequestGeneration,
        'sendOperationGeneration': sendOperationGeneration,
        'clearEpoch': clearEpoch,
        'accountIngressSequence': accountIngressSequence,
        'scopeIngressSequence': scopeIngressSequence,
        'providerSequence': providerSequence,
        'sourceRevision': sourceRevision,
        'membershipRevision': membershipRevision,
        'operationId': operationId,
        'source': source.name,
        'authority': authority.name,
        'proof': proof?.toJson(),
        'cursor': cursor?.toJson(),
        'observedAtMs': observedAtMs,
      };
}

class ImHistoryProofReference {
  const ImHistoryProofReference({required this.level, required this.source});

  final String level;
  final String source;

  Map<String, Object?> toJson() => <String, Object?>{
        'level': level,
        'source': source,
      };
}

class ImCursorReference {
  const ImCursorReference({this.messageId, this.sequence});

  final String? messageId;
  final int? sequence;

  Map<String, Object?> toJson() => <String, Object?>{
        'messageId': messageId,
        'sequence': sequence,
      };
}

String? _optional(String? value) {
  final normalized = value?.trim() ?? '';
  return normalized.isEmpty ? null : normalized;
}

void _requireNonNegative(String name, int value) {
  if (value < 0) throw ArgumentError('$name must be non-negative');
}

void _requirePositive(String name, int value) {
  if (value <= 0) throw ArgumentError('$name must be positive');
}

void _requireOptionalNonNegative(String name, int? value) {
  if (value != null) _requireNonNegative(name, value);
}

void _validateKindRequirements({
  required ImEventKind kind,
  required AccountScopedConversationKey? scope,
  required String? viewInstanceId,
  required String? surfaceId,
  required int? viewSessionGeneration,
  required int? historyRequestGeneration,
  required int? sendOperationGeneration,
  required String? operationId,
}) {
  switch (kind) {
    case ImEventKind.realtimeMessage:
    case ImEventKind.messageMutation:
    case ImEventKind.conversationMutation:
    case ImEventKind.readReceipt:
      if (scope == null) {
        throw ArgumentError('$kind requires a conversation scope');
      }
    case ImEventKind.historyPage:
      if (scope == null || historyRequestGeneration == null) {
        throw ArgumentError(
          'historyPage requires scope and historyRequestGeneration',
        );
      }
    case ImEventKind.sendReceipt:
    case ImEventKind.outgoingAdoption:
      if (scope == null ||
          (sendOperationGeneration == null && operationId == null)) {
        throw ArgumentError(
          '$kind requires scope and a send operation identity',
        );
      }
    case ImEventKind.uiProjection:
      if (viewInstanceId == null ||
          surfaceId == null ||
          viewSessionGeneration == null) {
        throw ArgumentError(
          'uiProjection requires viewInstanceId, surfaceId and viewSessionGeneration',
        );
      }
    case ImEventKind.searchResult:
    case ImEventKind.notification:
      break;
  }
}
