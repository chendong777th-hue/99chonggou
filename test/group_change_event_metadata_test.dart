import 'package:flutter_test/flutter_test.dart';
import 'package:tencent_cloud_chat_demo/src/utils/group_change_event_metadata.dart';

void main() {
  group('GroupChangeEventMetadata', () {
    test('reads occurredAt from detail fallback', () {
      final meta = GroupChangeEventMetadata.fromMaps(
        topLevel: const <String, dynamic>{
          'changeEventId': 'ce_abc',
          'timelineRank': 30,
        },
        detail: const <String, dynamic>{
          'occurredAt': 1718592000123,
        },
      );
      expect(meta.changeEventId, 'ce_abc');
      expect(meta.occurredAtMs, 1718592000123);
      expect(meta.occurredAtSec, 1718592000);
      expect(meta.timelineRank, 30);
    });

    test('normalizes push payload json strings', () {
      final normalized = GroupChangeEventMetadata.normalizePushPayload(
        <String, dynamic>{
          'memberUserIds': '["userB","userC"]',
          'detail': '{"occurredAt":1718592000123,"memberCount":3}',
        },
      );
      expect(normalized['memberUserIds'], ['userB', 'userC']);
      expect(normalized['detail'], isA<Map>());
      expect(
        (normalized['detail'] as Map)['occurredAt'],
        1718592000123,
      );
    });

    test('default timeline rank by action', () {
      expect(
        GroupChangeEventMetadata.defaultTimelineRankForAction('member_added'),
        30,
      );
      expect(
        GroupChangeEventMetadata.defaultTimelineRankForAction('member_left'),
        40,
      );
      expect(
        GroupChangeEventMetadata.defaultTimelineRankForAction(
          'group_name_changed',
        ),
        45,
      );
      expect(
        GroupChangeEventMetadata.defaultTimelineRankForAction(
          'group_avatar_changed',
        ),
        45,
      );
      expect(
        GroupChangeEventMetadata.defaultTimelineRankForAction(
          'group_notice_changed',
        ),
        45,
      );
    });
  });
}
