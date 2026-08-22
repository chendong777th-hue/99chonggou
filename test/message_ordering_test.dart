import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:tencent_cloud_chat_sdk/enum/message_elem_type.dart';
import 'package:tencent_cloud_chat_sdk/enum/message_status.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_message.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_message.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_image_elem.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_image_elem.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_sound_elem.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_sound_elem.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_text_elem.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_text_elem.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/view_models/tui_chat_global_model.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/chat_media_send_utils.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/history_pagination_anchor.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/regexp_probe.dart';

V2TimMessage _msg({
  required int elemType,
  bool isSelf = true,
  int? status,
  String? id,
  String? msgID,
  int? random,
  int? timestamp,
  String? seq,
  String? localCustomData,
  V2TimSoundElem? soundElem,
  V2TimImageElem? imageElem,
  String? groupID,
}) {
  final message = V2TimMessage.fromJson(<String, dynamic>{
    'message_server_time': timestamp ?? 1700000000,
    'message_msg_id': msgID,
    'message_seq': seq,
    'message_rand': random,
    'message_is_from_self': isSelf,
    'message_status': status ?? MessageStatus.V2TIM_MSG_STATUS_SENDING,
    'message_custom_str': localCustomData ?? '',
    'message_risk_type_identified': 0,
    'message_sender_group_member_info': <String, dynamic>{},
    'message_group_at_user_array': <String>[],
  });
  message.elemType = elemType;
  message.id = id;
  message.soundElem = soundElem;
  message.imageElem = imageElem;
  message.status = status ?? MessageStatus.V2TIM_MSG_STATUS_SENDING;
  message.groupID = groupID;
  if (timestamp != null) {
    message.timestamp = timestamp;
  }
  message.isSelf = isSelf;
  return message;
}

V2TimMessage _c2cTextMsg({
  required String text,
  required String userID,
  required String sender,
  required String msgID,
  required int timestamp,
  bool isSelf = true,
  String? localCustomData,
}) {
  final message = _msg(
    elemType: MessageElemType.V2TIM_ELEM_TYPE_TEXT,
    msgID: msgID,
    timestamp: timestamp,
    isSelf: isSelf,
    status: MessageStatus.V2TIM_MSG_STATUS_SEND_SUCC,
    localCustomData: localCustomData,
  );
  message.userID = userID;
  message.sender = sender;
  message.msgID = msgID;
  message.timestamp = timestamp;
  message.isSelf = isSelf;
  message.textElem = V2TimTextElem(text: text);
  return message;
}

String _localSeqData(int seq) {
  return jsonEncode(<String, dynamic>{'__outgoingLocalSeq': seq});
}

String _stableIdData(String stableId, {int? localSeq}) {
  return jsonEncode(<String, dynamic>{
    kChatOutgoingStableIdKey: stableId,
    if (localSeq != null) '__outgoingLocalSeq': localSeq,
  });
}

