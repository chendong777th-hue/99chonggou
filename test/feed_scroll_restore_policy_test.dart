import 'package:flutter_test/flutter_test.dart';
import 'package:tencent_cloud_chat_demo/src/utils/feed_scroll_restore_policy.dart';

void main() {
  group('FeedScrollRestorePolicy.evaluate', () {
    test('skips while syncing', () {
      final decision = FeedScrollRestorePolicy.evaluate(
        pendingOffset: 120,
        currentOffset: 0,
        maxScrollExtent: 500,
        isSyncing: true,
        isLoadingConversationData: false,
        isUserScrolling: false,
      );
      expect(decision.shouldRestore, isFalse);
      expect(decision.reason, 'syncing');
    });

    test('skips while loading conversation data', () {
      final decision = FeedScrollRestorePolicy.evaluate(
        pendingOffset: 120,
        currentOffset: 0,
        maxScrollExtent: 500,
        isSyncing: false,
        isLoadingConversationData: true,
        isUserScrolling: false,
      );
      expect(decision.shouldRestore, isFalse);
      expect(decision.reason, 'loading');
    });

    test('skips while user is scrolling', () {
      final decision = FeedScrollRestorePolicy.evaluate(
        pendingOffset: 120,
        currentOffset: 0,
        maxScrollExtent: 500,
        isSyncing: false,
        isLoadingConversationData: false,
        isUserScrolling: true,
      );
      expect(decision.shouldRestore, isFalse);
      expect(decision.reason, 'user_scrolling');
    });

    test('skips when scroll clients are unavailable', () {
      final decision = FeedScrollRestorePolicy.evaluate(
        pendingOffset: 120,
        currentOffset: null,
        maxScrollExtent: 500,
        isSyncing: false,
        isLoadingConversationData: false,
        isUserScrolling: false,
      );
      expect(decision.shouldRestore, isFalse);
      expect(decision.reason, 'no_clients');
    });

    test('skips when delta is below epsilon', () {
      final decision = FeedScrollRestorePolicy.evaluate(
        pendingOffset: 120,
        currentOffset: 116,
        maxScrollExtent: 500,
        isSyncing: false,
        isLoadingConversationData: false,
        isUserScrolling: false,
      );
      expect(decision.shouldRestore, isFalse);
      expect(decision.reason, 'already_at_target');
    });

    test('restores when delta exceeds epsilon', () {
      final decision = FeedScrollRestorePolicy.evaluate(
        pendingOffset: 120,
        currentOffset: 100,
        maxScrollExtent: 500,
        isSyncing: false,
        isLoadingConversationData: false,
        isUserScrolling: false,
      );
      expect(decision.shouldRestore, isTrue);
      expect(decision.targetOffset, 120);
    });

    test('clamps pending offset to maxScrollExtent', () {
      final decision = FeedScrollRestorePolicy.evaluate(
        pendingOffset: 800,
        currentOffset: 100,
        maxScrollExtent: 500,
        isSyncing: false,
        isLoadingConversationData: false,
        isUserScrolling: false,
      );
      expect(decision.shouldRestore, isTrue);
      expect(decision.targetOffset, 500);
    });
  });
}
