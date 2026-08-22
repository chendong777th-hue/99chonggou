import 'package:flutter_test/flutter_test.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_conversation.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/view_models/tui_chat_global_model.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/first_unread_jump.dart';
import 'package:tencent_cloud_chat_uikit/ui/views/TIMUIKitChat/TIMUIKItMessageList/TIMUIKitTongue/unread_tongue_policy.dart';

void main() {
  group('FirstUnreadJump.formatEntryUnreadCount', () {
    test('shows full count through 99', () {
      expect(FirstUnreadJump.formatEntryUnreadCount(15), '15');
      expect(FirstUnreadJump.formatEntryUnreadCount(99), '99');
    });

    test('caps above 99', () {
      expect(FirstUnreadJump.formatEntryUnreadCount(100), '99+');
      expect(FirstUnreadJump.formatEntryUnreadCount(10000), '99+');
    });
  });

  group('FirstUnreadJump.resolve', () {
    test('null when no unread', () {
      expect(
        FirstUnreadJump.resolve(
          unreadCount: 0,
          isGroup: true,
          groupReadSequence: 10,
        ),
        isNull,
      );
    });

    test('group uses groupReadSequence + 1', () {
      final target = FirstUnreadJump.resolve(
        unreadCount: 10000,
        isGroup: true,
        groupReadSequence: 1080,
        lastMessageSeq: 12000,
      );
      expect(target, isNotNull);
      expect(target!.strategy, 'group_read_seq');
      expect(target.seq, 1081);
    });

    test('group read caught up still estimates from unread', () {
      // Open-time mark-read often pushes readSeq == lastSeq while tip still locked.
      final target = FirstUnreadJump.resolve(
        unreadCount: 587,
        isGroup: true,
        groupReadSequence: 295967,
        lastMessageSeq: 295967,
      );
      expect(target, isNotNull);
      expect(target!.strategy, 'seq_from_unread');
      expect(target.seq, 295967 - 587 + 1);
    });

    test('prefers locked first unread seq', () {
      final target = FirstUnreadJump.resolve(
        unreadCount: 587,
        isGroup: true,
        groupReadSequence: 295967,
        lastMessageSeq: 295967,
        lockedFirstUnreadSeq: 295381,
      );
      expect(target?.strategy, 'locked_seq');
      expect(target?.seq, 295381);
    });

    test('c2c uses read timestamp', () {
      final target = FirstUnreadJump.resolve(
        unreadCount: 40,
        isGroup: false,
        c2cReadTimestamp: 1700000100,
        lastMessageTimestamp: 1700000999,
      );
      expect(target, isNotNull);
      expect(target!.strategy, 'c2c_read_ts');
      expect(target.timestampSec, 1700000100);
    });

    test('count_fallback only when unread <= 200 and no cursor', () {
      final small = FirstUnreadJump.resolve(
        unreadCount: 80,
        isGroup: true,
      );
      expect(small?.strategy, 'count_fallback');

      final large = FirstUnreadJump.resolve(
        unreadCount: 10000,
        isGroup: true,
      );
      expect(large, isNull);
    });

    test('group estimates first unread from lastSeq - unread when no read cursor',
        () {
      // Matches console: latest=295967, unread=587, read=295380 → first=295381
      final target = FirstUnreadJump.resolve(
        unreadCount: 587,
        isGroup: true,
        lastMessageSeq: 295967,
      );
      expect(target, isNotNull);
      expect(target!.strategy, 'seq_from_unread');
      expect(target.seq, 295381);
      expect(target.groupReadCursorSeq, 295380);
    });

    test('estimateFirstUnreadSeq rejects invalid inputs', () {
      expect(
        FirstUnreadJump.estimateFirstUnreadSeq(
          unreadCount: 10,
          lastMessageSeq: 5,
        ),
        isNull,
      );
      expect(
        FirstUnreadJump.estimateFirstUnreadSeq(
          unreadCount: 0,
          lastMessageSeq: 100,
        ),
        isNull,
      );
    });

    test('resolveLockedFirstUnreadSeq prefers read cursor', () {
      expect(
        FirstUnreadJump.resolveLockedFirstUnreadSeq(
          unreadCount: 587,
          isGroup: true,
          groupReadSequence: 295380,
          lastMessageSeq: 295967,
        ),
        295381,
      );
    });
  });

  group('UnreadTonguePolicy entry', () {
    test('entry tip currently disabled', () {
      expect(UnreadTonguePolicy.entryUnreadTongueEnabled, isFalse);
      expect(
        UnreadTonguePolicy.isEntryUnreadEnabledForConvType(ConvType.group, 15),
        isFalse,
      );
      expect(
        UnreadTonguePolicy.isEntryUnreadEnabledForConvType(ConvType.c2c, 15),
        isFalse,
      );
    });

    test('isEnabled gate stays off for c2c while feature flag is false', () {
      final c2c = V2TimConversation(
        conversationID: 'c2c_u1',
        type: 1,
        userID: 'u1',
        unreadCount: 20,
      );
      expect(UnreadTonguePolicy.isEntryUnreadEnabled(c2c, 20), isFalse);
    });
  });
}
