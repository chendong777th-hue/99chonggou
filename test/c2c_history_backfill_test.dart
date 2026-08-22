import 'package:flutter_test/flutter_test.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_local/c2c_history_backfill.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_conversation.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_conversation.dart';

void main() {
  group('C2cHistoryBackfill.selectCandidateConversationIds', () {
    test('merges friends and pinned, skips existing, caps max', () {
      final ids = C2cHistoryBackfill.selectCandidateConversationIds(
        friendUserIds: const ['u1', 'u2', 'u3', 'u4'],
        pinnedConversationIds: const ['c2c_u0', 'group_g1'],
        existingLocalIds: {'c2c_u1'},
        maxPeers: 3,
        includeFriends: true,
        includePinned: true,
      );
      expect(ids.first, 'c2c_u0');
      expect(ids, isNot(contains('c2c_u1')));
      expect(ids, isNot(contains('group_g1')));
      expect(ids.length, 3);
    });

    test('flag-off friends yields only pinned', () {
      final ids = C2cHistoryBackfill.selectCandidateConversationIds(
        friendUserIds: const ['u1', 'u2'],
        pinnedConversationIds: const ['c2c_pin'],
        existingLocalIds: const {},
        maxPeers: 10,
        includeFriends: false,
        includePinned: true,
      );
      expect(ids, ['c2c_pin']);
    });
  });

  group('C2cHistoryBackfill.buildShellFromHistory', () {
    test('requireHistory skips empty history', () {
      final shell = C2cHistoryBackfill.buildShellFromHistory(
        conversationId: 'c2c_peer1',
        lastMessage: null,
        hasHistory: false,
        requireHistory: true,
      );
      expect(shell, isNull);
    });

    test('builds shell when hasHistory without constructing SDK message', () {
      final shell = C2cHistoryBackfill.buildShellFromHistory(
        conversationId: 'c2c_peer1',
        lastMessage: null,
        hasHistory: true,
        requireHistory: true,
      );
      expect(shell, isNotNull);
      expect(shell!.conversationID, 'c2c_peer1');
      expect(shell.userID, 'peer1');
      expect(shell.type, 1);
    });
  });

  group('C2cHistoryBackfill.shouldAdmitSdkConversation', () {
    test('admits c2c sdk row', () {
      expect(
        C2cHistoryBackfill.shouldAdmitSdkConversation(
          V2TimConversation(conversationID: 'c2c_a', type: 1, userID: 'a'),
        ),
        isTrue,
      );
    });

    test('rejects null and non-c2c', () {
      expect(C2cHistoryBackfill.shouldAdmitSdkConversation(null), isFalse);
      expect(
        C2cHistoryBackfill.shouldAdmitSdkConversation(
          V2TimConversation(conversationID: 'group_x', type: 2),
        ),
        isFalse,
      );
    });
  });

  group('C2cHistoryBackfill.needsLastMessageEnrichment', () {
    test('true when null or empty lastMessage', () {
      expect(C2cHistoryBackfill.needsLastMessageEnrichment(null), isTrue);
      expect(
        C2cHistoryBackfill.needsLastMessageEnrichment(
          V2TimConversation(conversationID: 'c2c_a', type: 1),
        ),
        isTrue,
      );
    });

    test('true when lastMessage missing msgID', () {
      final row = V2TimConversation(conversationID: 'c2c_a', type: 1);
      expect(C2cHistoryBackfill.needsLastMessageEnrichment(row), isTrue);
    });
  });

  group('C2cHistoryBackfill.applyPinnedFlag / applyRecvOpt', () {
    test('writes pin and recvOpt onto conversation', () {
      final row = V2TimConversation(
        conversationID: 'c2c_a',
        type: 1,
        userID: 'a',
        isPinned: false,
        recvOpt: 0,
      );
      C2cHistoryBackfill.applyPinnedFlag(row, isPinned: true);
      C2cHistoryBackfill.applyRecvOpt(row, recvOpt: 2);
      expect(row.isPinned, isTrue);
      expect(row.recvOpt, 2);
      C2cHistoryBackfill.applyRecvOpt(row, recvOpt: null);
      expect(row.recvOpt, 2);
    });
  });

  group('C2cHistoryBackfill.shouldPersistBackfillRow', () {
    test('requireHistory drops shell without lastMessage unless pinned', () {
      final empty = V2TimConversation(conversationID: 'c2c_a', type: 1);
      expect(
        C2cHistoryBackfill.shouldPersistBackfillRow(
          row: empty,
          requireHistory: true,
          isPinned: false,
        ),
        isFalse,
      );
      expect(
        C2cHistoryBackfill.shouldPersistBackfillRow(
          row: empty,
          requireHistory: true,
          isPinned: true,
        ),
        isTrue,
      );
      expect(
        C2cHistoryBackfill.shouldPersistBackfillRow(
          row: empty,
          requireHistory: false,
          isPinned: false,
        ),
        isTrue,
      );
    });
  });

  group('C2cHistoryBackfill.shouldRunFriendScan', () {
    test('floor>0: scan when local below floor', () {
      expect(
        C2cHistoryBackfill.shouldRunFriendScan(
          localC2c: 3,
          floor: 40,
          friendScanDone: false,
        ),
        isTrue,
      );
      expect(
        C2cHistoryBackfill.shouldRunFriendScan(
          localC2c: 0,
          floor: 40,
          friendScanDone: false,
        ),
        isTrue,
      );
    });

    test('floor>0: skip when at/above floor or already done', () {
      expect(
        C2cHistoryBackfill.shouldRunFriendScan(
          localC2c: 40,
          floor: 40,
          friendScanDone: false,
        ),
        isFalse,
      );
      expect(
        C2cHistoryBackfill.shouldRunFriendScan(
          localC2c: 3,
          floor: 40,
          friendScanDone: true,
        ),
        isFalse,
      );
    });

    test('floor<=0: only scan when localC2c==0 (legacy)', () {
      expect(
        C2cHistoryBackfill.shouldRunFriendScan(
          localC2c: 0,
          floor: 0,
          friendScanDone: false,
        ),
        isTrue,
      );
      expect(
        C2cHistoryBackfill.shouldRunFriendScan(
          localC2c: 3,
          floor: 0,
          friendScanDone: false,
        ),
        isFalse,
      );
    });
  });
}
