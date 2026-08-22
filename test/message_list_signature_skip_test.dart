import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_message.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/view_models/tui_chat_global_model.dart';
import 'package:tencent_cloud_chat_uikit/data_services/services_locatar.dart';

V2TimMessage _msg({
  required String msgID,
  required int ts,
  String seq = '1',
  int status = 2,
}) {
  final message = V2TimMessage.fromJson(<String, dynamic>{
    'message_server_time': ts,
    'message_msg_id': msgID,
    'message_seq': seq,
    'message_status': status,
    'message_custom_str': '',
    'message_risk_type_identified': 0,
    'message_sender_group_member_info': <String, dynamic>{},
    'message_group_at_user_array': <String>[],
  });
  message.timestamp = ts;
  return message;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    setupServiceLocator();
  });

  test('setMessageList skips revision bump on identical rewrite', () {
    final model = serviceLocator<TUIChatGlobalModel>();
    const conv = 'c2c_signature_skip_test';
    final messages = <V2TimMessage>[
      _msg(msgID: 'msg-a', ts: 100, seq: '2'),
      _msg(msgID: 'msg-b', ts: 90, seq: '1'),
    ];

    model.setMessageList(conv, messages, needResetNewMessageCount: false);
    final revAfterFirst = model.messageListRevisionFor(conv);
    expect(revAfterFirst, greaterThan(0));

    model.setMessageList(
      conv,
      List<V2TimMessage>.from(messages),
      needResetNewMessageCount: false,
    );
    expect(
      model.messageListRevisionFor(conv),
      revAfterFirst,
      reason: 'identical hydrate rewrite must not bump revision',
    );

    model.setMessageList(
      conv,
      List<V2TimMessage>.from(messages),
      needResetNewMessageCount: false,
      replace: true,
    );
    expect(
      model.messageListRevisionFor(conv),
      revAfterFirst,
      reason: 'identical replace rewrite must not bump revision',
    );

    model.setMessageList(
      conv,
      <V2TimMessage>[
        _msg(msgID: 'msg-c', ts: 110, seq: '3'),
        ...messages,
      ],
      needResetNewMessageCount: false,
    );
    expect(
      model.messageListRevisionFor(conv),
      greaterThan(revAfterFirst),
      reason: 'real content change must still bump revision',
    );
  });
}
