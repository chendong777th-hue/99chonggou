import 'message_reconciliation_identity.dart';

/// Authoritative message mutations accepted by the reconciliation writer.
///
/// History pages remain typed as `MessageHistoryBatch`; every non-history
/// mutation uses this envelope so upserts and removals share one ordering and
/// idempotency boundary.
enum MessageDeltaKind {
  realtimeUpsert,
  optimisticInsert,
  optimisticAdoption,
  edit,
  revoke,
  delete,
  readReceipt,
  localMetadata,
  compatibilitySnapshot,
  syntheticProjection,
}

enum MessageDeltaSource {
  sdkRealtime,
  sendPipeline,
  userAction,
  historyEnvelope,
  compatibilityProjection,
}

class MessageDelta<T> {
  MessageDelta({
    required this.conversationKey,
    required this.eventID,
    required this.kind,
    required this.source,
    required this.generation,
    required this.clearEpoch,
    this.ownerUserID,
    this.accountGeneration,
    this.domainGeneration,
    this.replace = false,
    Iterable<MessageReconciliationRecord<T>> upserts = const [],
    Iterable<String> explicitDeletes = const <String>[],
    Iterable<String> tombstones = const <String>[],
  })  : upserts = List<MessageReconciliationRecord<T>>.unmodifiable(upserts),
        explicitDeletes = Set<String>.unmodifiable(
          explicitDeletes.map((id) => id.trim()).where((id) => id.isNotEmpty),
        ),
        tombstones = Set<String>.unmodifiable(
          tombstones.map((id) => id.trim()).where((id) => id.isNotEmpty),
        ) {
    if (conversationKey.trim().isEmpty) {
      throw ArgumentError.value(conversationKey, 'conversationKey');
    }
    if (eventID.trim().isEmpty) {
      throw ArgumentError.value(eventID, 'eventID');
    }
  }

  final String conversationKey;
  final String eventID;
  final MessageDeltaKind kind;
  final MessageDeltaSource source;
  final int generation;
  final int clearEpoch;

  /// Account/domain scope captured by the ingress event when available.
  ///
  /// These remain optional for the compatibility bridge. A configured Writer
  /// still rejects an explicitly mismatched value, while omitted values use
  /// the Writer's current scope so existing UIKit callers remain source
  /// compatible during the migration.
  final String? ownerUserID;
  final int? accountGeneration;
  final int? domainGeneration;
  final bool replace;
  final List<MessageReconciliationRecord<T>> upserts;
  final Set<String> explicitDeletes;
  final Set<String> tombstones;

  bool get isSynthetic => kind == MessageDeltaKind.syntheticProjection;

  bool get hasMutation =>
      replace ||
      upserts.isNotEmpty ||
      explicitDeletes.isNotEmpty ||
      tombstones.isNotEmpty;

  Map<String, Object?> toMetadataJson() => <String, Object?>{
        'conversationKey': conversationKey,
        'eventID': eventID,
        'kind': kind.name,
        'source': source.name,
        'generation': generation,
        'clearEpoch': clearEpoch,
        'ownerUserID': ownerUserID,
        'accountGeneration': accountGeneration,
        'domainGeneration': domainGeneration,
        'replace': replace,
        'upsertCount': upserts.length,
        'explicitDeleteCount': explicitDeletes.length,
        'tombstoneCount': tombstones.length,
        'synthetic': isSynthetic,
      };
}
