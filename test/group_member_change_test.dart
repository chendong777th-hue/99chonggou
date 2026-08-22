import 'package:flutter_test/flutter_test.dart';
import 'package:tencent_cloud_chat_demo/src/models/group_member_change.dart';

void main() {
  test('GroupMemberChangesPage parses camelCase UPSERT/REMOVED', () {
    final page = GroupMemberChangesPage.fromJson({
      'nextSeq': 10045,
      'hasMore': false,
      'memberCount': 128,
      'events': [
        {
          'seq': 10041,
          'type': 'MEMBER_UPSERTED',
          'groupId': 'm2225Q3N5CC',
          'userId': '10002',
          'nickName': '李四',
          'avatarUrl': 'https://example.com/a.png',
          'role': 200,
          'memberCount': 128,
        },
        {
          'seq': 10042,
          'type': 'MEMBER_REMOVED',
          'groupId': 'm2225Q3N5CC',
          'userId': '10003',
          'memberCount': 127,
        },
      ],
    });
    expect(page.nextSeq, 10045);
    expect(page.hasMore, isFalse);
    expect(page.memberCount, 128);
    expect(page.events, hasLength(2));
    expect(page.events[0].isUpserted, isTrue);
    expect(page.events[0].nickName, '李四');
    expect(page.events[0].role, 200);
    final record = page.events[0].toMemberRecord(ownerUserId: '10001');
    expect(record?.userId, '10002');
    expect(record?.isSelf, isFalse);
    expect(page.events[1].isRemoved, isTrue);
    expect(page.events[1].memberCount, 127);
  });

  test('GroupMemberChangesPage parses snake_case aliases', () {
    final page = GroupMemberChangesPage.fromJson({
      'next_seq': 12,
      'has_more': true,
      'member_count': 9,
      'items': [
        {
          'seq': 11,
          'type': 'MEMBER_ADDED',
          'group_id': 'g1',
          'user_id': 'u2',
          'nick_name': '王五',
          'avatar_url': 'https://example.com/b.png',
          'role': 100,
          'member_count': 9,
        },
      ],
    });
    expect(page.nextSeq, 12);
    expect(page.hasMore, isTrue);
    expect(page.memberCount, 9);
    expect(page.events.single.isUpserted, isTrue);
    expect(page.events.single.groupId, 'g1');
    expect(page.events.single.userId, 'u2');
  });
}
