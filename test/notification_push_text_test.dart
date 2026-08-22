import 'package:flutter_test/flutter_test.dart';
import 'package:tencent_cloud_chat_push/common/tim_push_message.dart';
import 'package:tencent_cloud_chat_sdk/enum/group_tips_elem_type.dart';
import 'package:tencent_cloud_chat_sdk/enum/message_elem_type.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_custom_elem.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_custom_elem.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_file_elem.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_file_elem.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_group_member_info.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_group_member_info.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_group_report_elem.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_group_report_elem.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_group_tips_elem.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_group_tips_elem.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_message.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_message.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_stream_elem.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_stream_elem.dart';
import 'package:tencent_cloud_chat_demo/src/models/notification_display_mode.dart';
import 'package:tencent_cloud_chat_demo/src/utils/notification_push_text.dart';
import 'package:tencent_cloud_chat_demo/utils/group_tips_message_helper.dart';

V2TimMessage _emptyMessageShell() {
  return V2TimMessage.fromJson(<String, dynamic>{
    'message_risk_type_identified': 0,
    'message_sender_group_member_info': <String, dynamic>{},
    'message_group_at_user_array': <String>[],
  });
}

V2TimMessage _messageFromParts({
  required int elemType,
  V2TimGroupTipsElem? groupTipsElem,
  V2TimGroupReportElem? groupReportElem,
  V2TimCustomElem? customElem,
  V2TimFileElem? fileElem,
  V2TimStreamElem? streamElem,
  String? groupID,
}) {
  final message = _emptyMessageShell();
  message.elemType = elemType;
  message.groupTipsElem = groupTipsElem;
  message.groupReportElem = groupReportElem;
  message.customElem = customElem;
  message.fileElem = fileElem;
  message.streamElem = streamElem;
  message.groupID = groupID;
  return message;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('NotificationPushText.summarizeMessage', () {
    test('maps group tips invite', () {
      final message = _messageFromParts(
        elemType: MessageElemType.V2TIM_ELEM_TYPE_GROUP_TIPS,
        groupID: 'g1',
        groupTipsElem: V2TimGroupTipsElem(
          groupID: 'g1',
          type: GroupTipsElemType.V2TIM_GROUP_TIPS_TYPE_INVITE,
          opMember: V2TimGroupMemberInfo(userID: 'owner', nickName: '群主'),
          memberList: [
            V2TimGroupMemberInfo(userID: 'u2', nickName: '新成员'),
          ],
        ),
      );

      final summary = NotificationPushText.summarizeMessage(message);
      expect(summary, contains('群主'));
      expect(summary, contains('新成员'));
      expect(summary, isNot('新消息'));
    });

    test('maps file name and stream markdown', () {
      final fileMessage = _messageFromParts(
        elemType: MessageElemType.V2TIM_ELEM_TYPE_FILE,
        fileElem: V2TimFileElem(fileName: 'report.pdf'),
      );
      expect(
        NotificationPushText.summarizeMessage(fileMessage),
        contains('report.pdf'),
      );

      final streamMessage = _messageFromParts(
        elemType: MessageElemType.V2TIM_ELEM_TYPE_STREAM,
        streamElem: V2TimStreamElem(markdown: 'Hello stream'),
      );
      expect(
        NotificationPushText.summarizeMessage(streamMessage),
        'Hello stream',
      );
    });

    test('delegates custom contact card to conversation preview', () {
      final message = _messageFromParts(
        elemType: MessageElemType.V2TIM_ELEM_TYPE_CUSTOM,
        customElem: V2TimCustomElem(
          data:
              '{"businessID":"contact_card","nickName":"Alice","userID":"alice"}',
        ),
      );

      expect(
        NotificationPushText.summarizeMessage(message),
        contains('Alice'),
      );
    });
  });

  group('GroupTipsMessageHelper.messagePreviewAbstract', () {
    test('maps group report delete', () {
      final report = V2TimGroupReportElem(
        type: V2TimGroupReportElem.kTIMGroupReport_Delete,
        groupID: 'g1',
        opUserID: 'owner',
      );
      report.opMemberInfo =
          V2TimGroupMemberInfo(userID: 'owner', nickName: '群主');
      final message = _messageFromParts(
        elemType: MessageElemType.V2TIM_ELEM_TYPE_GROUP_REPORT,
        groupReportElem: report,
      );

      final summary = GroupTipsMessageHelper.messagePreviewAbstract(message);
      expect(summary, isNotNull);
      expect(summary!, contains('群主'));
      expect(summary, contains('解散'));
    });
  });

  group('NotificationPushText.fromPush', () {
    test('maps contact card and platform notice from ext json', () {
      final contact = NotificationPushText.fromPush(
        TimPushMessage(
          ext:
              '{"businessID":"contact_card","nickName":"Bob","userID":"bob"}',
        ),
        mode: NotificationDisplayMode.full,
      );
      expect(contact.body, contains('Bob'));

      final notice = NotificationPushText.fromPush(
        TimPushMessage(
          ext:
              '{"businessID":"platform_wallet_notice","serviceName":"支付助手","title":"到账通知"}',
        ),
        mode: NotificationDisplayMode.full,
      );
      expect(notice.body, contains('支付助手'));
      expect(notice.body, contains('到账通知'));
    });
  });
}
