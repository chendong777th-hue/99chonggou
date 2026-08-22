import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tencent_cloud_chat_sdk/enum/message_elem_type.dart';
import 'package:tencent_cloud_chat_sdk/enum/message_status.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_image_elem.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_image_elem.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_message.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_message.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/view_models/chat_message_window.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/view_models/chat_message_window_policy.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/view_models/tui_chat_global_model.dart';

V2TimMessage _msg({
  bool isSelf = true,
  int? status,
  String? id,
  String? msgID,
  int? timestamp,
  int? localSeq,
  int elemType = MessageElemType.V2TIM_ELEM_TYPE_TEXT,
}) {
  final message = V2TimMessage.fromJson(<String, dynamic>{
    'message_server_time': timestamp ?? 1700000000,
    'message_msg_id': msgID,
    'message_is_from_self': isSelf,
    'message_status': status ?? MessageStatus.V2TIM_MSG_STATUS_SENDING,
    'message_custom_str': '',
    'message_risk_type_identified': 0,
    'message_sender_group_member_info': <String, dynamic>{},
    'message_group_at_user_array': <String>[],
    'elem_type': elemType,
  });
  message.elemType = elemType;
  message.id = id;
  message.status = status ?? MessageStatus.V2TIM_MSG_STATUS_SENDING;
  if (timestamp != null) {
    message.timestamp = timestamp;
  }
  message.isSelf = isSelf;
  if (localSeq != null) {
    message.localCustomData = jsonEncode(<String, dynamic>{
      '__outgoingLocalSeq': localSeq,
      '__outgoingLocalSentAt': timestamp ?? 1700000000,
    });
  }
  if (elemType == MessageElemType.V2TIM_ELEM_TYPE_IMAGE) {
    message.imageElem = V2TimImageElem(path: '/tmp/shot.jpg');
  }
  return message;
}

