import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tencent_cloud_chat_demo/src/services/chat_history_peek_bootstrap.dart';
import 'package:tencent_cloud_chat_demo/src/utils/conversation_preview_history_sync.dart';
import 'package:tencent_cloud_chat_sdk/enum/message_elem_type.dart';
import 'package:tencent_cloud_chat_sdk/enum/message_status.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_message.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_message.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_text_elem.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_text_elem.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/view_models/tui_chat_global_model.dart';
import 'package:tencent_cloud_chat_uikit/data_services/services_locatar.dart';

ConversationMessageRef _ref({String? msgID, String? id, int? timestamp}) {
  return ConversationMessageRef(msgID: msgID, id: id, timestamp: timestamp);
}

V2TimMessage _message({
  String? msgID,
  String? id,
  bool isSelf = false,
  int? random,
  int? status,
  int? timestamp,
  String? text,
  String? sender,
  String? userID,
  String? localCustomData,
}) {
  final message = V2TimMessage.fromJson(<String, dynamic>{
    'message_server_time': timestamp ?? 1700000000,
    'message_msg_id': msgID,
    'message_rand': random,
    'message_is_from_self': isSelf,
    'message_status': status ?? MessageStatus.V2TIM_MSG_STATUS_SEND_SUCC,
    'message_custom_str': localCustomData ?? '',
    'message_risk_type_identified': 0,
    'message_sender_group_member_info': <String, dynamic>{},
    'message_group_at_user_array': <String>[],
  });
  message.elemType = MessageElemType.V2TIM_ELEM_TYPE_TEXT;
  message.id = id;
  message.status = status ?? MessageStatus.V2TIM_MSG_STATUS_SEND_SUCC;
  if (timestamp != null) {
    message.timestamp = timestamp;
  }
  if (text != null) {
    message.textElem = V2TimTextElem(text: text);
  }
  message.sender = sender;
  message.userID = userID;
  return message;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    setupServiceLocator();
  });

  group('ConversationPreviewHistorySync.isPreviewAheadOfCachedRefs', () {
    test('preview msgID already in cached head is not ahead', () {
      final cached = [
        _ref(msgID: 'm1', timestamp: 100),
        _ref(msgID: 'm0', timestamp: 90),
      ];
      final preview = _ref(msgID: 'm1', timestamp: 100);
      expect(
        ConversationPreviewHistorySync.isPreviewAheadOfCachedRefs(
          preview: preview,
          cached: cached,
        ),
        isFalse,
      );
    });

    test('preview with newer timestamp is ahead', () {
      final cached = [_ref(msgID: 'm1', timestamp: 100)];
      final preview = _ref(msgID: 'm2', timestamp: 200);
      expect(
        ConversationPreviewHistorySync.isPreviewAheadOfCachedRefs(
          preview: preview,
          cached: cached,
        ),
        isTrue,
      );
    });

    test('preview with non-empty value is ahead when cache empty', () {
      final preview = _ref(msgID: 'm1', timestamp: 100);
      expect(
        ConversationPreviewHistorySync.isPreviewAheadOfCachedRefs(
          preview: preview,
          cached: const <ConversationMessageRef>[],
        ),
        isTrue,
      );
    });

    test('same timestamp but different msgID is ahead', () {
      final cached = [_ref(msgID: 'm1', timestamp: 100)];
      final preview = _ref(msgID: 'm2', timestamp: 100);
      expect(
        ConversationPreviewHistorySync.isPreviewAheadOfCachedRefs(
          preview: preview,
          cached: cached,
        ),
        isTrue,
      );
    });

    test('null preview is not ahead', () {
      final cached = [_ref(msgID: 'm1', timestamp: 100)];
      expect(
        ConversationPreviewHistorySync.isPreviewAheadOfCachedRefs(
          preview: null,
          cached: cached,
        ),
        isFalse,
      );
    });
  });

  group('ConversationPreviewHistorySync open rebootstrap tip check', () {
    // canSkipOpenRebootstrap 依赖 globalModel；此处覆盖其 tip 对齐核心。
    test('non-empty cache with aligned tip is not ahead', () {
      final cached = <V2TimMessage>[
        _message(msgID: 'm1', timestamp: 100),
        _message(msgID: 'm0', timestamp: 90),
      ];
      expect(
        ConversationPreviewHistorySync.isPreviewAheadOfCachedHistory(
          preview: _message(msgID: 'm1', timestamp: 100),
          cached: cached,
        ),
        isFalse,
      );
    });

    test('empty cache with preview is ahead (must rebootstrap)', () {
      expect(
        ConversationPreviewHistorySync.isPreviewAheadOfCachedHistory(
          preview: _message(msgID: 'm1', timestamp: 100),
          cached: const <V2TimMessage>[],
        ),
        isTrue,
      );
    });

    test('preview tip missing from list is ahead even if ts <= head', () {
      final cached = <V2TimMessage>[
        _message(msgID: '0', timestamp: 200, isSelf: true),
        _message(msgID: 'older', timestamp: 100),
      ];
      expect(
        ConversationPreviewHistorySync.isPreviewAheadOfCachedHistory(
          preview: _message(msgID: '11111', timestamp: 200, isSelf: true),
          cached: cached,
        ),
        isTrue,
      );
      expect(
        ConversationPreviewHistorySync.isPreviewAheadOfCachedHistory(
          preview: _message(msgID: '11111', timestamp: 150, isSelf: true),
          cached: cached,
        ),
        isTrue,
      );
      expect(
        ConversationPreviewHistorySync.isPreviewAheadOfCachedRefs(
          preview: _ref(msgID: '11111', timestamp: 150),
          cached: <ConversationMessageRef>[
            _ref(msgID: '0', timestamp: 200),
          ],
        ),
        isTrue,
      );
    });

    test('splice puts missing self lastMessage on newest end', () {
      final cached = <V2TimMessage>[
        _message(msgID: '0', timestamp: 100, isSelf: true),
      ];
      final last = _message(msgID: '11111', timestamp: 200, isSelf: true);
      final spliced = ChatHistoryPeekBootstrap.spliceSelfLastMessageIfMissing(
        last: last,
        messages: cached,
      );
      expect(spliced.first.msgID, '11111');
      expect(spliced.length, 2);
    });

    test('splice does not insert peer lastMessage over newer self', () {
      final cached = <V2TimMessage>[
        _message(msgID: 'mine', timestamp: 200, isSelf: true),
      ];
      final last = _message(msgID: 'peer-tip', timestamp: 150, isSelf: false);
      final spliced = ChatHistoryPeekBootstrap.spliceSelfLastMessageIfMissing(
        last: last,
        messages: cached,
      );
      expect(spliced, same(cached));
    });

    test('same-second distinct SDK tips are ahead when msgID differs', () {
      final cached = <V2TimMessage>[
        _message(
          msgID: '144115250268987090-1787389302-2245723238',
          timestamp: 200,
          isSelf: true,
          text: '9',
        ),
      ];
      expect(
        ConversationPreviewHistorySync.isPreviewAheadOfCachedHistory(
          preview: _message(
            msgID: '144115250268987090-1787389303-2245723239',
            timestamp: 200,
            isSelf: true,
            text: '0',
          ),
          cached: cached,
        ),
        isTrue,
      );
      expect(
        ConversationPreviewHistorySync.isPreviewAheadOfCachedHistory(
          preview: _message(
            msgID: '144115250268987090-1787389302-2245723238',
            timestamp: 200,
            isSelf: true,
            text: '9',
          ),
          cached: cached,
        ),
        isFalse,
      );
    });

    test('same timestamp correlating content is not ahead', () {
      const ts = 100;
      const peer = 'peer_user';
      const self = 'self_user';
      final cached = <V2TimMessage>[
        _message(
          msgID: '144115267812600597-1783162477-180902858',
          timestamp: ts,
          isSelf: true,
          text: '不用管',
          sender: self,
          userID: peer,
        ),
      ];
      final preview = _message(
        msgID: 'archive-msg-key-001',
        timestamp: ts,
        isSelf: false,
        text: '不用管',
        sender: self,
        userID: peer,
        localCustomData: '{"archiveHistory":true}',
      );
      expect(
        ConversationPreviewHistorySync.isPreviewAheadOfCachedHistory(
          preview: preview,
          cached: cached,
        ),
        isFalse,
      );
    });
  });

  test('prepared window reuse requires bottom idle and aligned preview', () {
    final model = serviceLocator<TUIChatGlobalModel>();
    const conversationID = 'prepared_window_policy_test';
    addTearDown(() => model.removeMessageList(conversationID));
    final cached = <V2TimMessage>[
      _message(msgID: 'm2', timestamp: 200),
      _message(msgID: 'm1', timestamp: 100),
    ];
    model.setMessageList(
      conversationID,
      cached,
      needResetNewMessageCount: false,
      replace: true,
    );
    model.setMessageListPosition(
      conversationID,
      HistoryMessagePosition.bottom,
      notify: false,
    );
    model.clearSearchJumpStatus(conversationID);
    model.markInitialHistoryLoaded(conversationID);
    model.markInitialHistoryMayHaveOlder(conversationID, mayHaveOlder: false);

    expect(
      ConversationPreviewHistorySync.canReusePreparedInitialWindow(
        globalModel: model,
        conversationKey: conversationID,
        preview: cached.first,
      ),
      isTrue,
    );

    model.setMessageListPosition(
      conversationID,
      HistoryMessagePosition.notShowLatest,
      notify: false,
    );
    expect(
      ConversationPreviewHistorySync.canReusePreparedInitialWindow(
        globalModel: model,
        conversationKey: conversationID,
        preview: cached.first,
      ),
      isFalse,
    );

    model.setMessageListPosition(
      conversationID,
      HistoryMessagePosition.bottom,
      notify: false,
    );
    model.setSearchJumpStatus(conversationID, SearchJumpStatus.loading);
    expect(
      ConversationPreviewHistorySync.canReusePreparedInitialWindow(
        globalModel: model,
        conversationKey: conversationID,
        preview: cached.first,
      ),
      isFalse,
    );

    model.clearSearchJumpStatus(conversationID);
    expect(
      ConversationPreviewHistorySync.canReusePreparedInitialWindow(
        globalModel: model,
        conversationKey: conversationID,
        preview: _message(msgID: 'm3', timestamp: 300),
      ),
      isFalse,
    );
  });

  test('aligned provisional short window must not skip cloud bootstrap', () {
    final model = serviceLocator<TUIChatGlobalModel>();
    const conversationID = 'provisional_short_window_test';
    addTearDown(() => model.removeMessageList(conversationID));
    final cached = <V2TimMessage>[
      _message(msgID: 'm2', timestamp: 200),
      _message(msgID: 'm1', timestamp: 100),
    ];
    model.setMessageList(
      conversationID,
      cached,
      needResetNewMessageCount: false,
      replace: true,
    );
    model.setMessageListPosition(
      conversationID,
      HistoryMessagePosition.bottom,
      notify: false,
    );
    model.clearSearchJumpStatus(conversationID);
    model.markInitialHistoryMayHaveOlder(conversationID, mayHaveOlder: true);

    expect(model.hasInitialHistoryLoaded(conversationID), isFalse);
    expect(
      ConversationPreviewHistorySync.canSkipOpenRebootstrap(
        globalModel: model,
        conversationKey: conversationID,
        preview: cached.first,
      ),
      isFalse,
    );
    expect(
      ConversationPreviewHistorySync.canReusePreparedInitialWindow(
        globalModel: model,
        conversationKey: conversationID,
        preview: cached.first,
      ),
      isFalse,
    );
  });

  test('loaded but underfilled window must not skip cloud bootstrap', () {
    final model = serviceLocator<TUIChatGlobalModel>();
    const conversationID = 'loaded_underfilled_window_test';
    addTearDown(() => model.removeMessageList(conversationID));
    final cached = <V2TimMessage>[
      _message(msgID: 'm2', timestamp: 200),
      _message(msgID: 'm1', timestamp: 100),
    ];
    model.setMessageList(
      conversationID,
      cached,
      needResetNewMessageCount: false,
      replace: true,
    );
    model.setMessageListPosition(
      conversationID,
      HistoryMessagePosition.bottom,
      notify: false,
    );
    model.clearSearchJumpStatus(conversationID);
    model.markInitialHistoryLoaded(conversationID);
    model.markInitialHistoryMayHaveOlder(conversationID, mayHaveOlder: true);

    expect(
      ConversationPreviewHistorySync.isCompleteOpenHistoryWindow(
        globalModel: model,
        conversationKey: conversationID,
      ),
      isFalse,
    );
    expect(
      ConversationPreviewHistorySync.canSkipOpenRebootstrap(
        globalModel: model,
        conversationKey: conversationID,
        preview: cached.first,
      ),
      isFalse,
    );
    expect(
      ConversationPreviewHistorySync.canReusePreparedInitialWindow(
        globalModel: model,
        conversationKey: conversationID,
        preview: cached.first,
      ),
      isFalse,
    );
  });

  test(
    'provisional refresh clears stale loaded flag but keeps window state',
    () {
      final model = serviceLocator<TUIChatGlobalModel>();
      const conversationID = 'provisional_refresh_loaded_flag_test';
      addTearDown(() => model.removeMessageList(conversationID));
      final cached = <V2TimMessage>[
        _message(msgID: 'm2', timestamp: 200),
        _message(msgID: 'm1', timestamp: 100),
      ];
      model.setMessageList(
        conversationID,
        cached,
        needResetNewMessageCount: false,
        replace: true,
      );
      model.setMessageListPosition(
        conversationID,
        HistoryMessagePosition.bottom,
        notify: false,
      );
      model.markInitialHistoryLoaded(conversationID);
      model.markInitialHistoryMayHaveOlder(conversationID, mayHaveOlder: true);

      model.clearInitialHistoryLoaded(conversationID);

      expect(model.hasInitialHistoryLoaded(conversationID), isFalse);
      expect(
        model.rawMessageList(conversationID)?.map((message) => message.msgID),
        <String?>['m2', 'm1'],
      );
      expect(model.mayHaveOlderHistory(conversationID), isTrue);
      expect(
        model.getMessageListPosition(conversationID),
        HistoryMessagePosition.bottom,
      );
    },
  );

  test('validated exhausted two-message window remains reusable', () {
    final model = serviceLocator<TUIChatGlobalModel>();
    const conversationID = 'validated_short_window_test';
    addTearDown(() => model.removeMessageList(conversationID));
    final cached = <V2TimMessage>[
      _message(msgID: 'm2', timestamp: 200),
      _message(msgID: 'm1', timestamp: 100),
    ];
    model.setMessageList(
      conversationID,
      cached,
      needResetNewMessageCount: false,
      replace: true,
    );
    model.setMessageListPosition(
      conversationID,
      HistoryMessagePosition.bottom,
      notify: false,
    );
    model.clearSearchJumpStatus(conversationID);
    model.markInitialHistoryLoaded(conversationID);
    model.markInitialHistoryMayHaveOlder(conversationID, mayHaveOlder: false);

    expect(
      ConversationPreviewHistorySync.canSkipOpenRebootstrap(
        globalModel: model,
        conversationKey: conversationID,
        preview: cached.first,
      ),
      isTrue,
    );
    expect(
      ConversationPreviewHistorySync.canReusePreparedInitialWindow(
        globalModel: model,
        conversationKey: conversationID,
        preview: cached.first,
      ),
      isTrue,
    );
    expect(model.mayHaveOlderHistory(conversationID), isFalse);
  });

  group('ConversationPreviewHistorySync synthetic local anchors', () {
    test('detects local group tip anchor ids', () {
      expect(
        ConversationPreviewHistorySync.isSyntheticLocalAnchorId(
          'local_gt_@TGS#2BXXNKM5CS_1782011772_447098142',
        ),
        isTrue,
      );
      expect(
        ConversationPreviewHistorySync.isSyntheticLocalAnchorId(
          '144115267812600597-1782011856-460697940',
        ),
        isFalse,
      );
    });
  });

  group('ConversationPreviewHistorySync.isSameMessage', () {
    test('cross msgID and id match', () {
      final a = _message(msgID: 'S1');
      final b = _message(id: 'S1');
      expect(ConversationPreviewHistorySync.isSameMessage(a, b), isTrue);
    });

    test('cross id and msgID match', () {
      final a = _message(id: 'C1');
      final b = _message(msgID: 'C1');
      expect(ConversationPreviewHistorySync.isSameMessage(a, b), isTrue);
    });

    test('unrelated messages do not match', () {
      final a = _message(msgID: 'A1');
      final b = _message(msgID: 'B2');
      expect(ConversationPreviewHistorySync.isSameMessage(a, b), isFalse);
    });

    test('outgoing placeholder correlates with resolved copy', () {
      final placeholder = _message(
        isSelf: true,
        id: 'client_a',
        random: 42,
        status: MessageStatus.V2TIM_MSG_STATUS_SENDING,
      );
      final resolved = _message(
        isSelf: true,
        id: 'client_a',
        msgID: 'server_a',
        random: 42,
        status: MessageStatus.V2TIM_MSG_STATUS_SEND_SUCC,
      );
      expect(
        ConversationPreviewHistorySync.isSameMessage(placeholder, resolved),
        isTrue,
      );
    });
  });
}
