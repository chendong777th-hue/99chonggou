import 'package:flutter_test/flutter_test.dart';
import 'package:tencent_cloud_chat_demo/src/services/chat_history_peek_bootstrap.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/view_models/message_history_coverage.dart';
import 'package:tencent_cloud_chat_uikit/ui/constants/history_message_constant.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/history_pagination_anchor.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_conversation.dart';

void main() {
  group('ChatHistoryPeekBootstrap local snapshot source policy', () {
    test('C2C cloud verification yields to the first local frame', () {
      expect(
        ChatHistoryPeekBootstrap.c2cCloudVerifyAfterLocalFirst,
        const Duration(milliseconds: 120),
      );
    });

    test('ordinary C2C and group allow local first paint', () {
      expect(
        ChatHistoryPeekBootstrap.allowsLocalSnapshotFirst(
          V2TimConversation(
            conversationID: 'c2c_alice',
            userID: 'alice',
            type: 1,
          ),
        ),
        isTrue,
      );
      expect(
        ChatHistoryPeekBootstrap.allowsLocalSnapshotFirst(
          V2TimConversation(
            conversationID: 'group_@TGS#room',
            groupID: '@TGS#room',
            type: 2,
          ),
        ),
        isTrue,
      );
    });
  });

  group('ChatHistoryPeekBootstrap empty cloud result policy', () {
    MessageHistoryCoverage coverage(MessageHistoryCoverageStatus status) {
      return MessageHistoryCoverage(
        conversationKey: 'c2c_alice',
        isGroup: false,
        clearEpoch: 0,
        coverageRevision: 1,
        status: status,
        olderExhausted: false,
        newerHasMore: false,
        holes: const <MessageHistoryHole>[],
        ranges: status == MessageHistoryCoverageStatus.verified
            ? const <MessageHistoryCoverageRange>[
                MessageHistoryCoverageRange(
                  key: 'latest:closed',
                  direction: MessageHistoryCoverageDirection.latest,
                  closed: true,
                  proofKind: MessageHistoryProofKind.serverContinuity,
                ),
              ]
            : const <MessageHistoryCoverageRange>[],
        cloudVerifiedAtMs:
            status == MessageHistoryCoverageStatus.verified ? 1 : 0,
        updatedAtMs: 1,
      );
    }

    test('provisional local window never stops cloud retry', () {
      expect(
        ChatHistoryPeekBootstrap.canAcceptEmptyCloudWindow(
          warmMessageCount: 20,
          coverage: coverage(MessageHistoryCoverageStatus.provisional),
        ),
        isFalse,
      );
    });

    test('verified warm window may accept an empty refresh', () {
      expect(
        ChatHistoryPeekBootstrap.canAcceptEmptyCloudWindow(
          warmMessageCount: 20,
          coverage: coverage(MessageHistoryCoverageStatus.verified),
        ),
        isTrue,
      );
    });

    test('holes or newer continuation keep retry enabled', () {
      final withHole = coverage(MessageHistoryCoverageStatus.verified).copyWith(
        holes: const <MessageHistoryHole>[
          MessageHistoryHole(
            key: 'c2c:local:cloud',
            kind: MessageHistoryHoleKind.c2cBoundary,
            status: MessageHistoryHoleStatus.open,
            olderMsgID: 'local',
            newerMsgID: 'cloud',
          ),
        ],
      );
      final withNewer = coverage(MessageHistoryCoverageStatus.verified)
          .copyWith(newerHasMore: true);

      expect(
        ChatHistoryPeekBootstrap.canAcceptEmptyCloudWindow(
          warmMessageCount: 20,
          coverage: withHole,
        ),
        isFalse,
      );
      expect(
        ChatHistoryPeekBootstrap.canAcceptEmptyCloudWindow(
          warmMessageCount: 20,
          coverage: withNewer,
        ),
        isFalse,
      );
    });
  });

  group('ChatHistoryPeekBootstrap local-first mayHaveOlder', () {
    test('thin local window always keeps mayHaveOlder even if SDK finished',
        () {
      expect(
        ChatHistoryPeekBootstrap.localFirstImpliesMayHaveOlder(
          localCount: 1,
          localReportedHasMoreOlder: false,
        ),
        isTrue,
      );
      expect(
        ChatHistoryPeekBootstrap.localFirstImpliesMayHaveOlder(
          localCount: HistoryMessageDartConstant.initialOpenFetchCount - 1,
          localReportedHasMoreOlder: false,
        ),
        isTrue,
      );
    });

    test('full local window trusts SDK hasMoreOlder flag', () {
      expect(
        ChatHistoryPeekBootstrap.localFirstImpliesMayHaveOlder(
          localCount: HistoryMessageDartConstant.initialOpenFetchCount,
          localReportedHasMoreOlder: false,
        ),
        isFalse,
      );
      expect(
        ChatHistoryPeekBootstrap.localFirstImpliesMayHaveOlder(
          localCount: HistoryMessageDartConstant.initialOpenFetchCount,
          localReportedHasMoreOlder: true,
        ),
        isTrue,
      );
    });
  });

  group('ChatHistoryPeekBootstrap thin-window local-first policy', () {
    test('attempts local-first for empty and incomplete memory windows', () {
      expect(
        ChatHistoryPeekBootstrap.shouldAttemptLocalFirstBeforeCloud(
          memoryCount: 0,
          completeOpenWindow: false,
        ),
        isTrue,
      );
      expect(
        ChatHistoryPeekBootstrap.shouldAttemptLocalFirstBeforeCloud(
          memoryCount: 3,
          completeOpenWindow: false,
        ),
        isTrue,
      );
      expect(
        ChatHistoryPeekBootstrap.shouldAttemptLocalFirstBeforeCloud(
          memoryCount: 3,
          completeOpenWindow: true,
        ),
        isFalse,
      );
      expect(
        ChatHistoryPeekBootstrap.shouldAttemptLocalFirstBeforeCloud(
          memoryCount: HistoryMessageDartConstant.initialOpenFetchCount,
          completeOpenWindow: false,
        ),
        isFalse,
      );
    });

    test('replaces thin memory when local window is at least as large', () {
      expect(
        ChatHistoryPeekBootstrap.shouldReplaceMemoryWithLocalFirst(
          memoryCount: 3,
          localCount: HistoryMessageDartConstant.initialOpenFetchCount,
        ),
        isTrue,
      );
      expect(
        ChatHistoryPeekBootstrap.shouldReplaceMemoryWithLocalFirst(
          memoryCount: 3,
          localCount: 3,
        ),
        isTrue,
      );
      expect(
        ChatHistoryPeekBootstrap.shouldReplaceMemoryWithLocalFirst(
          memoryCount: 10,
          localCount: 3,
        ),
        isFalse,
      );
      expect(
        ChatHistoryPeekBootstrap.shouldReplaceMemoryWithLocalFirst(
          memoryCount: 0,
          localCount: 0,
        ),
        isFalse,
      );
    });
  });

  group('preserve filled history over late peek', () {
    test('120-row window is not restamped by a 20-row peek', () {
      expect(
        HistoryPaginationAnchor.shouldPreserveFilledHistoryOverPeek(
          existingCount: 120,
          fetchedCount: HistoryMessageDartConstant.initialOpenFetchCount,
        ),
        isTrue,
      );
    });

    test('C2C filled window above first screen rejects peek restamp', () {
      expect(
        HistoryPaginationAnchor.shouldRejectC2cPeekRestamp(
          existingCount: 38,
          incomingCount: HistoryMessageDartConstant.initialOpenFetchCount,
        ),
        isTrue,
      );
      expect(
        HistoryPaginationAnchor.shouldRejectC2cPeekRestamp(
          existingCount: 130,
          incomingCount: HistoryMessageDartConstant.initialOpenFetchCount,
        ),
        isTrue,
      );
      expect(
        HistoryPaginationAnchor.shouldRejectC2cPeekRestamp(
          existingCount: HistoryMessageDartConstant.initialOpenFetchCount,
          incomingCount: HistoryMessageDartConstant.initialOpenFetchCount,
        ),
        isFalse,
      );
      expect(
        HistoryPaginationAnchor.shouldRejectC2cPeekRestamp(
          existingCount: 0,
          incomingCount: 20,
        ),
        isFalse,
      );
    });

    test('first-screen peek can still replace an empty or thin window', () {
      expect(
        HistoryPaginationAnchor.shouldPreserveFilledHistoryOverPeek(
          existingCount: 0,
          fetchedCount: 20,
        ),
        isFalse,
      );
      expect(
        HistoryPaginationAnchor.shouldPreserveFilledHistoryOverPeek(
          existingCount: HistoryMessageDartConstant.initialOpenFetchCount,
          fetchedCount: HistoryMessageDartConstant.initialOpenFetchCount,
        ),
        isFalse,
      );
      expect(
        HistoryPaginationAnchor.shouldPreserveFilledHistoryOverPeek(
          existingCount: 24,
          fetchedCount: 20,
        ),
        isFalse,
      );
      expect(
        HistoryPaginationAnchor.shouldPreserveFilledHistoryOverPeek(
          existingCount: 36,
          fetchedCount: 20,
        ),
        isFalse,
      );
    });
  });
}