void main() {
  test('pin request matches alias conversation IDs', () {
    final source = File(
      'third_party/tencent_cloud_chat_uikit/lib/ui/views/TIMUIKitChat/'
      'TIMUIKItMessageList/tim_uikit_chat_history_message_list.dart',
    ).readAsStringSync();
    final start = source.indexOf('void _onPinToBottomRequested()');
    expect(start, greaterThanOrEqualTo(0));
    final end = source.indexOf('void _onGlobalRouteRestoreChanged()', start);
    expect(end, greaterThan(start));
    final body = source.substring(start, end);
    expect(body.contains('isSameConversationIdForHistory'), isTrue);
    expect(body.contains('convId != _conversationId()'), isFalse);
  });

  test('retain sending self when replace window lacks it', () {
    final extras = TUIChatGlobalModel.collectUncorrelatedInFlightOutgoing(
      previous: <V2TimMessage>[
        _msg(id: 'c1', status: MessageStatus.V2TIM_MSG_STATUS_SENDING),
      ],
      incoming: <V2TimMessage>[
        _msg(
          isSelf: false,
          id: 'peer1',
          status: MessageStatus.V2TIM_MSG_STATUS_SEND_SUCC,
        ),
      ],
    );
    expect(extras.map((m) => m.id), <String?>['c1']);
  });

  test('retain skips swapped placeholder with the same client id', () {
    final extras = TUIChatGlobalModel.collectUncorrelatedInFlightOutgoing(
      previous: <V2TimMessage>[
        _msg(id: 'c1', status: MessageStatus.V2TIM_MSG_STATUS_SENDING),
      ],
      incoming: <V2TimMessage>[
        _msg(
          id: 'c1',
          msgID: 'm1',
          status: MessageStatus.V2TIM_MSG_STATUS_SEND_SUCC,
        ),
      ],
    );
    expect(extras, isEmpty);
  });

  test('retain newer acked self missing from stale history snapshot', () {
    final extras = TUIChatGlobalModel.collectUncorrelatedInFlightOutgoing(
      previous: <V2TimMessage>[
        _msg(
          id: 'mine',
          status: MessageStatus.V2TIM_MSG_STATUS_SEND_SUCC,
          timestamp: 200,
        ),
      ],
      incoming: <V2TimMessage>[
        _msg(
          isSelf: false,
          id: 'peer',
          status: MessageStatus.V2TIM_MSG_STATUS_SEND_SUCC,
          timestamp: 100,
        ),
      ],
    );
    expect(extras.map((m) => m.id), <String?>['mine']);
  });

  test('retain ignores older acked self already behind incoming newest', () {
    final extras = TUIChatGlobalModel.collectUncorrelatedInFlightOutgoing(
      previous: <V2TimMessage>[
        _msg(
          id: 'old-self',
          status: MessageStatus.V2TIM_MSG_STATUS_SEND_SUCC,
          timestamp: 50,
        ),
      ],
      incoming: <V2TimMessage>[
        _msg(
          id: 'newest',
          status: MessageStatus.V2TIM_MSG_STATUS_SEND_SUCC,
          timestamp: 200,
        ),
      ],
    );
    expect(extras, isEmpty);
  });

  test('replace:false older page retains newer acked self 11111', () {
    final extras = TUIChatGlobalModel.collectUncorrelatedInFlightOutgoing(
      previous: <V2TimMessage>[
        _msg(
          id: 'mine',
          msgID: '11111',
          status: MessageStatus.V2TIM_MSG_STATUS_SEND_SUCC,
          timestamp: 200,
        ),
      ],
      incoming: <V2TimMessage>[
        for (var i = 0; i < 20; i++)
          _msg(
            isSelf: i.isEven,
            id: 'old-$i',
            msgID: 'old-msg-$i',
            status: MessageStatus.V2TIM_MSG_STATUS_SEND_SUCC,
            timestamp: 100 - i,
          ),
      ],
    );
    expect(extras.map((m) => m.msgID), <String?>['11111']);
  });

  test('retain session text after later image ack replace', () {
    final extras = TUIChatGlobalModel.collectUncorrelatedInFlightOutgoing(
      previous: <V2TimMessage>[
        _msg(
          id: 'text-1',
          msgID: 'text-msg',
          status: MessageStatus.V2TIM_MSG_STATUS_SEND_SUCC,
          timestamp: 100,
          localSeq: 2,
        ),
        _msg(
          id: 'img-opt',
          status: MessageStatus.V2TIM_MSG_STATUS_SENDING,
          timestamp: 100,
          localSeq: 1,
          elemType: MessageElemType.V2TIM_ELEM_TYPE_IMAGE,
        ),
      ],
      incoming: <V2TimMessage>[
        _msg(
          id: 'img-sdk',
          msgID: 'img-msg',
          status: MessageStatus.V2TIM_MSG_STATUS_SEND_SUCC,
          timestamp: 108,
          localSeq: 1,
          elemType: MessageElemType.V2TIM_ELEM_TYPE_IMAGE,
        ),
      ],
    );
    expect(extras.map((m) => m.id), <String?>['text-1']);
  });

  test('retain does not resurrect swapped image placeholder', () {
    final extras = TUIChatGlobalModel.collectUncorrelatedInFlightOutgoing(
      previous: <V2TimMessage>[
        _msg(
          id: 'img-opt',
          status: MessageStatus.V2TIM_MSG_STATUS_SENDING,
          timestamp: 100,
          localSeq: 1,
          elemType: MessageElemType.V2TIM_ELEM_TYPE_IMAGE,
        ),
      ],
      incoming: <V2TimMessage>[
        _msg(
          id: 'img-opt',
          msgID: 'img-msg',
          status: MessageStatus.V2TIM_MSG_STATUS_SEND_SUCC,
          timestamp: 108,
          localSeq: 1,
          elemType: MessageElemType.V2TIM_ELEM_TYPE_IMAGE,
        ),
      ],
    );
    expect(extras, isEmpty);
  });

  test('retain skips SDK ack already in incoming by msgID', () {
    final extras = TUIChatGlobalModel.collectUncorrelatedInFlightOutgoing(
      previous: <V2TimMessage>[
        _msg(
          id: 'c1',
          msgID: 'm1',
          status: MessageStatus.V2TIM_MSG_STATUS_SEND_SUCC,
          timestamp: 200,
        ),
      ],
      incoming: <V2TimMessage>[
        _msg(
          id: 'sdk-c1',
          msgID: 'm1',
          status: MessageStatus.V2TIM_MSG_STATUS_SEND_SUCC,
          timestamp: 200,
        ),
      ],
    );
    expect(extras, isEmpty);
  });

  test('memory window trim around old anchor still restores newest self', () {
    final previous = <V2TimMessage>[
      _msg(
        id: 'tip',
        msgID: '--------------',
        status: MessageStatus.V2TIM_MSG_STATUS_SEND_SUCC,
        timestamp: 10000,
      ),
      for (var i = 0; i < 177; i++)
        _msg(
          isSelf: i.isEven,
          id: 'hist-$i',
          msgID: 'hist-msg-$i',
          status: MessageStatus.V2TIM_MSG_STATUS_SEND_SUCC,
          timestamp: 9999 - i,
        ),
    ];
    expect(previous.length, 178);
    expect(previous.length, greaterThan(ChatMessageWindowPolicy.softMax));

    final trimmed = ChatMessageWindow.trimToWindow(
      list: previous,
      preferLatest: false,
      anchorMsgID: previous.last.msgID,
    );
    expect(trimmed.didTrim, isTrue);
    expect(
      trimmed.list.any((m) => m.msgID == '--------------'),
      isFalse,
    );

    final restored = TUIChatGlobalModel.restoreUncorrelatedInFlightOutgoing(
      previous: previous,
      incoming: trimmed.list,
    );
    expect(restored.any((m) => m.msgID == '--------------'), isTrue);
    expect(restored.first.msgID, '--------------');
  });

  test('older-history commit reads alias memory and replace-writes full window',
      () {
    final source = File(
      'third_party/tencent_cloud_chat_uikit/lib/business_logic/'
      'separate_models/tui_chat_separate_view_model.dart',
    ).readAsStringSync();
    final mergeStart = source.indexOf(
      'List<V2TimMessage> _mergeWithInMemoryHistory(',
    );
    expect(mergeStart, greaterThanOrEqualTo(0));
    final mergeEnd = source.indexOf(
      'String _peekWindowBatchSignature(',
      mergeStart,
    );
    expect(mergeEnd, greaterThan(mergeStart));
    final mergeBody = source.substring(mergeStart, mergeEnd);
    expect(mergeBody.contains('mergedAliasMessageList'), isTrue);
    expect(mergeBody.contains('messageListMap[conversationID]'), isFalse);

    final commitStart = source.indexOf('void _commitHistoricalMessages(');
    expect(commitStart, greaterThanOrEqualTo(0));
    final commitEnd = source.indexOf(
      'late final HistoryPaginationLoadRunner _historyLoadRunner',
      commitStart,
    );
    expect(commitEnd, greaterThan(commitStart));
    final commitBody = source.substring(commitStart, commitEnd);
    expect(commitBody.contains('mergedAliasMessageList'), isTrue);
    expect(commitBody.contains('replace: replaceWithPeekWindow'), isFalse);
    expect(commitBody.contains('replace: true'), isTrue);
    expect(
      commitBody.contains('shouldPreserveFilledHistoryOverPeek'),
      isTrue,
    );
    expect(
      commitBody.contains('shouldRejectC2cPeekRestamp'),
      isTrue,
    );
    expect(
      source.contains('roaming_sync_reconcile_skip_official_sdk'),
      isTrue,
    );
    expect(
      source.contains('hydrate_keep_c2c_sdk_window'),
      isTrue,
    );

    final fillStart = source.indexOf('Future<void> _fillTowardOlderHistory(');
    expect(fillStart, greaterThanOrEqualTo(0));
    final fillExisting =
        source.indexOf('final existing = List<V2TimMessage>.from(', fillStart);
    expect(fillExisting, greaterThan(fillStart));
    final fillExistingBody = source.substring(fillExisting, fillExisting + 180);
    expect(fillExistingBody.contains('mergedAliasMessageList'), isTrue);
    expect(fillExistingBody.contains('messageListMap[convId]'), isFalse);

    final fillEnd = source.indexOf(
      'static String _historyMessageId(',
      fillStart,
    );
    expect(fillEnd, greaterThan(fillStart));
    final fillBody = source.substring(fillStart, fillEnd);
    expect(fillBody.contains('c2cOfficialOlderCursor'), isTrue);
    expect(fillBody.contains('loadOlderCloudOnlyResult'), isTrue);
    expect(
      source.contains('loadOlderCloudOnlyResult'),
      isTrue,
    );
    expect(fillBody.contains('_rememberC2cSdkOlderPage'), isTrue);
    final fillCommit = fillBody.indexOf('_commitHistoricalMessages(');
    final fillRemember = fillBody.indexOf('_rememberC2cSdkOlderPage');
    expect(fillCommit, greaterThanOrEqualTo(0));
    expect(fillRemember, greaterThan(fillCommit));
    expect(source.contains('mergeC2cOfficialOlderPage'), isTrue);
    expect(source.contains('usesOfficialSdkHistory'), isTrue);
    expect(fillBody.contains('shouldMergeC2cOlderPageByLastMsg'), isFalse);
    expect(fillBody.contains('mergedAliasMessageList(convId).length'), isTrue);

    final pagination = File(
      'third_party/tencent_cloud_chat_uikit/lib/business_logic/'
      'separate_models/tui_chat_history_pagination_load.dart',
    ).readAsStringSync();
    expect(pagination.contains('useC2cCloudOnly'), isTrue);
    expect(pagination.contains('c2cOfficialOlderCursor'), isTrue);
    expect(pagination.contains('mergeC2cOfficialOlderPage'), isTrue);
    expect(pagination.contains('load_chat_record_c2c_official_cursor'), isTrue);
    final paginationCommit = pagination.indexOf(
      'model.globalModel.setMessageList(',
    );
    final paginationRemember = pagination.indexOf(
      'model._rememberC2cSdkOlderPage(response.messageList)',
    );
    expect(paginationCommit, greaterThanOrEqualTo(0));
    expect(paginationRemember, greaterThan(paginationCommit));
    expect(
      pagination.substring(0, paginationCommit).contains(
            'model._rememberC2cSdkOlderPage(mergedMessages)',
          ),
      isFalse,
    );
    expect(
      pagination
          .contains('if (model.usesOfficialSdkHistory) {\n      return false;'),
      isTrue,
    );

    final bootstrap = File(
      'lib/src/services/chat_history_peek_bootstrap.dart',
    ).readAsStringSync();
    expect(bootstrap.contains('mergedAliasMessageList(key)'), isTrue);
    expect(bootstrap.contains('bootstrap_skip_c2c_filled_sdk'), isTrue);
    expect(bootstrap.contains('shouldRejectC2cPeekRestamp'), isTrue);

    final globalModel = File(
      'third_party/tencent_cloud_chat_uikit/lib/business_logic/'
      'view_models/tui_chat_global_model.dart',
    ).readAsStringSync();
    expect(globalModel.contains('c2c_reject_peek_restamp'), isTrue);
    expect(globalModel.contains('shouldRejectC2cPeekRestamp'), isTrue);
  });

  test('text send inserts local sending before createTextMessage', () {
    final source = File(
      'third_party/tencent_cloud_chat_uikit/lib/business_logic/'
      'separate_models/tui_chat_separate_view_model.dart',
    ).readAsStringSync();
    final start = source.indexOf(
      'Future<V2TimValueCallback<V2TimMessage>?> sendTextMessage(',
    );
    expect(start, greaterThanOrEqualTo(0));
    final end = source.indexOf(
      'Future<V2TimValueCallback<V2TimMessage>?>? sendMessageFromController(',
      start,
    );
    expect(end, greaterThan(start));
    final body = source.substring(start, end);
    expect(body.contains('_prependOptimisticTextPlaceholder'), isTrue);
    expect(body.contains('createTextMessage'), isTrue);
    expect(
      body.indexOf('_prependOptimisticTextPlaceholder'),
      lessThan(body.indexOf('createTextMessage')),
    );
    expect(body.contains('_adoptOptimisticOutgoingTextMessage'), isTrue);
    expect(source.contains('V2TIM_ELEM_TYPE_TEXT'), isTrue);

    final listSource = File(
      'third_party/tencent_cloud_chat_uikit/lib/ui/views/TIMUIKitChat/'
      'TIMUIKItMessageList/tim_uikit_chat_history_message_list.dart',
    ).readAsStringSync();
    expect(listSource.contains('outgoingTextInserted'), isTrue);
    expect(listSource.contains('outgoingNonTextAnimating'), isTrue);
    expect(
      listSource.contains(
        'if (wechatListPush) ...outgoingNonTextAnimating,',
      ),
      isTrue,
    );
    expect(
      listSource.contains(
        'if (wechatListPush) ...outgoingAnimatingMessages,',
      ),
      isFalse,
    );
  });

  test('prepend from stale window reloads newest then pins', () {
    final source = File(
      'third_party/tencent_cloud_chat_uikit/lib/business_logic/'
      'separate_models/tui_chat_separate_view_model.dart',
    ).readAsStringSync();
    final start =
        source.indexOf('void _prependOutgoingMessageForConversation(');
    expect(start, greaterThanOrEqualTo(0));
    final end = source.indexOf(
        'Future<V2TimValueCallback<V2TimMessage>?> sendTextAtMessage(');
    expect(end, greaterThan(start));
    final body = source.substring(start, end);
    expect(body.contains('haveMoreLatestData'), isTrue);
    expect(body.contains('reloadNewestMessageWindow'), isTrue);
  });
}
