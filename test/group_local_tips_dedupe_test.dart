import 'package:flutter_test/flutter_test.dart';
import 'package:tencent_cloud_chat_demo/src/utils/group_local_tips_dedupe.dart';

void main() {
  group('decideMemberAddedDuplicate', () {
    test('skips admin executor when inviter already exists', () {
      expect(
        decideMemberAddedDuplicate(
          existingOperatorIsAdmin: false,
          incomingOperatorIsAdmin: true,
        ),
        MemberAddedDuplicateDecision.skipIncoming,
      );
    });

    test('replaces admin executor when inviter arrives later', () {
      expect(
        decideMemberAddedDuplicate(
          existingOperatorIsAdmin: true,
          incomingOperatorIsAdmin: false,
        ),
        MemberAddedDuplicateDecision.replaceExisting,
      );
    });

    test('skips duplicate records with same operator category', () {
      expect(
        decideMemberAddedDuplicate(
          existingOperatorIsAdmin: false,
          incomingOperatorIsAdmin: false,
        ),
        MemberAddedDuplicateDecision.skipIncoming,
      );
    });
  });

  group('memberAddedSemanticKey', () {
    test('ignores member order', () {
      expect(
        memberAddedSemanticKey('g1', ['b', 'a']),
        memberAddedSemanticKey('g1', ['a', 'b']),
      );
    });
  });

  group('memberRemovedSemanticKey', () {
    test('ignores member order', () {
      expect(
        memberRemovedSemanticKey('g1', ['b', 'a']),
        memberRemovedSemanticKey('g1', ['a', 'b']),
      );
    });

    test('differs from added key for same members', () {
      expect(
        memberRemovedSemanticKey('g1', ['a']),
        isNot(memberAddedSemanticKey('g1', ['a'])),
      );
    });
  });

  group('looksLikeAdminExecutorLabel', () {
    test('detects administrator placeholder labels', () {
      expect(looksLikeAdminExecutorLabel('Administrator'), isTrue);
      expect(looksLikeAdminExecutorLabel('管理员'), isTrue);
      expect(looksLikeAdminExecutorLabel('算账号'), isFalse);
    });
  });

  group('groupProfileTipContentKey', () {
    test('reads group name from detail', () {
      expect(
        groupProfileTipContentKey(
          'group_name_changed',
          <String, dynamic>{'groupName': '新名字'},
        ),
        '新名字',
      );
    });

    test('falls back to changeEventId then occurredAtMs', () {
      expect(
        groupProfileTipContentKey(
          'group_name_changed',
          null,
          changeEventId: 'evt-1',
        ),
        'eid:evt-1',
      );
      expect(
        groupProfileTipContentKey(
          'group_name_changed',
          const <String, dynamic>{},
          occurredAtMs: 123,
        ),
        't:123',
      );
    });
  });

  group('groupProfileChangedSemanticKey', () {
    test('same name shares key; different names diverge', () {
      expect(
        groupProfileChangedSemanticKey(
          'g1',
          'group_name_changed',
          contentKey: 'A',
        ),
        groupProfileChangedSemanticKey(
          'g1',
          'group_name_changed',
          contentKey: 'A',
        ),
      );
      expect(
        groupProfileChangedSemanticKey(
          'g1',
          'group_name_changed',
          contentKey: 'A',
        ),
        isNot(
          groupProfileChangedSemanticKey(
            'g1',
            'group_name_changed',
            contentKey: 'B',
          ),
        ),
      );
    });
  });
}
