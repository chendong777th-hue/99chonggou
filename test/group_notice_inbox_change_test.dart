import 'package:flutter_test/flutter_test.dart';
import 'package:tencent_cloud_chat_demo/src/models/group_notice_inbox_change.dart';

void main() {
  test('GroupNoticeInboxChangesPage parses camelCase UPSERT/DELETE/READ', () {
    final page = GroupNoticeInboxChangesPage.fromJson({
      'nextSeq': 10045,
      'hasMore': false,
      'events': [
        {
          'seq': 10041,
          'type': 'NOTICE_UPSERTED',
          'noticeId': 'grant_administrator|g1|op|tg|1786520412000',
          'groupId': 'm2225Q3N5CC',
          'groupName': '产品讨论群',
          'groupAvatarUrl': 'https://example.com/a.png',
          'noticeType': 'grant_administrator',
          'operatorUserId': '10001',
          'operatorNickName': '张三',
          'targetUserId': '10002',
          'targetNickName': '李四',
          'createdAtMs': 1786520412000,
        },
        {
          'seq': 10042,
          'type': 'NOTICE_DELETED',
          'noticeId': 'grant_administrator|g1|op|tg|1786520412000',
        },
        {
          'seq': 10043,
          'type': 'READ_WATERMARK',
          'lastReadAtMs': 1786520500000,
        },
      ],
    });
    expect(page.nextSeq, 10045);
    expect(page.hasMore, isFalse);
    expect(page.events, hasLength(3));
    expect(page.events[0].isUpserted, isTrue);
    expect(page.events[0].toRecord()?.type, 'grant_administrator');
    expect(page.events[0].toRecord()?.groupId, 'm2225Q3N5CC');
    expect(page.events[1].isDeleted, isTrue);
    expect(page.events[2].isReadWatermark, isTrue);
    expect(page.events[2].lastReadAtMs, 1786520500000);
  });

  test('GroupNoticeInboxChangesPage parses snake_case aliases', () {
    final page = GroupNoticeInboxChangesPage.fromJson({
      'next_seq': 12,
      'has_more': true,
      'items': [
        {
          'seq': 11,
          'type': 'NOTICE_CREATED',
          'notice_id': 'n1',
          'group_id': 'g1',
          'notice_type': 'transfer_owner',
          'created_at_ms': 100,
        },
      ],
    });
    expect(page.nextSeq, 12);
    expect(page.hasMore, isTrue);
    expect(page.events.single.isUpserted, isTrue);
    expect(page.events.single.toRecord()?.type, 'transfer_owner');
  });
}
