import 'package:flutter_test/flutter_test.dart';
import 'package:tencent_cloud_chat_demo/src/models/group_entity_change.dart';

void main() {
  test('GroupEntityChangesPage parses snake_case payload', () {
    final page = GroupEntityChangesPage.fromJson({
      'next_seq': 10045,
      'has_more': false,
      'events': [
        {
          'seq': 10041,
          'type': 'GROUP_INFO_UPDATED',
          'group_id': 'm2225Q3N5CC',
          'group_name': '新名称',
          'avatar_url': 'https://example.com/a.png',
          'avatar_version': 8,
          'updated_at': 1786520412000,
        },
      ],
    });
    expect(page.nextSeq, 10045);
    expect(page.hasMore, isFalse);
    expect(page.events, hasLength(1));
    final event = page.events.single;
    expect(event.groupId, 'm2225Q3N5CC');
    expect(event.groupName, '新名称');
    expect(event.avatarUrl, 'https://example.com/a.png');
    expect(event.isInfoUpdated, isTrue);
  });

  test('GroupEntityChangesPage parses camelCase aliases', () {
    final page = GroupEntityChangesPage.fromJson({
      'nextSeq': 12,
      'hasMore': true,
      'items': [
        {
          'seq': 11,
          'action': 'group_name_changed',
          'groupId': 'g1',
          'groupName': 'N',
        },
      ],
    });
    expect(page.nextSeq, 12);
    expect(page.hasMore, isTrue);
    expect(page.events.single.type, 'group_name_changed');
    expect(page.events.single.isInfoUpdated, isTrue);
  });
}
