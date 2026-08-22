class FeedScrollRestoreDecision {
  const FeedScrollRestoreDecision._({
    required this.shouldRestore,
    this.targetOffset,
    required this.reason,
  });

  const FeedScrollRestoreDecision.skip({required String reason})
      : this._(shouldRestore: false, reason: reason);

  const FeedScrollRestoreDecision.restore({required double targetOffset})
      : this._(
          shouldRestore: true,
          targetOffset: targetOffset,
          reason: 'restore',
        );

  final bool shouldRestore;
  final double? targetOffset;
  final String reason;
}

class FeedScrollRestorePolicy {
  FeedScrollRestorePolicy._();

  static const double epsilonPx = 8.0;

  static FeedScrollRestoreDecision evaluate({
    required double pendingOffset,
    required double? currentOffset,
    required double maxScrollExtent,
    required bool isSyncing,
    required bool isLoadingConversationData,
    required bool isUserScrolling,
  }) {
    if (isSyncing) {
      return const FeedScrollRestoreDecision.skip(reason: 'syncing');
    }
    if (isLoadingConversationData) {
      return const FeedScrollRestoreDecision.skip(reason: 'loading');
    }
    if (isUserScrolling) {
      return const FeedScrollRestoreDecision.skip(reason: 'user_scrolling');
    }
    if (currentOffset == null) {
      return const FeedScrollRestoreDecision.skip(reason: 'no_clients');
    }
    final target = pendingOffset.clamp(0.0, maxScrollExtent);
    if ((target - currentOffset).abs() < epsilonPx) {
      return const FeedScrollRestoreDecision.skip(reason: 'already_at_target');
    }
    return FeedScrollRestoreDecision.restore(targetOffset: target);
  }
}
