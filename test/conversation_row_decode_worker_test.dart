import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_local/conversation_row_decode_worker.dart';

void main() {
  test('decodeConversationRowsForIsolate parses valid raw_json', () {
    final raw = jsonEncode({
      'conv_show_name': 'Alice',
      'conv_unread_num': 2,
    });
    final payloads = decodeConversationRowsForIsolate([
      <String, Object?>{
        'conversation_id': 'c2c_alice',
        'conv_type': 1,
        'user_id': 'alice',
        'group_id': '',
        'show_name': 'Alice',
        'face_url': '',
        'unread_count': 2,
        'recv_opt': 0,
        'group_type': '',
        'is_pinned': 0,
        'order_key': 10,
        'active_time': 10,
        'read_cleared_at': 0,
        'local_draft_text': '',
        'local_draft_updated_at': 0,
        'raw_json': raw,
      },
    ]);

    expect(payloads, hasLength(1));
    expect(payloads.single['conversation_id'], 'c2c_alice');
    expect(payloads.single['decoded'], isA<Map>());
    expect(
      (payloads.single['decoded'] as Map)['conv_show_name'],
      'Alice',
    );
  });

  test('decodeConversationRowsForIsolate tolerates bad json', () {
    final payloads = decodeConversationRowsForIsolate([
      <String, Object?>{
        'conversation_id': 'c2c_bad',
        'conv_type': 1,
        'user_id': 'bad',
        'group_id': '',
        'show_name': 'Bad',
        'face_url': '',
        'unread_count': 0,
        'recv_opt': 0,
        'group_type': '',
        'is_pinned': 0,
        'order_key': 1,
        'active_time': 1,
        'read_cleared_at': 0,
        'local_draft_text': '',
        'local_draft_updated_at': 0,
        'raw_json': '{not-json',
      },
    ]);

    expect(payloads, hasLength(1));
    expect(payloads.single['conversation_id'], 'c2c_bad');
    expect(payloads.single['decoded'], isNull);
  });

  test('decodeConversationRowsForIsolate handles empty raw_json', () {
    final payloads = decodeConversationRowsForIsolate([
      <String, Object?>{
        'conversation_id': 'group_g1',
        'conv_type': 2,
        'user_id': '',
        'group_id': 'g1',
        'show_name': 'Group',
        'face_url': '',
        'unread_count': 0,
        'recv_opt': 0,
        'group_type': 'Work',
        'is_pinned': 1,
        'order_key': 5,
        'active_time': 5,
        'read_cleared_at': 0,
        'local_draft_text': 'draft',
        'local_draft_updated_at': 9,
        'raw_json': '',
      },
    ]);

    expect(payloads.single['decoded'], isNull);
    expect(payloads.single['group_id'], 'g1');
    expect(payloads.single['local_draft_text'], 'draft');
    expect(payloads.single['is_pinned'], 1);
  });
}
