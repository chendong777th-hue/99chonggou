import 'package:flutter_test/flutter_test.dart';
import 'package:tencent_cloud_chat_sdk/enum/message_elem_type.dart';
import 'package:tencent_cloud_chat_sdk/enum/message_status.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_message.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_message.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/voice_auto_play_order.dart';

V2TimMessage _sound({
  required String msgID,
  String? id,
  int timestamp = 1,
  int status = MessageStatus.V2TIM_MSG_STATUS_SEND_SUCC,
  bool isSelf = false,
}) {
  final message = V2TimMessage.fromJson(<String, dynamic>{
    'message_server_time': timestamp,
    'message_msg_id': msgID,
    'message_seq': '1',
    'message_is_from_self': isSelf,
    'message_status': status,
    'message_custom_str': '',
    'message_risk_type_identified': 0,
    'message_sender_group_member_info': <String, dynamic>{},
    'message_group_at_user_array': <String>[],
  });
  message.elemType = MessageElemType.V2TIM_ELEM_TYPE_SOUND;
  message.msgID = msgID;
  message.id = id;
  message.status = status;
  message.isSelf = isSelf;
  message.timestamp = timestamp;
  return message;
}

V2TimMessage _text({required String msgID}) {
  final message = _sound(msgID: msgID);
  message.elemType = MessageElemType.V2TIM_ELEM_TYPE_TEXT;
  return message;
}

void main() {
  test('autoplay walks newest-first list toward newer voices one by one', () {
    // index 0 = newest = visually below
    final list = [
      _sound(msgID: 'c', timestamp: 30),
      _sound(msgID: 'b', timestamp: 20),
      _sound(msgID: 'a', timestamp: 10),
    ];

    expect(
      findNextPlayableSound(
        messagesNewestFirst: list,
        completedMessageId: 'a',
      )?.msgID,
      'b',
    );
    expect(
      findNextPlayableSound(
        messagesNewestFirst: list,
        completedMessageId: 'b',
      )?.msgID,
      'c',
    );
    expect(
      findNextPlayableSound(
        messagesNewestFirst: list,
        completedMessageId: 'c',
      ),
      isNull,
    );
  });

  test('autoplay skips text and sending/failed sounds, keeps going down', () {
    final list = [
      _sound(msgID: 'newer', timestamp: 40),
      _sound(
        msgID: 'sending',
        timestamp: 30,
        status: MessageStatus.V2TIM_MSG_STATUS_SENDING,
      ),
      _text(msgID: 'text'),
      _sound(msgID: 'anchor', timestamp: 10),
    ];

    expect(
      findNextPlayableSound(
        messagesNewestFirst: list,
        completedMessageId: 'anchor',
      )?.msgID,
      'newer',
    );
  });

  test('autoplay does not filter by sender', () {
    final list = [
      _sound(msgID: 'mine', timestamp: 20, isSelf: true),
      _sound(msgID: 'theirs', timestamp: 10, isSelf: false),
    ];

    expect(
      findNextPlayableSound(
        messagesNewestFirst: list,
        completedMessageId: 'theirs',
      )?.msgID,
      'mine',
    );
  });

  test('autoplay matches completed local id as well as msgID', () {
    final list = [
      _sound(msgID: 'cloud-2', id: 'local-2', timestamp: 20),
      _sound(msgID: 'cloud-1', id: 'local-1', timestamp: 10),
    ];

    expect(
      findNextPlayableSound(
        messagesNewestFirst: list,
        completedMessageId: 'local-1',
      )?.msgID,
      'cloud-2',
    );
  });

  test('next voice drives progress even before engine id matches', () {
    expect(
      shouldDriveVoicePlaybackUi(
        isCurrent: true,
        engineMatches: false,
        isAnimating: false,
        isPaused: false,
        playerActive: true,
      ),
      isTrue,
    );
    expect(
      shouldDriveVoicePlaybackUi(
        isCurrent: false,
        engineMatches: false,
        isAnimating: false,
        isPaused: false,
        playerActive: true,
      ),
      isFalse,
    );
    expect(
      shouldDriveVoicePlaybackUi(
        isCurrent: false,
        engineMatches: true,
        isAnimating: false,
        isPaused: false,
        playerActive: false,
      ),
      isTrue,
    );
  });
}
