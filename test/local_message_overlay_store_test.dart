import 'package:flutter_test/flutter_test.dart';
import 'package:tencent_cloud_chat_demo/src/services/local_message_overlay_store.dart';
import 'package:tencent_cloud_chat_sdk/enum/message_elem_type.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_custom_elem.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_custom_elem.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_message.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_message.dart';

void main() {
  final store = LocalMessageOverlayStore.instance;

  V2TimMessage message(String id) {
    final value = V2TimMessage.fromJson(<String, dynamic>{
      'message_msg_id': id,
      'message_server_time': 100,
      'message_status': 2,
      'message_custom_str': '',
      'message_risk_type_identified': 0,
      'message_sender_group_member_info': <String, dynamic>{},
      'message_group_at_user_array': <String>[],
      'message_elem_type': MessageElemType.V2TIM_ELEM_TYPE_CUSTOM,
    });
    value.msgID = id;
    value.id = id;
    value.timestamp = 100;
    value.elemType = MessageElemType.V2TIM_ELEM_TYPE_CUSTOM;
    value.customElem = V2TimCustomElem(data: id);
    return value;
  }

  setUp(() {
    store.invalidateScope();
    store.resetForTesting();
  });

  test('scope change drops overlays from the previous account/domain', () {
    store.configureScope(ownerUserId: 'user-a', domainGeneration: 1);
    expect(store.upsert('peer-1', message('call-a')), isTrue);
    expect(store.messagesFor('c2c_peer-1'), hasLength(1));

    store.configureScope(ownerUserId: 'user-b', domainGeneration: 2);

    expect(store.messagesFor('c2c_peer-1'), isEmpty);
  });

  test('equivalent conversation aliases share one overlay bucket', () {
    store.configureScope(ownerUserId: 'user-a', domainGeneration: 1);
    expect(store.upsert('group_123', message('tip-1')), isTrue);

    expect(store.messagesFor('123', isGroup: true), hasLength(1));
    expect(store.messagesFor('group_123'), hasLength(1));
  });
}