void main() {
  test('findOutgoingPlaceholderIndex matches by random', () {
    final list = <V2TimMessage>[
      _msg(
        elemType: MessageElemType.V2TIM_ELEM_TYPE_IMAGE,
        id: 'client_new',
        random: 200,
      ),
      _msg(
        elemType: MessageElemType.V2TIM_ELEM_TYPE_IMAGE,
        id: 'client_old',
        random: 100,
      ),
    ];
    final incoming = _msg(
      elemType: MessageElemType.V2TIM_ELEM_TYPE_IMAGE,
      msgID: 'server_old',
      random: 100,
      status: MessageStatus.V2TIM_MSG_STATUS_SEND_SUCC,
    );

    final index = TUIChatGlobalModel.findOutgoingPlaceholderIndexForTesting(
      list,
      incoming,
    );
    expect(index, 1);
  });

  test('findOutgoingPlaceholderIndex matches by client id when random is zero', () {
    final list = <V2TimMessage>[
      _msg(
        elemType: MessageElemType.V2TIM_ELEM_TYPE_TEXT,
        id: 'client_new',
        random: 0,
      ),
      _msg(
        elemType: MessageElemType.V2TIM_ELEM_TYPE_TEXT,
        id: 'client_old',
        random: 0,
      ),
    ];
    final incoming = _msg(
      elemType: MessageElemType.V2TIM_ELEM_TYPE_TEXT,
      id: 'client_old',
      msgID: 'server',
      random: 0,
      status: MessageStatus.V2TIM_MSG_STATUS_SEND_SUCC,
    );

    final index = TUIChatGlobalModel.findOutgoingPlaceholderIndexForTesting(
      list,
      incoming,
    );
    expect(index, 1);
  });

  test('findOutgoingPlaceholderIndex avoids ambiguous FIFO without client id', () {
    final list = <V2TimMessage>[
      _msg(
        elemType: MessageElemType.V2TIM_ELEM_TYPE_TEXT,
        id: 'client_new',
        random: 0,
      ),
      _msg(
        elemType: MessageElemType.V2TIM_ELEM_TYPE_TEXT,
        id: 'client_old',
        random: 0,
      ),
    ];
    final incoming = _msg(
      elemType: MessageElemType.V2TIM_ELEM_TYPE_TEXT,
      msgID: 'server',
      random: 0,
      status: MessageStatus.V2TIM_MSG_STATUS_SEND_SUCC,
    );

    final index = TUIChatGlobalModel.findOutgoingPlaceholderIndexForTesting(
      list,
      incoming,
    );
    expect(index, -1);
  });

  test('findOutgoingPlaceholderIndex matches placeholder by sync msgID', () {
    final list = <V2TimMessage>[
      _msg(
        elemType: MessageElemType.V2TIM_ELEM_TYPE_TEXT,
        id: 'client_new',
        random: 0,
      ),
      _msg(
        elemType: MessageElemType.V2TIM_ELEM_TYPE_TEXT,
        id: 'client_old',
        msgID: 'server_old',
        random: 0,
      ),
    ];
    final incoming = _msg(
      elemType: MessageElemType.V2TIM_ELEM_TYPE_TEXT,
      msgID: 'server_old',
      random: 0,
      status: MessageStatus.V2TIM_MSG_STATUS_SEND_SUCC,
    );

    final index = TUIChatGlobalModel.findOutgoingPlaceholderIndexForTesting(
      list,
      incoming,
    );
    expect(index, 1);
  });

  test('findOutgoingPlaceholderIndex matches image by client id', () {
    final list = <V2TimMessage>[
      _msg(
        elemType: MessageElemType.V2TIM_ELEM_TYPE_IMAGE,
        id: 'img_new',
        random: 0,
      ),
      _msg(
        elemType: MessageElemType.V2TIM_ELEM_TYPE_IMAGE,
        id: 'img_old',
        random: 0,
      ),
    ];
    final incoming = _msg(
      elemType: MessageElemType.V2TIM_ELEM_TYPE_IMAGE,
      id: 'img_new',
      msgID: 'server_new',
      random: 0,
      status: MessageStatus.V2TIM_MSG_STATUS_SEND_SUCC,
    );

    final index = TUIChatGlobalModel.findOutgoingPlaceholderIndexForTesting(
      list,
      incoming,
    );
    expect(index, 0);
  });

  test('findOutgoingPlaceholderIndex matches by outgoing stable id', () {
    final list = <V2TimMessage>[
      _msg(
        elemType: MessageElemType.V2TIM_ELEM_TYPE_IMAGE,
        id: 'opt_a',
        random: 0,
        localCustomData: _stableIdData('stable_a'),
        imageElem: V2TimImageElem(path: '/tmp/a.jpg'),
      ),
      _msg(
        elemType: MessageElemType.V2TIM_ELEM_TYPE_IMAGE,
        id: 'opt_b',
        random: 0,
        localCustomData: _stableIdData('stable_b'),
        imageElem: V2TimImageElem(path: '/tmp/b.jpg'),
      ),
    ];
    final incoming = _msg(
      elemType: MessageElemType.V2TIM_ELEM_TYPE_IMAGE,
      id: 'sdk_b',
      msgID: 'server_b',
      random: 99,
      status: MessageStatus.V2TIM_MSG_STATUS_SEND_SUCC,
      localCustomData: _stableIdData('stable_b'),
      imageElem: V2TimImageElem(path: '/tmp/b.jpg'),
    );

    final index = TUIChatGlobalModel.findOutgoingPlaceholderIndexForTesting(
      list,
      incoming,
    );
    expect(index, 1);
  });

  test('findOutgoingPlaceholderIndex matches unique image path among many', () {
    final list = <V2TimMessage>[
      _msg(
        elemType: MessageElemType.V2TIM_ELEM_TYPE_IMAGE,
        id: 'opt_a',
        random: 0,
        imageElem: V2TimImageElem(path: '/tmp/a.jpg'),
      ),
      _msg(
        elemType: MessageElemType.V2TIM_ELEM_TYPE_IMAGE,
        id: 'opt_b',
        random: 0,
        imageElem: V2TimImageElem(path: '/tmp/b.jpg'),
      ),
    ];
    final incoming = _msg(
      elemType: MessageElemType.V2TIM_ELEM_TYPE_IMAGE,
      id: 'sdk_a',
      msgID: 'server_a',
      random: 42,
      status: MessageStatus.V2TIM_MSG_STATUS_SEND_SUCC,
      imageElem: V2TimImageElem(path: '/tmp/a.jpg'),
    );

    final index = TUIChatGlobalModel.findOutgoingPlaceholderIndexForTesting(
      list,
      incoming,
    );
    expect(index, 0);
  });

  test('dedupe collapses optimistic and sdk image sharing stable id', () {
    final optimistic = _msg(
      elemType: MessageElemType.V2TIM_ELEM_TYPE_IMAGE,
      id: 'opt_1',
      random: 0,
      localCustomData: _stableIdData('stable_1', localSeq: 1),
      imageElem: V2TimImageElem(path: '/tmp/one.jpg'),
    );
    final sdkEcho = _msg(
      elemType: MessageElemType.V2TIM_ELEM_TYPE_IMAGE,
      id: 'sdk_1',
      msgID: 'server_1',
      random: 77,
      status: MessageStatus.V2TIM_MSG_STATUS_SEND_SUCC,
      localCustomData: _stableIdData('stable_1', localSeq: 1),
      imageElem: V2TimImageElem(path: '/tmp/one.jpg'),
    );

    final deduped = TUIChatGlobalModel.dedupeMessagesForTesting(
      <V2TimMessage>[sdkEcho, optimistic],
    );
    expect(deduped, hasLength(1));
  });

  test('preserveOutgoingLocalOrderData keeps local seq after send merge', () {
    final placeholder = _msg(
      elemType: MessageElemType.V2TIM_ELEM_TYPE_TEXT,
      id: 'client_a',
      timestamp: 100,
      localCustomData: _localSeqData(3),
    );
    final resolved = _msg(
      elemType: MessageElemType.V2TIM_ELEM_TYPE_TEXT,
      id: 'client_a',
      msgID: 'server_a',
      timestamp: 100,
      seq: '1',
      status: MessageStatus.V2TIM_MSG_STATUS_SEND_SUCC,
    );

    TUIChatGlobalModel.preserveOutgoingLocalOrderDataForTesting(
      placeholder,
      resolved,
    );

    expect(
      TUIChatGlobalModel.readOutgoingLocalSeqForTesting(resolved),
      3,
    );
  });

  test('rapid same-second sends keep tap order via localSeq after merge', () {
    final first = _msg(
      elemType: MessageElemType.V2TIM_ELEM_TYPE_TEXT,
      id: 'first',
      timestamp: 100,
      seq: '10',
      localCustomData: _localSeqData(1),
    );
    final second = _msg(
      elemType: MessageElemType.V2TIM_ELEM_TYPE_TEXT,
      id: 'second',
      timestamp: 100,
      seq: '10',
      localCustomData: _localSeqData(2),
    );

    final sorted = TUIChatGlobalModel.sortMessagesChronologicallyAsc(
      <V2TimMessage>[second, first],
    );

    expect(sorted.map((item) => item.id).toList(), <String>['first', 'second']);
  });

  test('findOutgoingPlaceholderIndex sound duration', () {
    final list = <V2TimMessage>[
      _msg(
        elemType: MessageElemType.V2TIM_ELEM_TYPE_SOUND,
        id: 'client_new',
        random: 0,
        soundElem: V2TimSoundElem(duration: 5),
      ),
      _msg(
        elemType: MessageElemType.V2TIM_ELEM_TYPE_SOUND,
        id: 'client_old',
        random: 0,
        soundElem: V2TimSoundElem(duration: 3),
      ),
    ];
    final incoming = _msg(
      elemType: MessageElemType.V2TIM_ELEM_TYPE_SOUND,
      msgID: 'server',
      random: 0,
      status: MessageStatus.V2TIM_MSG_STATUS_SEND_SUCC,
      soundElem: V2TimSoundElem(duration: 3),
    );

    final index = TUIChatGlobalModel.findOutgoingPlaceholderIndexForTesting(
      list,
      incoming,
    );
    expect(index, 1);
  });

  test('dedupeMessages prefers resolved over placeholder', () {
    final placeholder = _msg(
      elemType: MessageElemType.V2TIM_ELEM_TYPE_IMAGE,
      id: 'client_a',
      random: 42,
    );
    final resolved = _msg(
      elemType: MessageElemType.V2TIM_ELEM_TYPE_IMAGE,
      id: 'client_a',
      msgID: 'server_a',
      random: 42,
      status: MessageStatus.V2TIM_MSG_STATUS_SEND_SUCC,
    );

    final deduped = TUIChatGlobalModel.dedupeMessagesForTesting(
      <V2TimMessage>[placeholder, resolved],
    );

    expect(deduped, hasLength(1));
    expect(deduped.single.msgID, 'server_a');
    expect(deduped.single.status, MessageStatus.V2TIM_MSG_STATUS_SEND_SUCC);
  });

  test('dedupeMessages existing placeholder kept when no server', () {
    final placeholder = _msg(
      elemType: MessageElemType.V2TIM_ELEM_TYPE_TEXT,
      id: 'client_only',
      random: 7,
    );

    final deduped = TUIChatGlobalModel.dedupeMessagesForTesting(
      <V2TimMessage>[placeholder],
    );

    expect(deduped, hasLength(1));
    expect(deduped.single.id, 'client_only');
  });

  test('mergeHistoricalWithInMemory no duplicate', () {
    final existing = <V2TimMessage>[
      _msg(
        elemType: MessageElemType.V2TIM_ELEM_TYPE_TEXT,
        id: 'client_a',
        random: 99,
      ),
    ];
    final fetched = <V2TimMessage>[
      _msg(
        elemType: MessageElemType.V2TIM_ELEM_TYPE_TEXT,
        id: 'client_a',
        msgID: 'server_a',
        random: 99,
        status: MessageStatus.V2TIM_MSG_STATUS_SEND_SUCC,
      ),
    ];

    final merged = TUIChatGlobalModel.mergeHistoricalWithInMemory(
      existing: existing,
      fetched: fetched,
    );

    expect(merged, hasLength(1));
    expect(merged.single.msgID, 'server_a');
  });

  test('mergeHistoricalWithInMemory dedupes preview msgID against existing id', () {
    final existing = <V2TimMessage>[
      _msg(
        elemType: MessageElemType.V2TIM_ELEM_TYPE_TEXT,
        id: 'M1',
        msgID: 'M1',
        status: MessageStatus.V2TIM_MSG_STATUS_SEND_SUCC,
      ),
    ];
    final fetched = <V2TimMessage>[
      _msg(
        elemType: MessageElemType.V2TIM_ELEM_TYPE_TEXT,
        id: 'M1',
        status: MessageStatus.V2TIM_MSG_STATUS_SEND_SUCC,
      ),
    ];

    final merged = TUIChatGlobalModel.mergeHistoricalWithInMemory(
      existing: existing,
      fetched: fetched,
    );

    expect(merged, hasLength(1));
    expect(merged.single.msgID, 'M1');
  });

  test('mergePeekWindowWithLiveMemory keeps localGroupTips older than window', () {
    final localTip = _msg(
      elemType: MessageElemType.V2TIM_ELEM_TYPE_GROUP_TIPS,
      msgID: 'local_gt_cancel_admin_1',
      id: 'local_gt_cancel_admin_1',
      timestamp: 1700000000,
      isSelf: false,
      status: MessageStatus.V2TIM_MSG_STATUS_SEND_SUCC,
      localCustomData: jsonEncode(<String, dynamic>{
        'localGroupTips': true,
        'action': 'member_cancel_admin',
      }),
      groupID: '@TGS#g123',
    );
    localTip.localCustomData = jsonEncode(<String, dynamic>{
      'localGroupTips': true,
      'action': 'member_cancel_admin',
    });
    final existing = <V2TimMessage>[
      localTip,
      _msg(
        elemType: MessageElemType.V2TIM_ELEM_TYPE_TEXT,
        msgID: 'im_old',
        timestamp: 1700000001,
        isSelf: false,
        status: MessageStatus.V2TIM_MSG_STATUS_SEND_SUCC,
      ),
    ];
    final fetched = <V2TimMessage>[
      _msg(
        elemType: MessageElemType.V2TIM_ELEM_TYPE_TEXT,
        msgID: 'im_new',
        timestamp: 1700000100,
        isSelf: false,
        status: MessageStatus.V2TIM_MSG_STATUS_SEND_SUCC,
      ),
    ];

    final merged = TUIChatGlobalModel.mergePeekWindowWithLiveMemory(
      existing: existing,
      fetched: fetched,
    );

    expect(
      merged.any((m) => m.msgID == 'local_gt_cancel_admin_1'),
      isTrue,
    );
    expect(merged.any((m) => m.msgID == 'im_new'), isTrue);
  });

  test('dedupeMessages removes duplicate mount segment append', () {
    final base = _msg(
      elemType: MessageElemType.V2TIM_ELEM_TYPE_TEXT,
      msgID: 'm2',
      status: MessageStatus.V2TIM_MSG_STATUS_SEND_SUCC,
    );
    final duplicate = _msg(
      elemType: MessageElemType.V2TIM_ELEM_TYPE_TEXT,
      msgID: 'm2',
      status: MessageStatus.V2TIM_MSG_STATUS_SEND_SUCC,
    );

    final deduped = TUIChatGlobalModel.dedupeMessagesForTesting(
      <V2TimMessage>[base, duplicate],
    );

    expect(deduped, hasLength(1));
    expect(deduped.single.msgID, 'm2');
  });

  test('dedupeMessages merges group archive and SDK copy by seq', () {
    const groupID = '@TGS#2BXXNKM5CS';
    final archive = _msg(
      elemType: MessageElemType.V2TIM_ELEM_TYPE_TEXT,
      groupID: groupID,
      msgID: '$groupID:91',
      seq: '91',
      status: MessageStatus.V2TIM_MSG_STATUS_SEND_SUCC,
    );
    final sdk = _msg(
      elemType: MessageElemType.V2TIM_ELEM_TYPE_TEXT,
      groupID: groupID,
      msgID: '144115267812600597-1783162477-180902858',
      seq: '91',
      status: MessageStatus.V2TIM_MSG_STATUS_SEND_SUCC,
    );

    final dedupedArchiveFirst = TUIChatGlobalModel.dedupeMessagesForTesting(
      <V2TimMessage>[archive, sdk],
    );
    expect(dedupedArchiveFirst, hasLength(1));
    expect(dedupedArchiveFirst.single.msgID, archive.msgID);

    final dedupedSdkFirst = TUIChatGlobalModel.dedupeMessagesForTesting(
      <V2TimMessage>[sdk, archive],
    );
    expect(dedupedSdkFirst, hasLength(1));
    expect(dedupedSdkFirst.single.msgID, archive.msgID);
  });

  test('dedupeMessages merges group SDK with conversation preview stub', () {
    final sdk = _msg(
      elemType: MessageElemType.V2TIM_ELEM_TYPE_TEXT,
      isSelf: false,
      msgID: '144115267812600597-1784355597-1115962817',
      seq: '1920',
      timestamp: 1784355597,
      status: MessageStatus.V2TIM_MSG_STATUS_SEND_SUCC,
    );
    sdk.textElem = V2TimTextElem(text: '，，，');
    final preview = _msg(
      elemType: MessageElemType.V2TIM_ELEM_TYPE_TEXT,
      isSelf: false,
      timestamp: 1784355597,
      status: MessageStatus.V2TIM_MSG_STATUS_SEND_SUCC,
    );
    preview.textElem = V2TimTextElem(text: '，，，');

    final deduped = TUIChatGlobalModel.dedupeMessagesForTesting(
      <V2TimMessage>[sdk, preview],
    );

    expect(deduped, hasLength(1));
    expect(deduped.single.msgID, sdk.msgID);
    expect(
      TUIChatGlobalModel.messagesCorrelateForDedup(sdk, preview),
      isTrue,
    );
  });

  test(
      'dedupeMessages merges SDK head with preview stub missing textElem (Web lastMessage)',
      () {
    final sdk = _msg(
      elemType: MessageElemType.V2TIM_ELEM_TYPE_TEXT,
      isSelf: false,
      msgID: '144115267812600597-1784355597-1115962817',
      seq: '1920',
      timestamp: 1784355597,
      status: MessageStatus.V2TIM_MSG_STATUS_SEND_SUCC,
    );
    sdk.textElem = V2TimTextElem(text: '，，，');
    sdk.sender = 'acnj6oxey9';
    final preview = _msg(
      elemType: MessageElemType.V2TIM_ELEM_TYPE_TEXT,
      isSelf: false,
      timestamp: 1784355597,
      status: MessageStatus.V2TIM_MSG_STATUS_SEND_SUCC,
    );
    preview.sender = 'acnj6oxey9';

    expect(
      TUIChatGlobalModel.messagesCorrelateForDedup(sdk, preview),
      isTrue,
    );
    final deduped = TUIChatGlobalModel.dedupeMessagesForTesting(
      <V2TimMessage>[sdk, preview],
    );
    expect(deduped, hasLength(1));
    expect(deduped.single.msgID, sdk.msgID);
  });

  test(
      'dedupeMessages does not merge same-second text with image preview stub',
      () {
    // 复现：刚发出的文字（或仍在发送）与同秒图片 stub 被 _groupPreviewStubCorrelate
    // 误并后，prefer 会留下图片，本地气泡从文字变成图；对端仍显示文字。
    final textSending = _msg(
      elemType: MessageElemType.V2TIM_ELEM_TYPE_TEXT,
      isSelf: true,
      id: 'client_text_1',
      timestamp: 1787210439,
      status: MessageStatus.V2TIM_MSG_STATUS_SENDING,
      groupID: 'g1',
    );
    textSending.textElem = V2TimTextElem(text: 'hello');
    textSending.sender = 'me';

    final imageSdk = _msg(
      elemType: MessageElemType.V2TIM_ELEM_TYPE_IMAGE,
      isSelf: true,
      msgID: '144115250268987189-1787210439-1593794653',
      seq: '286638',
      timestamp: 1787210439,
      status: MessageStatus.V2TIM_MSG_STATUS_SEND_SUCC,
      groupID: 'g1',
    );
    imageSdk.sender = 'me';

    expect(
      TUIChatGlobalModel.messagesCorrelateForDedup(textSending, imageSdk),
      isFalse,
    );
    final deduped = TUIChatGlobalModel.dedupeMessagesForTesting(
      <V2TimMessage>[textSending, imageSdk],
    );
    expect(deduped, hasLength(2));
    expect(
      deduped.where((m) => m.elemType == MessageElemType.V2TIM_ELEM_TYPE_TEXT),
      hasLength(1),
    );
    expect(
      deduped.where((m) => m.elemType == MessageElemType.V2TIM_ELEM_TYPE_IMAGE),
      hasLength(1),
    );
  });

  test(
      'dedupeMessages does not merge outgoing text/image that share random',
      () {
    final text = _msg(
      elemType: MessageElemType.V2TIM_ELEM_TYPE_TEXT,
      isSelf: true,
      msgID: 'sdk-text-rand',
      random: 42,
      timestamp: 1787210439,
      status: MessageStatus.V2TIM_MSG_STATUS_SEND_SUCC,
      groupID: 'g1',
    );
    text.textElem = V2TimTextElem(text: 'hello');
    final image = _msg(
      elemType: MessageElemType.V2TIM_ELEM_TYPE_IMAGE,
      isSelf: true,
      msgID: 'sdk-image-rand',
      random: 42,
      timestamp: 1787210500,
      status: MessageStatus.V2TIM_MSG_STATUS_SEND_SUCC,
      groupID: 'g1',
    );
    expect(
      TUIChatGlobalModel.messagesCorrelateForDedup(text, image),
      isFalse,
    );
    expect(
      TUIChatGlobalModel.dedupeMessagesForTesting(<V2TimMessage>[text, image]),
      hasLength(2),
    );
  });

  test('dedupeMessages merges duplicate self group echoes on Web SDK', () {
    final first = _msg(
      elemType: MessageElemType.V2TIM_ELEM_TYPE_TEXT,
      isSelf: true,
      msgID: '144115267812600597-1783162477-111',
      seq: '88',
      timestamp: 1721196720,
      status: MessageStatus.V2TIM_MSG_STATUS_SEND_SUCC,
    );
    first.textElem = V2TimTextElem(text: '@所有人');
    final second = _msg(
      elemType: MessageElemType.V2TIM_ELEM_TYPE_TEXT,
      isSelf: true,
      msgID: '144115267812600597-1783162477-222',
      seq: '88',
      timestamp: 1721196720,
      status: MessageStatus.V2TIM_MSG_STATUS_SEND_SUCC,
    );
    second.textElem = V2TimTextElem(text: '@所有人');

    final dedupedBySeq = TUIChatGlobalModel.dedupeMessagesForTesting(
      <V2TimMessage>[first, second],
    );
    expect(dedupedBySeq, hasLength(1));
    expect(dedupedBySeq.single.textElem?.text, '@所有人');

    final third = _msg(
      elemType: MessageElemType.V2TIM_ELEM_TYPE_TEXT,
      isSelf: true,
      msgID: '144115267812600597-1783162477-333',
      timestamp: 1721196720,
      status: MessageStatus.V2TIM_MSG_STATUS_SEND_SUCC,
    );
    third.textElem = V2TimTextElem(text: '@所有人');
    final fourth = _msg(
      elemType: MessageElemType.V2TIM_ELEM_TYPE_TEXT,
      isSelf: true,
      msgID: '144115267812600597-1783162477-444',
      timestamp: 1721196720,
      status: MessageStatus.V2TIM_MSG_STATUS_SEND_SUCC,
    );
    fourth.textElem = V2TimTextElem(text: '@所有人');

    final dedupedByEcho = TUIChatGlobalModel.dedupeMessagesForTesting(
      <V2TimMessage>[third, fourth],
    );
    expect(dedupedByEcho, hasLength(1));
    expect(
      TUIChatGlobalModel.messagesCorrelateForDedup(third, fourth),
      isTrue,
    );
  });

  test('dedupeMessages keeps same-second identical group self sends by seq', () {
    const groupID = '@TGS#2BXXNKM5CS';
    const ts = 1750000000;
    const text =
        '今天开到这里先暂停，新平台比较忙要设置这个那个加好友等等以及新机器人一直在优化的问题';
    V2TimMessage send(String msgID, String seq, {int? random, String? id}) {
      final message = _msg(
        elemType: MessageElemType.V2TIM_ELEM_TYPE_TEXT,
        isSelf: true,
        groupID: groupID,
        msgID: msgID,
        id: id,
        seq: seq,
        random: random,
        timestamp: ts,
        status: MessageStatus.V2TIM_MSG_STATUS_SEND_SUCC,
      );
      message.sender = 'self_user';
      message.textElem = V2TimTextElem(text: text);
      return message;
    }

    final first = send('144115267812600597-1783162477-101', '101', random: 11);
    final second = send('144115267812600597-1783162477-102', '102', random: 12);
    final third = send('144115267812600597-1783162477-103', '103', random: 13);

    expect(
      TUIChatGlobalModel.messagesCorrelateForDedup(first, second),
      isFalse,
    );
    final deduped = TUIChatGlobalModel.dedupeMessagesForTesting(
      <V2TimMessage>[first, second, third],
    );
    expect(deduped, hasLength(3));
  });

  test('dedupeMessages keeps identical peer group messages with distinct seq',
      () {
    const groupID = '@TGS#2BXXNKM5CS';
    V2TimMessage peer(String msgID, String seq) {
      final message = _msg(
        elemType: MessageElemType.V2TIM_ELEM_TYPE_TEXT,
        isSelf: false,
        groupID: groupID,
        msgID: msgID,
        seq: seq,
        random: 99,
        timestamp: 1750000000,
        status: MessageStatus.V2TIM_MSG_STATUS_SEND_SUCC,
      );
      message.sender = 'peer_user';
      message.textElem = V2TimTextElem(text: '重复内容');
      return message;
    }

    final first = peer('sdk-peer-101', '101');
    final second = peer('sdk-peer-102', '102');

    expect(
      TUIChatGlobalModel.messagesCorrelateForDedup(first, second),
      isFalse,
    );
    expect(
      TUIChatGlobalModel.dedupeMessagesForTesting(
        <V2TimMessage>[first, second],
      ),
      hasLength(2),
    );
  });

  test('dedupeMessages still merges group copies with the same seq', () {
    const groupID = '@TGS#2BXXNKM5CS';
    final first = _msg(
      elemType: MessageElemType.V2TIM_ELEM_TYPE_TEXT,
      isSelf: false,
      groupID: groupID,
      msgID: 'sdk-copy-101',
      seq: '101',
      timestamp: 1750000000,
      status: MessageStatus.V2TIM_MSG_STATUS_SEND_SUCC,
    );
    final second = _msg(
      elemType: MessageElemType.V2TIM_ELEM_TYPE_TEXT,
      isSelf: false,
      groupID: groupID,
      msgID: 'archive-copy-101',
      seq: '101',
      timestamp: 1750000000,
      status: MessageStatus.V2TIM_MSG_STATUS_SEND_SUCC,
    );

    expect(
      TUIChatGlobalModel.dedupeMessagesForTesting(
        <V2TimMessage>[first, second],
      ),
      hasLength(1),
    );
  });

  test('dedupeMessages keeps same-second group sending placeholders by client id',
      () {
    const groupID = '@TGS#2BXXNKM5CS';
    const ts = 1750000000;
    const text = '重复发送同一段话';
    V2TimMessage sending(String id) {
      final message = _msg(
        elemType: MessageElemType.V2TIM_ELEM_TYPE_TEXT,
        isSelf: true,
        groupID: groupID,
        id: id,
        timestamp: ts,
        status: MessageStatus.V2TIM_MSG_STATUS_SENDING,
      );
      message.sender = 'self_user';
      message.textElem = V2TimTextElem(text: text);
      return message;
    }

    final deduped = TUIChatGlobalModel.dedupeMessagesForTesting(
      <V2TimMessage>[
        sending('opt_1'),
        sending('opt_2'),
        sending('opt_3'),
      ],
    );
    expect(deduped, hasLength(3));
  });

  test('dedupeMessages merges group archive when Web SDK lacks groupID', () {
    const groupID = '@TGS#2BXXNKM5CS';
    final archive = _msg(
      elemType: MessageElemType.V2TIM_ELEM_TYPE_TEXT,
      isSelf: false,
      groupID: groupID,
      msgID: '$groupID:42',
      seq: '42',
      status: MessageStatus.V2TIM_MSG_STATUS_SEND_SUCC,
    );
    archive.textElem = V2TimTextElem(text: ', , , ');
    archive.localCustomData =
        jsonEncode(const <String, Object?>{'archiveHistory': true});
    final sdk = _msg(
      elemType: MessageElemType.V2TIM_ELEM_TYPE_TEXT,
      isSelf: true,
      msgID: '144115267812600597-1783162477-999',
      seq: '42',
      status: MessageStatus.V2TIM_MSG_STATUS_SEND_SUCC,
    );
    sdk.textElem = V2TimTextElem(text: ', , , ');
    // Web SDK 漫游偶发缺 groupID：此前会被误判为 C2C，无法与归档 correlate。

    final deduped = TUIChatGlobalModel.dedupeMessagesForTesting(
      <V2TimMessage>[archive, sdk],
    );

    expect(deduped, hasLength(1));
    expect(deduped.single.msgID, archive.msgID);
    expect(
      TUIChatGlobalModel.messagesCorrelateForDedup(archive, sdk),
      isTrue,
    );
  });

  test('dedupeMessages merges C2C archive and SDK copy by content', () {
    const peer = 'peer_user';
    const self = 'self_user';
    const text = '不用管';
    const ts = 1750000000;
    final archive = _c2cTextMsg(
      text: text,
      userID: peer,
      sender: self,
      msgID: 'archive-msg-key-001',
      timestamp: ts,
      isSelf: false,
      localCustomData: jsonEncode(const <String, Object?>{'archiveHistory': true}),
    );
    final sdk = _c2cTextMsg(
      text: text,
      userID: peer,
      sender: self,
      msgID: '144115267812600597-1783162477-180902858',
      timestamp: ts,
      isSelf: true,
    );

    final deduped = TUIChatGlobalModel.dedupeMessagesForTesting(
      <V2TimMessage>[archive, sdk],
    );

    expect(deduped, hasLength(1));
    expect(deduped.single.msgID, archive.msgID);
    expect(deduped.single.isSelf, isTrue);
  });

  test('dedupeMessages merges C2C archive image with SDK by wire identity', () {
    const peer = 'k6qxy77crk';
    const self = 'self_user';
    const ts = 1785663586;
    const random = 566185649;
    final archive = _msg(
      elemType: MessageElemType.V2TIM_ELEM_TYPE_IMAGE,
      msgID: '463257603_${random}_$ts',
      random: random,
      timestamp: ts,
      isSelf: true,
      status: MessageStatus.V2TIM_MSG_STATUS_SEND_SUCC,
      localCustomData:
          jsonEncode(const <String, Object?>{'archiveHistory': true}),
    );
    archive.userID = peer;
    archive.sender = self;
    archive.msgID = '463257603_${random}_$ts';
    final sdk = _msg(
      elemType: MessageElemType.V2TIM_ELEM_TYPE_IMAGE,
      msgID: '144115268026882536-$ts-$random',
      random: random,
      timestamp: ts,
      isSelf: true,
      status: MessageStatus.V2TIM_MSG_STATUS_SEND_SUCC,
    );
    sdk.userID = peer;
    sdk.sender = self;
    sdk.msgID = '144115268026882536-$ts-$random';
    sdk.imageElem = archive.imageElem;

    expect(
      TUIChatGlobalModel.parseC2cWireIdentityForTesting(archive)?.random,
      random,
    );
    expect(
      TUIChatGlobalModel.parseC2cWireIdentityForTesting(sdk)?.random,
      random,
    );
    expect(
      TUIChatGlobalModel.messagesCorrelateForDedup(archive, sdk),
      isTrue,
    );

    final deduped = TUIChatGlobalModel.dedupeMessagesForTesting(
      <V2TimMessage>[sdk, archive],
    );
    expect(deduped, hasLength(1));
    expect(deduped.single.msgID, archive.msgID);
    expect(
      HistoryPaginationAnchor.isArchiveHistoryMessage(deduped.single),
      isTrue,
    );
  });

  test('mergePeekWindowWithLiveMemory keeps C2C archive over SDK window', () {
    const peer = 'k6qxy77crk';
    const self = 'self_user';
    const ts = 1785663586;
    const random = 566185649;
    final archive = _msg(
      elemType: MessageElemType.V2TIM_ELEM_TYPE_IMAGE,
      msgID: '463257603_${random}_$ts',
      random: random,
      timestamp: ts,
      isSelf: true,
      status: MessageStatus.V2TIM_MSG_STATUS_SEND_SUCC,
      localCustomData:
          jsonEncode(const <String, Object?>{'archiveHistory': true}),
    );
    archive.userID = peer;
    archive.sender = self;
    archive.msgID = '463257603_${random}_$ts';
    final older = _c2cTextMsg(
      text: 'old',
      userID: peer,
      sender: peer,
      msgID: '144115267826741382-1783411847-3364154496',
      timestamp: 1783411847,
      isSelf: false,
    );
    final sdk = _msg(
      elemType: MessageElemType.V2TIM_ELEM_TYPE_IMAGE,
      msgID: '144115268026882536-$ts-$random',
      random: random,
      timestamp: ts,
      isSelf: true,
      status: MessageStatus.V2TIM_MSG_STATUS_SEND_SUCC,
    );
    sdk.userID = peer;
    sdk.sender = self;
    sdk.msgID = '144115268026882536-$ts-$random';

    final merged = TUIChatGlobalModel.mergePeekWindowWithLiveMemory(
      existing: <V2TimMessage>[archive, older],
      fetched: <V2TimMessage>[sdk, older],
    );

    expect(merged, hasLength(2));
    final image = merged.firstWhere(
      (m) => m.elemType == MessageElemType.V2TIM_ELEM_TYPE_IMAGE,
    );
    expect(image.msgID, archive.msgID);
    expect(HistoryPaginationAnchor.isArchiveHistoryMessage(image), isTrue);
  });

  test('mergePeekWindowWithLiveMemory keeps uncovered archive gap fills', () {
    const peer = 'acnj6oxey9';
    const self = 'q14gkm5swv';
    final newest = _c2cTextMsg(
      text: 'newest',
      userID: peer,
      sender: self,
      msgID: '$self-1785751874-3468974440',
      timestamp: 1785751874,
      isSelf: true,
    );
    final gapArchives = <V2TimMessage>[
      for (final entry in <(int, int, int)>[
        (2177769875, 2024904741, 1785749519),
        (2177769874, 2024904740, 1785749518),
        (2177769870, 2024904736, 1785749512),
      ])
        () {
          final msg = _msg(
            elemType: MessageElemType.V2TIM_ELEM_TYPE_TEXT,
            msgID: '${entry.$1}_${entry.$2}_${entry.$3}',
            random: entry.$2,
            timestamp: entry.$3,
            isSelf: false,
            status: MessageStatus.V2TIM_MSG_STATUS_SEND_SUCC,
            localCustomData:
                jsonEncode(const <String, Object?>{'archiveHistory': true}),
          );
          msg.userID = peer;
          msg.sender = peer;
          msg.msgID = '${entry.$1}_${entry.$2}_${entry.$3}';
          msg.textElem = V2TimTextElem(text: 'gap-${entry.$1}');
          return msg;
        }(),
    ];

    final merged = TUIChatGlobalModel.mergePeekWindowWithLiveMemory(
      existing: <V2TimMessage>[newest, ...gapArchives],
      fetched: <V2TimMessage>[newest],
    );

    expect(merged, hasLength(4));
    for (final archive in gapArchives) {
      expect(
        merged.any((m) => m.msgID == archive.msgID),
        isTrue,
        reason: 'peek must retain uncovered archive ${archive.msgID}',
      );
    }
  });

  test('parseC2cWireIdentity reads userId-ts-random msgID', () {
    const peer = 'acnj6oxey9';
    const self = 'q14gkm5swv';
    const ts = 1785731054;
    const random = 174908238;
    final msg = _c2cTextMsg(
      text: 'call',
      userID: peer,
      sender: self,
      msgID: '$self-$ts-$random',
      timestamp: ts,
      isSelf: true,
    );
    final wire = TUIChatGlobalModel.parseC2cWireIdentityForTesting(msg);
    expect(wire, isNotNull);
    expect(wire!.timestampSec, ts);
    expect(wire.random, random);
  });

  test('parseC2cWireIdentity early-out skips probe when ts+random set', () {
    RegExpProbe.debugForceEnabled = true;
    RegExpProbe.reset();
    addTearDown(() {
      RegExpProbe.debugForceEnabled = false;
      RegExpProbe.reset();
    });

    const peer = 'acnj6oxey9';
    const self = 'q14gkm5swv';
    const ts = 1785732001;
    const random = 174908301;
    final msg = _c2cTextMsg(
      text: 'early',
      userID: peer,
      sender: self,
      msgID: '$self-$ts-$random',
      timestamp: ts,
      isSelf: true,
    );
    msg.random = random;

    final wire = TUIChatGlobalModel.parseC2cWireIdentityForTesting(msg);
    expect(wire, isNotNull);
    expect(wire!.timestampSec, ts);
    expect(wire.random, random);
    expect(
      RegExpProbe.snapshotForTesting()['msgId.c2cWireIdentity']?.calls ?? 0,
      0,
    );
  });

  test('parseC2cWireIdentity fills from msgID when fields missing', () {
    const peer = 'acnj6oxey9';
    const self = 'q14gkm5swv';
    const ts = 1785732102;
    const random = 174908402;
    final msg = _c2cTextMsg(
      text: 'fill',
      userID: peer,
      sender: self,
      msgID: '$self-$ts-$random',
      timestamp: 0,
      isSelf: true,
    );
    msg.timestamp = 0;
    msg.random = 0;

    final wire = TUIChatGlobalModel.parseC2cWireIdentityForTesting(msg);
    expect(wire, isNotNull);
    expect(wire!.timestampSec, ts);
    expect(wire.random, random);
    expect(wire.sender, self);
  });

  test('parseC2cWireIdentity fills from archive underscore msgID', () {
    const peer = 'acnj6oxey9';
    const self = 'q14gkm5swv';
    const ts = 1785732203;
    const random = 174908503;
    final msg = _c2cTextMsg(
      text: 'archive-fill',
      userID: peer,
      sender: self,
      msgID: '463257603_${random}_$ts',
      timestamp: 0,
      isSelf: true,
    );
    msg.timestamp = 0;
    msg.random = 0;

    final wire = TUIChatGlobalModel.parseC2cWireIdentityForTesting(msg);
    expect(wire, isNotNull);
    expect(wire!.timestampSec, ts);
    expect(wire.random, random);
  });

  test('parseC2cWireIdentity rejects malformed msgID without fields', () {
    const peer = 'acnj6oxey9';
    const self = 'q14gkm5swv';
    final msg = _c2cTextMsg(
      text: 'bad',
      userID: peer,
      sender: self,
      msgID: 'not-a-wire-id',
      timestamp: 0,
      isSelf: true,
    );
    msg.timestamp = 0;
    msg.random = 0;

    expect(TUIChatGlobalModel.parseC2cWireIdentityForTesting(msg), isNull);
  });

  test('dedupeMessages merges userId-ts-random SDK with archive seq_random_ts', () {
    const peer = 'acnj6oxey9';
    const self = 'q14gkm5swv';
    const ts = 1785749519;
    const random = 2024904741;
    final archive = _c2cTextMsg(
      text: 'hole',
      userID: peer,
      sender: peer,
      msgID: '2177769875_${random}_$ts',
      timestamp: ts,
      isSelf: false,
      localCustomData:
          jsonEncode(const <String, Object?>{'archiveHistory': true}),
    );
    archive.random = random;
    final sdk = _c2cTextMsg(
      text: 'hole',
      userID: peer,
      sender: peer,
      msgID: '$self-$ts-$random',
      timestamp: ts,
      isSelf: false,
    );
    sdk.random = random;

    expect(
      TUIChatGlobalModel.messagesCorrelateForDedup(archive, sdk),
      isTrue,
    );
    final deduped = TUIChatGlobalModel.dedupeMessagesForTesting(
      <V2TimMessage>[sdk, archive],
    );
    expect(deduped, hasLength(1));
    expect(deduped.single.msgID, archive.msgID);
  });

  test('dedupeMessages merges duplicate self group text by seq', () {
    const groupID = '@TGS#2BXXNKM5CS';
    final archive = _msg(
      elemType: MessageElemType.V2TIM_ELEM_TYPE_TEXT,
      isSelf: true,
      groupID: groupID,
      msgID: '$groupID:42',
      seq: '42',
      status: MessageStatus.V2TIM_MSG_STATUS_SEND_SUCC,
    );
    archive.textElem = V2TimTextElem(text: '1');
    final sdk = _msg(
      elemType: MessageElemType.V2TIM_ELEM_TYPE_TEXT,
      isSelf: true,
      groupID: groupID,
      msgID: '144115267812600597-1783162477-999',
      seq: '42',
      status: MessageStatus.V2TIM_MSG_STATUS_SEND_SUCC,
    );
    sdk.textElem = V2TimTextElem(text: '1');

    final deduped = TUIChatGlobalModel.dedupeMessagesForTesting(
      <V2TimMessage>[archive, sdk],
    );

    expect(deduped, hasLength(1));
    expect(deduped.single.textElem?.text, '1');
  });

  test('C2C official older page keeps 20 unique SDK rows with repeated digits',
      () {
    const peer = 'rqwm8onw3j';
    const self = 'q14gkm5swv';
    V2TimMessage row({
      required String msgID,
      required int ts,
      required String text,
      required String seq,
    }) {
      final message = _c2cTextMsg(
        text: text,
        userID: peer,
        sender: self,
        msgID: msgID,
        timestamp: ts,
        isSelf: true,
      );
      message.seq = seq;
      message.random = 1;
      return message;
    }

    final existing = <V2TimMessage>[
      row(
        msgID: '144115250268987090-1787391925-202147721',
        ts: 1787391925,
        text: '，',
        seq: '2220862973',
      ),
      ...List<V2TimMessage>.generate(37, (i) {
        return row(
          msgID: '144115250268987090-1787391106-${202147706 - i}',
          ts: 1787391106 - i,
          text: '${(i % 9) + 1}',
          seq: '${2220862958 - i}',
        );
      }),
    ];
    final fetched = <V2TimMessage>[
      row(
        msgID: '144115250268987090-1787389303-2245723239',
        ts: 1787389303,
        text: '0',
        seq: '3779632708',
      ),
      ...List<V2TimMessage>.generate(17, (i) {
        return row(
          msgID: '144115250268987090-1787389302-${2245723238 - i}',
          ts: 1787389302 - (i ~/ 2),
          text: '${9 - (i % 9)}',
          seq: '${3779632707 - i}',
        );
      }),
      row(
        msgID: '144115250268987090-1787389290-2245723229',
        ts: 1787389290,
        text: '--------------',
        seq: '3779632698',
      ),
      row(
        msgID: '144115250268987090-1787388747-3974300079',
        ts: 1787388747,
        text: '11111',
        seq: '2957041275',
      ),
    ];

    expect(existing, hasLength(38));
    expect(fetched, hasLength(20));
    expect(
      TUIChatGlobalModel.messagesCorrelateForDedup(existing[2], fetched[1]),
      isFalse,
    );
    final collapsed = TUIChatGlobalModel.mergeHistoricalWithInMemory(
      existing: existing,
      fetched: fetched,
    );
    final merged = TUIChatGlobalModel.mergeC2cOfficialOlderPage(
      existing: existing,
      fetched: fetched,
    );
    expect(merged, hasLength(58));
    expect(collapsed.length, greaterThanOrEqualTo(58));
    expect(
      merged.map((m) => m.msgID).toSet(),
      hasLength(58),
    );
  });

  test('dedupeMessages keeps same-second distinct sends from same user', () {
    const peer = 'peer_user';
    const self = 'self_user';
    const ts = 1750000000;
    final first = _c2cTextMsg(
      text: 'ok',
      userID: peer,
      sender: self,
      msgID: '144115267812600597-1783162477-180902858',
      timestamp: ts,
      isSelf: true,
    );
    final second = _c2cTextMsg(
      text: 'ok',
      userID: peer,
      sender: self,
      msgID: '144115267812600597-1783162477-180902859',
      timestamp: ts,
      isSelf: true,
    );

    final deduped = TUIChatGlobalModel.dedupeMessagesForTesting(
      <V2TimMessage>[first, second],
    );

    expect(deduped, hasLength(2));
  });

  test('compareMessagesChronological localSeq tie-break', () {
    final earlier = _msg(
      elemType: MessageElemType.V2TIM_ELEM_TYPE_TEXT,
      id: 'a',
      timestamp: 100,
      seq: '1',
      localCustomData: _localSeqData(3),
    );
    final later = _msg(
      elemType: MessageElemType.V2TIM_ELEM_TYPE_TEXT,
      id: 'b',
      timestamp: 100,
      seq: '1',
      localCustomData: _localSeqData(5),
    );

    expect(
      TUIChatGlobalModel.compareMessagesChronological(earlier, later),
      lessThan(0),
    );
    expect(
      TUIChatGlobalModel.compareMessagesChronological(later, earlier),
      greaterThan(0),
    );
  });

  test('compareMessagesChronological random id fallback unchanged', () {
    final left = _msg(
      elemType: MessageElemType.V2TIM_ELEM_TYPE_TEXT,
      id: 'alpha',
      msgID: 'alpha',
      timestamp: 100,
      seq: '1',
    );
    final right = _msg(
      elemType: MessageElemType.V2TIM_ELEM_TYPE_TEXT,
      id: 'beta',
      msgID: 'beta',
      timestamp: 100,
      seq: '2',
    );

    expect(
      TUIChatGlobalModel.compareMessagesChronological(left, right),
      lessThan(0),
    );
  });

  test('server seq wins over non-monotonic timestamp (rizhi repro)', () {
    final fifth = _msg(
      elemType: MessageElemType.V2TIM_ELEM_TYPE_TEXT,
      id: 'temp-5',
      msgID: '144115268012739422-1783099556-4277357490',
      timestamp: 1783099556,
      seq: '1477',
      status: MessageStatus.V2TIM_MSG_STATUS_SEND_SUCC,
      groupID: '@TGS#2BXXNKM5CS',
    );
    final sixth = _msg(
      elemType: MessageElemType.V2TIM_ELEM_TYPE_TEXT,
      id: 'temp-6',
      msgID: '144115268012739422-1783099555-1091889746',
      timestamp: 1783099555,
      seq: '1478',
      status: MessageStatus.V2TIM_MSG_STATUS_SEND_SUCC,
      groupID: '@TGS#2BXXNKM5CS',
    );

    final sorted = TUIChatGlobalModel.sortMessagesChronologicallyAsc(
      <V2TimMessage>[sixth, fifth],
    );

    expect(sorted.map((item) => item.id).toList(), <String>['temp-5', 'temp-6']);
  });

  test('sending placeholder stays newest on same-second tie (rizhi2 repro)', () {
    // Resolved message sent moments ago, same wall-clock second as the new tap.
    final resolved = _msg(
      elemType: MessageElemType.V2TIM_ELEM_TYPE_TEXT,
      id: 'created_temp_id-3',
      msgID: '144115268012739422-1783102482-1011022579',
      timestamp: 1783102482,
      seq: '1545',
      status: MessageStatus.V2TIM_MSG_STATUS_SEND_SUCC,
      localCustomData: _localSeqData(3),
      groupID: '@TGS#2BXXNKM5CS',
    );
    // Just-tapped placeholder: no server seq yet, SENDING, same timestamp.
    final placeholder = _msg(
      elemType: MessageElemType.V2TIM_ELEM_TYPE_TEXT,
      id: 'created_temp_id-4',
      timestamp: 1783102482,
      status: MessageStatus.V2TIM_MSG_STATUS_SENDING,
      localCustomData: _localSeqData(4),
    );

    final newestFirst = TUIChatGlobalModel.sortMessagesNewestFirst(
      <V2TimMessage>[resolved, placeholder],
    );

    // The live placeholder must be the newest row (index 0), not demoted below
    // the already-resolved same-second message.
    expect(
      newestFirst.map((item) => item.id).toList(),
      <String>['created_temp_id-4', 'created_temp_id-3'],
    );
  });

  test('C2C orders by timestamp, ignoring per-sender seq (rizhi3 repro)', () {
    // Real C2C data: self and peer number their messages independently, so the
    // older peer message has a LARGER seq than the newer self message. Ordering
    // must follow timestamps, never the incomparable per-sender seq.
    final selfNewer = _msg(
      elemType: MessageElemType.V2TIM_ELEM_TYPE_TEXT,
      isSelf: true,
      id: 'self-newer',
      msgID: '144115268012739422-1783091996-849593802',
      timestamp: 1783091996,
      seq: '3625744112',
      status: MessageStatus.V2TIM_MSG_STATUS_SEND_SUCC,
    );
    final peerOlder = _msg(
      elemType: MessageElemType.V2TIM_ELEM_TYPE_TEXT,
      isSelf: false,
      id: 'peer-older',
      msgID: '144115267812600597-1783017560-4232315847',
      timestamp: 1783017561,
      seq: '3842201582',
      status: MessageStatus.V2TIM_MSG_STATUS_SEND_SUCC,
    );

    final newestFirst = TUIChatGlobalModel.sortMessagesNewestFirst(
      <V2TimMessage>[peerOlder, selfNewer],
    );

    // selfNewer has the smaller seq but the larger timestamp: it must be newest.
    expect(
      newestFirst.map((item) => item.id).toList(),
      <String>['self-newer', 'peer-older'],
    );
  });

  test('distinct inbound batch is equivalent to sequential inserts', () {
    final existing = <V2TimMessage>[
      _msg(
        elemType: MessageElemType.V2TIM_ELEM_TYPE_TEXT,
        isSelf: false,
        msgID: 'existing',
        timestamp: 100,
      ),
    ];
    final incoming = List<V2TimMessage>.generate(
      1000,
      (index) => _msg(
        elemType: MessageElemType.V2TIM_ELEM_TYPE_TEXT,
        isSelf: false,
        msgID: 'incoming-$index',
        timestamp: 101 + index,
      ),
    ).reversed.toList();

    var sequential = List<V2TimMessage>.from(existing);
    for (final message in incoming) {
      sequential = TUIChatGlobalModel.sortMessagesNewestFirst(
        <V2TimMessage>[message, ...sequential],
      );
    }
    final batched =
        TUIChatGlobalModel.appendDistinctIncomingBatchForTesting(
      existing: existing,
      incoming: incoming,
    );

    expect(
      batched.map((message) => message.msgID).toList(),
      sequential.map((message) => message.msgID).toList(),
    );
    expect(batched, hasLength(existing.length + incoming.length));
  });

  test('distinct group burst preserves server seq ordering', () {
    const groupID = '@TGS#2BXXNKM5CS';
    final incoming = <V2TimMessage>[
      _msg(
        elemType: MessageElemType.V2TIM_ELEM_TYPE_TEXT,
        isSelf: false,
        msgID: 'sdk-103',
        seq: '103',
        timestamp: 100,
        groupID: groupID,
      ),
      _msg(
        elemType: MessageElemType.V2TIM_ELEM_TYPE_TEXT,
        isSelf: false,
        msgID: 'sdk-101',
        seq: '101',
        timestamp: 300,
        groupID: groupID,
      ),
      _msg(
        elemType: MessageElemType.V2TIM_ELEM_TYPE_TEXT,
        isSelf: false,
        msgID: 'sdk-102',
        seq: '102',
        timestamp: 200,
        groupID: groupID,
      ),
    ];

    final batched =
        TUIChatGlobalModel.appendDistinctIncomingBatchForTesting(
      existing: const <V2TimMessage>[],
      incoming: incoming,
    );

    expect(
      batched.map((message) => message.seq).toList(),
      <String?>['103', '102', '101'],
    );
  });

  test('visible projection hides rows without changing authority', () {
    final authority = <V2TimMessage>[
      _msg(
        elemType: MessageElemType.V2TIM_ELEM_TYPE_TEXT,
        isSelf: false,
        msgID: 'm3',
        timestamp: 3,
      ),
      _msg(
        elemType: MessageElemType.V2TIM_ELEM_TYPE_TEXT,
        isSelf: false,
        msgID: 'm2',
        timestamp: 2,
      ),
      _msg(
        elemType: MessageElemType.V2TIM_ELEM_TYPE_TEXT,
        isSelf: false,
        msgID: 'm1',
        timestamp: 1,
      ),
    ];
    final hidden = <String>{
      TUIChatGlobalModel.messageDedupKey(authority[0]),
      TUIChatGlobalModel.messageDedupKey(authority[1]),
    };

    final visible = TUIChatGlobalModel.filterHiddenProjectionForTesting(
      authoritativeMessages: authority,
      hiddenKeys: hidden,
    );

    expect(authority.map((message) => message.msgID), <String?>['m3', 'm2', 'm1']);
    expect(visible.map((message) => message.msgID), <String?>['m1']);
    expect(authority, hasLength(3));
  });

  test('dedupeMessages merges C2C isSelf mirror duplicate for peer text', () {
    const peer = 'acnj6oxey9';
    const text = '66666';
    const ts = 1785184200;
    const msgID = '144115268012739422-1785184219-78121925';
    final incoming = _c2cTextMsg(
      text: text,
      userID: peer,
      sender: peer,
      msgID: msgID,
      timestamp: ts,
      isSelf: false,
    );
    final wrongSelf = _c2cTextMsg(
      text: text,
      userID: peer,
      sender: peer,
      msgID: msgID,
      timestamp: ts,
      isSelf: true,
    );

    expect(
      TUIChatGlobalModel.messagesCorrelateForDedup(incoming, wrongSelf),
      isTrue,
    );

    final deduped = TUIChatGlobalModel.dedupeMessagesForTesting(<V2TimMessage>[
      wrongSelf,
      incoming,
    ]);

    expect(deduped, hasLength(1));
    expect(deduped.single.isSelf, isFalse);
    expect(deduped.single.msgID, incoming.msgID);
  });

  test('dedupeMessages merges C2C SDK copy with preview client echo', () {
    const peer = 'acnj6oxey9';
    const login = 'rqwm8onw3j';
    const text = '66666';
    const ts = 1785184220;
    const sdkMsgID = '144115268012739422-1785184219-78121925';
    final sdkPeer = _c2cTextMsg(
      text: text,
      userID: peer,
      sender: peer,
      msgID: sdkMsgID,
      timestamp: ts,
      isSelf: false,
    );
    final previewEcho = _c2cTextMsg(
      text: text,
      userID: peer,
      sender: login,
      msgID: '',
      timestamp: ts,
      isSelf: true,
    );
    previewEcho.id = 'rqwm8onw3j_${ts}___1';

    expect(
      TUIChatGlobalModel.messagesCorrelateForDedup(sdkPeer, previewEcho),
      isTrue,
    );

    final deduped = TUIChatGlobalModel.dedupeMessagesForTesting(<V2TimMessage>[
      sdkPeer,
      previewEcho,
    ]);

    expect(deduped, hasLength(1));
    expect(deduped.single.msgID, sdkMsgID);
    expect(deduped.single.isSelf, isFalse);
  });

  test('dedupeMessages merges msgID/id alias copies of the same message', () {
    const ts = 1700000123;
    const text = '123123';
    const userID = 'user_a';
    const sdkMsgID = '144115188075855872-1700000123-1234567890';
    final byMsgID = _c2cTextMsg(
      text: text,
      userID: userID,
      sender: userID,
      msgID: sdkMsgID,
      timestamp: ts,
      isSelf: true,
    );
    final byClientId = _c2cTextMsg(
      text: text,
      userID: userID,
      sender: userID,
      msgID: '',
      timestamp: ts,
      isSelf: true,
    );
    byClientId.id = sdkMsgID;

    final deduped = TUIChatGlobalModel.dedupeMessagesForTesting(<V2TimMessage>[
      byMsgID,
      byClientId,
    ]);

    expect(deduped, hasLength(1));
    expect(
      TUIChatGlobalModel.messagesCorrelateForDedup(byMsgID, byClientId),
      isTrue,
    );
  });

  test('normalizeMessageEpochSeconds converts ms mistaken for seconds', () {
    expect(
      TUIChatGlobalModel.normalizeMessageEpochSeconds(1785238080000),
      1785238080,
    );
    expect(
      TUIChatGlobalModel.normalizeMessageEpochSeconds(1785238080),
      1785238080,
    );
  });

  test('older peer sorts above newer self burst in display order', () {
    const peer = 'bot_user';
    const tsSelf = 1785238080;
    const tsPeer = tsSelf - 60;
    final peerMsg = _c2cTextMsg(
      text: '56',
      userID: peer,
      sender: peer,
      msgID: '144115268012739422-1785238070-11111111',
      timestamp: tsPeer,
      isSelf: false,
    );
    final selfBurst = List<V2TimMessage>.generate(6, (index) {
      return _c2cTextMsg(
        text: index == 5 ? '444' : '4',
        userID: peer,
        sender: 'self_user',
        msgID: '144115268012739422-1785238080-${index + 1}',
        timestamp: tsSelf,
        isSelf: true,
        localCustomData: _localSeqData(index + 1),
      );
    });

    // 模拟 send_done 原位更新后存储序错乱：旧 peer 被顶到 index 0。
    final scrambled = <V2TimMessage>[peerMsg, ...selfBurst.reversed];
    expect(
      TUIChatGlobalModel.isNewestFirstStorageOrderValid(scrambled),
      isFalse,
    );

    final sorted = TUIChatGlobalModel.sortMessagesNewestFirst(scrambled);
    expect(sorted.first.msgID, selfBurst.last.msgID);
    expect(sorted.last.textElem?.text, '56');
    expect(
      TUIChatGlobalModel.isNewestFirstStorageOrderValid(sorted),
      isTrue,
    );
  });

  test('C2C same-second peer reply sorts after self sends', () {
    const peer = 'bot_user';
    const ts = 1785238080;
    final self = _c2cTextMsg(
      text: '4',
      userID: peer,
      sender: 'self_user',
      msgID: '144115268012739422-1785238080-1',
      timestamp: ts,
      isSelf: true,
      localCustomData: _localSeqData(1),
    );
    final peerReply = _c2cTextMsg(
      text: '56',
      userID: peer,
      sender: peer,
      msgID: '144115268012739422-1785238080-2',
      timestamp: ts,
      isSelf: false,
    );

    final sorted = TUIChatGlobalModel.sortMessagesNewestFirst(
      <V2TimMessage>[peerReply, self],
    );

    expect(sorted.first.msgID, peerReply.msgID);
    expect(sorted.last.msgID, self.msgID);
  });
}
