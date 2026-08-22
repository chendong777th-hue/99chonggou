import 'package:flutter_test/flutter_test.dart';
import 'package:tencent_cloud_chat_demo/src/services/push_payload_normalizer.dart';

void main() {
  test('empty conversationID falls back to threadId', () {
    final id = PushPayloadNormalizer.resolveConversationId(<String, dynamic>{
      'conversationID': '',
      'threadId': 'c2c_99Chat',
      'fromAccount': '99Chat',
      'chatType': 'c2c',
      'type': 'im_chat',
    });
    expect(id, 'c2c_99Chat');
  });

  test('empty conversationID falls back to fromAccount', () {
    final id = PushPayloadNormalizer.resolveConversationId(<String, dynamic>{
      'conversationID': '',
      'fromAccount': '99Chat',
      'chatType': 'c2c',
      'type': 'im_chat',
    });
    expect(id, 'c2c_99Chat');
  });

  test('self-hosted APNs root payload resolves C2C conversation', () {
    final payload = PushPayloadNormalizer.normalize(<String, dynamic>{
      'aps': <String, dynamic>{
        'alert': <String, dynamic>{
          'title': 'Sender',
          'body': 'Message',
        },
        'mutable-content': 1,
      },
      'type': 'im_chat',
      'chatType': 'c2c',
      'fromAccount': 'user-123',
      'msgKey': 'message-123',
      'avatarUrl': 'https://example.com/avatar.png',
    });

    expect(
      PushPayloadNormalizer.resolveConversationId(payload),
      'c2c_user-123',
    );
  });

  test('self-hosted APNs root payload resolves group conversation', () {
    final payload = PushPayloadNormalizer.normalize(<String, dynamic>{
      'type': 'im_chat',
      'chatType': 'group',
      'groupId': 'group-123',
      'fromAccount': 'user-123',
    });

    expect(
      PushPayloadNormalizer.resolveConversationId(payload),
      'group_group-123',
    );
  });
}
