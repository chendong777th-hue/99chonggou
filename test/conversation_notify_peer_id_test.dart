import 'package:flutter_test/flutter_test.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_notify_sync_service.dart';
import 'package:tencent_cloud_chat_demo/utils/chat_id_format.dart';

void main() {
  test('group notify peerId uses backend api group id', () {
    // 后端透传 IM 原格式：apiGroupId 原样保留，不改写前缀族。
    expect(
      ChatIdFormat.apiGroupId('@TGS#_@TGS#m2BXTRBN5CK'),
      '@TGS#_@TGS#m2BXTRBN5CK',
    );
    expect(
      ChatIdFormat.apiGroupId('@TGS#c2SX4NMM62CZ'),
      '@TGS#c2SX4NMM62CZ',
    );
    expect(
      ChatIdFormat.apiGroupId('@TGS#_mc2SX4NMM62CZ'),
      '@TGS#_mc2SX4NMM62CZ',
    );
    expect(
      ConversationNotifySyncService.recvOptToMuted(2),
      isTrue,
    );
    expect(
      ConversationNotifySyncService.recvOptToMuted(0),
      isFalse,
    );
  });
}
