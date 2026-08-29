import 'package:flutter/foundation.dart';

/// Terminal state shared by the app-owned open bootstrap and UIKit's
/// conversation loader. Keeping this contract in UIKit avoids a second
/// history request when the caller arrives just after bootstrap completion.
enum OpenHydrateResultKind {
  notRun,
  committedMessages,
  committedEmpty,
  cloudAttemptedEmpty,
  verifiedWarm,
  aborted,
  failed,
}

@immutable
class OpenHydrateResult {
  const OpenHydrateResult({
    required this.kind,
    required this.conversationKey,
    this.resultCount = 0,
    this.cloudAttempts = 0,
    this.firstWindowCommitted = false,
    this.generation = 0,
    this.completedAtMs = 0,
  });

  final OpenHydrateResultKind kind;
  final String conversationKey;
  final int resultCount;
  final int cloudAttempts;
  final bool firstWindowCommitted;
  final int generation;
  final int completedAtMs;

  bool get shouldSuppressOrdinaryLoad =>
      kind == OpenHydrateResultKind.committedMessages ||
      kind == OpenHydrateResultKind.committedEmpty ||
      kind == OpenHydrateResultKind.cloudAttemptedEmpty ||
      kind == OpenHydrateResultKind.verifiedWarm;

  bool get hasMessages => resultCount > 0;
}
