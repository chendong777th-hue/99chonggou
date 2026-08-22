import 'package:flutter_test/flutter_test.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_local/conversation_list_notifier.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_local/conversation_preview_text_cache.dart';
import 'package:tencent_cloud_chat_demo/src/utils/revoked_message_preview.dart';
import 'package:tencent_cloud_chat_demo/utils/custom_message/custom_last_message.dart';
import 'package:tencent_cloud_chat_sdk/enum/message_elem_type.dart';
import 'package:tencent_cloud_chat_sdk/enum/message_status.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_conversation.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_message.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_text_elem.dart';

V2TimMessage _textMsg({
  required String id,
  required String text,
  int timestamp = 100,
  bool isSelf = true,
}) {
  final message = V2TimMessage.fromJson(<String, dynamic>{
    'message_server_time': timestamp,
    'message_msg_id': id,
    'message_is_from_self': isSelf,
    'message_status': MessageStatus.V2TIM_MSG_STATUS_SEND_SUCC,
    'message_custom_str': '',
    'message_risk_type_identified': 0,
    'message_sender_group_member_info': <String, dynamic>{},
    'message_group_at_user_array': <String>[],
  });
  message.elemType = MessageElemType.V2TIM_ELEM_TYPE_TEXT;
  message.status = MessageStatus.V2TIM_MSG_STATUS_SEND_SUCC;
  message.isSelf = isSelf;
  message.timestamp = timestamp;
  message.textElem = V2TimTextElem(text: text);
  return message;
}

V2TimConversation _conv({
  required String id,
  V2TimMessage? last,
}) {
  return V2TimConversation(
    conversationID: id,
    type: 1,
    userID: id.replaceFirst('c2c_', ''),
    lastMessage: last,
    unreadCount: 0,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    ConversationPreviewTextCache.instance.clear();
  });

  tearDown(() {
    ConversationPreviewTextCache.instance.clear();
  });

  test('strongConversationPreviewTextForCache prefers revoked label over text', () {
    final message = _textMsg(id: 'm1', text: '真实内容不应展示');
    applyRevokedStateToMessage(message);

    final preview = strongConversationPreviewTextForCache(message);
    expect(preview, isNotNull);
    expect(preview, isNot('真实内容不应展示'));
    expect(preview, buildRevokedMessagePreviewLabel(message));
  });

  group('applyLastMessageLocally revoked preview cache', () {
    late ConversationListNotifier notifier;

    setUp(() {
      notifier = ConversationListNotifier.instance;
    });

    test('caches revoked label instead of original text', () {
      final original = _textMsg(id: 'm1', text: '真实内容不应展示');
      notifier.setConversationsForTest([
        _conv(id: 'c2c_u1', last: original),
      ]);

      final revoked = _textMsg(id: 'm1', text: '真实内容不应展示');
      applyRevokedStateToMessage(revoked);

      notifier.applyLastMessageLocally(
        conversationID: 'c2c_u1',
        message: revoked,
      );

      final last = notifier.conversations.single.lastMessage;
      expect(isRevokedMessage(last), isTrue);

      final key = conversationPreviewCacheMessageKey(last!);
      final cached = ConversationPreviewTextCache.instance.getForMessage(
        'c2c_u1',
        key,
      );
      expect(cached, isNotNull);
      expect(cached, isNot('真实内容不应展示'));
      expect(cached, buildRevokedMessagePreviewLabel(last));
    });

    test('in-place revoke of same lastMessage still caches label', () {
      final original = _textMsg(id: 'm_inplace', text: '真实内容不应展示');
      notifier.setConversationsForTest([
        _conv(id: 'c2c_u2', last: original),
      ]);

      applyRevokedStateToMessage(original);
      notifier.applyLastMessageLocally(
        conversationID: 'c2c_u2',
        message: original,
      );

      final last = notifier.conversations.single.lastMessage;
      expect(identical(last, original), isTrue);
      expect(isRevokedMessage(last), isTrue);

      final key = conversationPreviewCacheMessageKey(last!);
      final cached = ConversationPreviewTextCache.instance.getForMessage(
        'c2c_u2',
        key,
      );
      expect(cached, isNot('真实内容不应展示'));
      expect(cached, buildRevokedMessagePreviewLabel(last));
    });

    test('remote revoke resolves from notifier memory and caches label', () {
      final original = _textMsg(
        id: 'remote_m1',
        text: '对方发的秘密',
        isSelf: false,
      );
      notifier.setConversationsForTest([
        _conv(id: 'c2c_peer', last: original),
      ]);

      final matched =
          notifier.findConversationByLastMessageId('remote_m1');
      expect(matched?.conversationID, 'c2c_peer');

      final revoked = _textMsg(
        id: 'remote_m1',
        text: '对方发的秘密',
        isSelf: false,
      );
      applyRemoteRevokedStateToMessage(revoked);

      notifier.applyLastMessageLocally(
        conversationID: 'c2c_peer',
        message: revoked,
      );

      final last = notifier.conversations.single.lastMessage;
      expect(isRevokedMessage(last), isTrue);

      final key = conversationPreviewCacheMessageKey(last!);
      final cached = ConversationPreviewTextCache.instance.getForMessage(
        'c2c_peer',
        key,
      );
      expect(cached, isNot('对方发的秘密'));
      expect(cached, buildRevokedMessagePreviewLabel(last));
    });
  });
}
