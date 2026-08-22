import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tencent_cloud_chat_demo/src/utils/conversation_preview_history_sync.dart';
import 'package:tencent_cloud_chat_sdk/enum/message_elem_type.dart';
import 'package:tencent_cloud_chat_sdk/enum/message_status.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_message.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_message.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_text_elem.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_text_elem.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/view_models/tui_chat_global_model.dart';
import 'package:tencent_cloud_chat_uikit/data_services/services_locatar.dart';

ConversationMessageRef _ref({
  String? msgID,
  String? id,
  int? timestamp,
}) {
  return ConversationMessageRef(
    msgID: msgID,
    id: id,
    timestamp: timestamp,
  );
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
      final cached = [
        _ref(msgID: 'm1', timestamp: 100),
      ];
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
      final cached = [
        _ref(msgID: 'm1', timestamp: 100),
      ];
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
      final cached = [
        _ref(msgID: 'm1', timestamp: 100),
      ];
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
