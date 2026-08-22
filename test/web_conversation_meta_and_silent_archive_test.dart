import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_local/web_conversation_meta_snapshot.dart';
import 'package:tencent_cloud_chat_demo/src/services/silent_archive_service.dart';
import 'package:tencent_cloud_chat_demo/src/utils/web_chat_open_policy.dart';
import 'package:tencent_cloud_chat_sdk/enum/message_elem_type.dart';
import 'package:tencent_cloud_chat_sdk/enum/message_status.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_message.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_message.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_text_elem.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_text_elem.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/view_models/tui_chat_global_model.dart';

void main() {
  group('WebConversationMetaSnapshot', () {
    test('roundtrips json maps', () {
      const snapshot = WebConversationMetaSnapshot(
        historyClearedAtMs: <String, int>{'c2c_user1': 1234567890000},
        readClearedAtMs: <String, int>{'group_g1': 987},
        readClearedLastMsgId: <String, String>{'c2c_user1': 'msg-1'},
      );
      final restored = WebConversationMetaSnapshot.fromJson(snapshot.toJson());
      expect(restored.historyClearedAtMs['c2c_user1'], 1234567890000);
      expect(restored.readClearedAtMs['group_g1'], 987);
      expect(restored.readClearedLastMsgId['c2c_user1'], 'msg-1');
    });

    test('fromJson ignores invalid entries', () {
      final restored = WebConversationMetaSnapshot.fromJson(<String, dynamic>{
        'historyClearedAtMs': <String, dynamic>{'a': 'bad', 'b': 2},
        'readClearedAtMs': null,
        'readClearedLastMsgId': <String, dynamic>{'x': ''},
      });
      expect(restored.historyClearedAtMs, <String, int>{'b': 2});
      expect(restored.readClearedAtMs, isEmpty);
      expect(restored.readClearedLastMsgId, isEmpty);
    });
  });

  group('SilentArchiveService.filterArchiveSupplement', () {
    V2TimMessage groupSdk({
      required String seq,
      required String msgID,
      bool isSelf = true,
      String sender = 'self_user',
      String? localCustomData,
    }) {
      final message = V2TimMessage.fromJson(<String, dynamic>{
        'message_server_time': 1750000000 + int.parse(seq),
        'message_msg_id': msgID,
        'message_seq': seq,
        'message_is_from_self': isSelf,
        'message_status': MessageStatus.V2TIM_MSG_STATUS_SEND_SUCC,
        'message_custom_str': localCustomData ?? '',
        'message_risk_type_identified': 0,
        'message_sender_group_member_info': <String, dynamic>{},
        'message_group_at_user_array': <String>[],
      });
      message.elemType = MessageElemType.V2TIM_ELEM_TYPE_TEXT;
      message.groupID = '@TGS#2BXXNKM5CS';
      message.seq = seq;
      message.msgID = msgID;
      message.timestamp = 1750000000 + int.parse(seq);
      message.isSelf = isSelf;
      message.sender = sender;
      message.status = MessageStatus.V2TIM_MSG_STATUS_SEND_SUCC;
      message.textElem = V2TimTextElem(text: ', , , ');
      message.localCustomData = localCustomData;
      return message;
    }

    V2TimMessage groupArchive({
      required String seq,
      bool isSelf = false,
      String sender = 'wrong_user',
    }) {
      return groupSdk(
        seq: seq,
        msgID: '@TGS#2BXXNKM5CS:$seq',
        isSelf: isSelf,
        sender: sender,
        localCustomData:
            jsonEncode(const <String, Object?>{'archiveHistory': true}),
      );
    }

    test('drops archive overlap already in existing window', () {
      const groupID = '@TGS#2BXXNKM5CS';
      final existing = <V2TimMessage>[
        groupSdk(seq: '42', msgID: '144115267812600597-1783162477-999'),
        groupSdk(seq: '41', msgID: '144115267812600597-1783162477-998'),
      ];
      final overlap = groupArchive(seq: '42');
      final older = groupArchive(seq: '40');

      final filtered = SilentArchiveService.filterArchiveSupplement(
        candidates: <V2TimMessage>[overlap, older],
        existing: existing,
        oldestAnchor: existing.last,
      );

      expect(filtered, hasLength(1));
      expect(filtered.single.seq, '40');
      expect(groupID, isNotEmpty);
    });

    test('dedupe keeps archive source of truth for the same group seq', () {
      final archive = groupArchive(seq: '42', isSelf: false, sender: 'wrong');
      final sdk = groupSdk(
        seq: '42',
        msgID: '144115267812600597-1783162477-999',
        isSelf: true,
        sender: 'self_user',
      );

      final deduped = TUIChatGlobalModel.dedupeMessagesForTesting(
        <V2TimMessage>[archive, sdk],
      );

      expect(deduped, hasLength(1));
      expect(deduped.single.isSelf, isFalse);
      expect(deduped.single.msgID, archive.msgID);
    });
  });

  group('WebChatOpenPolicy silent archive', () {
    test('UIKit history path never schedules the app archive supplement', () {
      expect(
        WebChatOpenPolicy.shouldScheduleSilentInitialArchive(
          isInitialWindow: true,
          sdkMessageCount: 0,
          requestedCount: 40,
        ),
        isFalse,
      );
      expect(
        WebChatOpenPolicy.shouldScheduleSilentInitialArchive(
          isInitialWindow: true,
          sdkMessageCount: 15,
          requestedCount: 40,
        ),
        isFalse,
      );
      expect(
        WebChatOpenPolicy.shouldScheduleSilentInitialArchive(
          isInitialWindow: true,
          sdkMessageCount: 40,
          requestedCount: 40,
        ),
        isFalse,
      );
      expect(
        WebChatOpenPolicy.shouldScheduleSilentInitialArchive(
          isInitialWindow: false,
          sdkMessageCount: 5,
          requestedCount: 40,
        ),
        isFalse,
      );
    });
  });
}
