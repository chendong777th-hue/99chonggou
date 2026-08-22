import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tencent_cloud_chat_sdk/enum/message_elem_type.dart';
import 'package:tencent_cloud_chat_sdk/enum/message_status.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_message.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_message.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/separate_models/tui_chat_separate_view_model.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/view_models/tui_chat_global_model.dart';
import 'package:tencent_cloud_chat_uikit/data_services/services_locatar.dart';

V2TimMessage _textMessage(String msgID) {
  final message = V2TimMessage.fromJson(<String, dynamic>{
    'message_server_time': 1700000000,
    'message_msg_id': msgID,
    'message_rand': 1,
    'message_is_from_self': false,
    'message_status': MessageStatus.V2TIM_MSG_STATUS_SEND_SUCC,
    'message_custom_str': '',
    'message_risk_type_identified': 0,
    'message_sender_group_member_info': <String, dynamic>{},
    'message_group_at_user_array': <String>[],
  });
  message.elemType = MessageElemType.V2TIM_ELEM_TYPE_TEXT;
  message.id = msgID;
  message.status = MessageStatus.V2TIM_MSG_STATUS_SEND_SUCC;
  return message;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    setupServiceLocator();
  });

  group('TUIChatGlobalModel.isSameConversationIdForHistory', () {
    test('strips c2c_ / group_ prefixes', () {
      expect(
        TUIChatGlobalModel.isSameConversationIdForHistory(
          'c2c_usera',
          'usera',
        ),
        isTrue,
      );
      expect(
        TUIChatGlobalModel.isSameConversationIdForHistory(
          'group_@TGS#abc',
          '@TGS#abc',
        ),
        isTrue,
      );
    });

    test('community short code matches full TGS form', () {
      expect(
        TUIChatGlobalModel.isSameConversationIdForHistory(
          '@TGS#_@TGS#short1',
          'short1',
        ),
        isTrue,
      );
    });

    test('different peers do not match', () {
      expect(
        TUIChatGlobalModel.isSameConversationIdForHistory('usera', 'userb'),
        isFalse,
      );
    });
  });

  group('hydrateKeepEmptyRejectReason', () {
    test('allows keep-empty when no alias / preview / grace', () {
      expect(
        TUIChatSeparateViewModel.hydrateKeepEmptyRejectReason(
          warmCountBare: 0,
          warmCountGroup: 0,
          hasNonTipPreviewEvidence: false,
          inClearGrace: false,
        ),
        isNull,
      );
    });

    test('rejects when alias bucket has messages', () {
      expect(
        TUIChatSeparateViewModel.hydrateKeepEmptyRejectReason(
          warmCountBare: 3,
          warmCountGroup: 0,
          hasNonTipPreviewEvidence: false,
          inClearGrace: false,
        ),
        'alias_nonzero',
      );
      expect(
        TUIChatSeparateViewModel.hydrateKeepEmptyRejectReason(
          warmCountBare: 0,
          warmCountGroup: 2,
          hasNonTipPreviewEvidence: false,
          inClearGrace: false,
        ),
        'alias_nonzero',
      );
    });

    test('rejects when list preview has non-tip evidence', () {
      expect(
        TUIChatSeparateViewModel.hydrateKeepEmptyRejectReason(
          warmCountBare: 0,
          warmCountGroup: 0,
          hasNonTipPreviewEvidence: true,
          inClearGrace: false,
        ),
        'preview_evidence',
      );
    });

    test('rejects during history-clear grace', () {
      expect(
        TUIChatSeparateViewModel.hydrateKeepEmptyRejectReason(
          warmCountBare: 0,
          warmCountGroup: 0,
          hasNonTipPreviewEvidence: false,
          inClearGrace: true,
        ),
        'clear_grace',
      );
    });
  });

  group('selectedConversationMatchesChatId', () {
    test('matches group_ conversationID to bare chat id', () {
      expect(
        TUIChatSeparateViewModel.selectedConversationMatchesChatId(
          conversationID: '@TGS#room1',
          selectedConversationID: 'group_@TGS#room1',
        ),
        isTrue,
      );
    });

    test('matches selected groupID to bare chat id', () {
      expect(
        TUIChatSeparateViewModel.selectedConversationMatchesChatId(
          conversationID: '@TGS#room1',
          selectedGroupID: '@TGS#room1',
        ),
        isTrue,
      );
    });

    test('matches c2c_ conversationID to bare user id', () {
      expect(
        TUIChatSeparateViewModel.selectedConversationMatchesChatId(
          conversationID: 'peer_42',
          selectedUserID: 'peer_42',
          selectedConversationID: 'c2c_peer_42',
        ),
        isTrue,
      );
    });

    test('rejects unrelated conversation', () {
      expect(
        TUIChatSeparateViewModel.selectedConversationMatchesChatId(
          conversationID: '@TGS#room1',
          selectedConversationID: 'group_@TGS#other',
          selectedGroupID: '@TGS#other',
        ),
        isFalse,
      );
    });
  });

  group('init alias migrate window (storage write)', () {
    test('copying raw alias window onto storage key fills warm count', () {
      final model = serviceLocator<TUIChatGlobalModel>();
      const rawKey = 'group_@TGS#migrate_gate';
      const storageKey = '@TGS#migrate_gate';
      model.removeMessageList(rawKey);
      model.removeMessageList(storageKey);

      model.setMessageList(
        rawKey,
        <V2TimMessage>[_textMessage('m_migrate_1'), _textMessage('m_migrate_2')],
        needResetNewMessageCount: false,
        replace: true,
      );
      // group_ 前缀与裸 TGS 同一群桶：写入落在 canonical storage key。
      expect(model.messageListMap[storageKey]?.length, 2);

      model.markInitialHistoryLoaded(storageKey);

      expect(model.messageListMap[storageKey]?.length, 2);
      expect(model.hasInitialHistoryLoaded(storageKey), isTrue);

      model.removeMessageList(rawKey);
      model.removeMessageList(storageKey);
    });
  });
}
