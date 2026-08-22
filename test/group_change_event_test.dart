import 'package:flutter_test/flutter_test.dart';
import 'package:tencent_cloud_chat_demo/src/models/group_change_event.dart';

void main() {
  group('GroupChangeEvent.fromJson', () {
    test('parses camelCase response', () {
      final event = GroupChangeEvent.fromJson({
        'changeEventId': 'ce_01',
        'groupId': '@TGS#ABC',
        'action': 'member_added',
        'operatorUserId': 'usera',
        'memberUserIds': ['userb', 'userc'],
        'occurredAt': 1718592000123,
        'timelineRank': 30,
        'detail': {'memberCount': 128},
      });
      expect(event.changeEventId, 'ce_01');
      expect(event.groupId, '@TGS#ABC');
      expect(event.action, 'member_added');
      expect(event.operatorUserId, 'usera');
      expect(event.memberUserIds, ['userb', 'userc']);
      expect(event.occurredAt, 1718592000123);
      expect(event.timelineRank, 30);
      expect(event.detail['memberCount'], 128);
    });

    test('parses snake_case response', () {
      final event = GroupChangeEvent.fromJson({
        'change_event_id': 'ce_02',
        'group_id': '@TGS#XYZ',
        'action': 'member_removed',
        'operator_user_id': 'admin1',
        'member_user_ids': ['userx'],
        'occurred_at': 1718593000000,
      });
      expect(event.changeEventId, 'ce_02');
      expect(event.action, 'member_removed');
      expect(event.memberUserIds, ['userx']);
    });
  });

  group('GroupChangeEventsPage.fromJson', () {
    test('computes nextSince from items when missing', () {
      final page = GroupChangeEventsPage.fromJson({
        'groupId': '@TGS#ABC',
        'items': [
          {
            'changeEventId': 'ce_1',
            'action': 'member_added',
            'occurredAt': 100,
          },
          {
            'changeEventId': 'ce_2',
            'action': 'member_added',
            'occurredAt': 200,
          },
        ],
        'hasMore': false,
      });
      expect(page.nextSince, 200);
      expect(page.items.length, 2);
      expect(page.hasMore, isFalse);
    });
  });
}
