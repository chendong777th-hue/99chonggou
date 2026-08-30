import 'account_scoped_conversation_key.dart';

enum ImPlatform { android, ios, web, macos, windows, linux, unknown }

enum ImHistorySource { local, cloud }

enum ImHistoryDirection { older, newer, latest }

enum ImHistoryProofLevel { none, transportObserved, serverContinuity }

class ImHistoryCursor {
  const ImHistoryCursor({this.messageId, this.sequence});

  final String? messageId;
  final int? sequence;

  Map<String, Object?> toJson() => <String, Object?>{
        'messageId': messageId,
        'sequence': sequence,
      };
}

/// Evidence for one bounded history response, never a claim of full history.
class HistoryProof {
  factory HistoryProof({
    required AccountScopedConversationKey scope,
    required ImPlatform platform,
    required int accountGeneration,
    required int domainGeneration,
    required int requestGeneration,
    required String requestId,
    required ImHistoryDirection direction,
    required ImHistorySource requestedSource,
    required ImHistorySource actualSource,
    required ImHistoryProofLevel level,
    required int returnedCount,
    required bool isFinished,
    Iterable<String> boundaryMessageIds = const <String>[],
    Iterable<String> overlapMessageIds = const <String>[],
    ImHistoryCursor? cursor,
    int? oldestSequence,
    int? newestSequence,
    String? requestFingerprint,
  }) {
    if (requestId.trim().isEmpty) {
      throw ArgumentError.value(requestId, 'requestId', 'must not be empty');
    }
    if (requestGeneration < 0 ||
        accountGeneration < 0 ||
        domainGeneration < 0) {
      throw ArgumentError('history generations must be non-negative');
    }
    if (returnedCount < 0) {
      throw ArgumentError.value(
          returnedCount, 'returnedCount', 'must not be negative');
    }
    if (platform == ImPlatform.web && actualSource == ImHistorySource.local) {
      throw ArgumentError(
        'Web has no native local history; map LOCAL requests to CLOUD and record it',
      );
    }
    if (oldestSequence != null && oldestSequence < 0 ||
        newestSequence != null && newestSequence < 0) {
      throw ArgumentError('history sequences must be non-negative');
    }
    return HistoryProof._(
      scope: scope,
      platform: platform,
      accountGeneration: accountGeneration,
      domainGeneration: domainGeneration,
      requestGeneration: requestGeneration,
      requestId: requestId.trim(),
      direction: direction,
      requestedSource: requestedSource,
      actualSource: actualSource,
      level: level,
      returnedCount: returnedCount,
      isFinished: isFinished,
      boundaryMessageIds: _normalizedIds(boundaryMessageIds),
      overlapMessageIds: _normalizedIds(overlapMessageIds),
      cursor: cursor,
      oldestSequence: oldestSequence,
      newestSequence: newestSequence,
      requestFingerprint: _optional(requestFingerprint),
    );
  }

  const HistoryProof._({
    required this.scope,
    required this.platform,
    required this.accountGeneration,
    required this.domainGeneration,
    required this.requestGeneration,
    required this.requestId,
    required this.direction,
    required this.requestedSource,
    required this.actualSource,
    required this.level,
    required this.returnedCount,
    required this.isFinished,
    required this.boundaryMessageIds,
    required this.overlapMessageIds,
    required this.cursor,
    required this.oldestSequence,
    required this.newestSequence,
    required this.requestFingerprint,
  });

  final AccountScopedConversationKey scope;
  final ImPlatform platform;
  final int accountGeneration;
  final int domainGeneration;
  final int requestGeneration;
  final String requestId;
  final ImHistoryDirection direction;
  final ImHistorySource requestedSource;
  final ImHistorySource actualSource;
  final ImHistoryProofLevel level;
  final int returnedCount;
  final bool isFinished;
  final List<String> boundaryMessageIds;
  final List<String> overlapMessageIds;
  final ImHistoryCursor? cursor;
  final int? oldestSequence;
  final int? newestSequence;
  final String? requestFingerprint;

  bool get cloudTransportObserved =>
      actualSource == ImHistorySource.cloud &&
      level != ImHistoryProofLevel.none;

  /// `isFinished` only closes this direction's window. It never means all
  /// server history is present.
  bool get closesCurrentDirection => isFinished;

  bool get claimsCompleteHistory => false;

  Map<String, Object?> toJson() => <String, Object?>{
        'scope': scope.toJson(),
        'platform': platform.name,
        'accountGeneration': accountGeneration,
        'domainGeneration': domainGeneration,
        'requestGeneration': requestGeneration,
        'requestId': requestId,
        'direction': direction.name,
        'requestedSource': requestedSource.name,
        'actualSource': actualSource.name,
        'level': level.name,
        'returnedCount': returnedCount,
        'isFinished': isFinished,
        'boundaryMessageIds': boundaryMessageIds,
        'overlapMessageIds': overlapMessageIds,
        'cursor': cursor?.toJson(),
        'oldestSequence': oldestSequence,
        'newestSequence': newestSequence,
        'requestFingerprint': requestFingerprint,
      };
}

List<String> _normalizedIds(Iterable<String> ids) => List<String>.unmodifiable(
      ids.map((id) => id.trim()).where((id) => id.isNotEmpty).toSet(),
    );

String? _optional(String? value) {
  final normalized = value?.trim() ?? '';
  return normalized.isEmpty ? null : normalized;
}
