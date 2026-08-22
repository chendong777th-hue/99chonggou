// ignore_for_file: non_constant_identifier_names
@JS()
library js_interop;

import 'package:js/js.dart'; // Pull in our dependency

import 'package:tencent_cloud_chat_sdk/web/utils/utils.dart';

@JS("TencentCloudChat")
class GroupRecvMsgEnum {
  external static dynamic TYPES; // 这个是用作枚举的
}

class GroupRecvMsgOpt {
  static String MSG_REMIND_ACPT_AND_NOTE = checkEmptyEnum(
      () => jsToMap(GroupRecvMsgEnum.TYPES)["MSG_REMIND_ACPT_AND_NOTE"],
      "AcceptAndNotify");
  static String MSG_REMIND_ACPT_NOT_NOTE = checkEmptyEnum(
      () => jsToMap(GroupRecvMsgEnum.TYPES)["MSG_REMIND_ACPT_NOT_NOTE"],
      "AcceptNotNotify");
  static String MSG_REMIND_DISCARD = checkEmptyEnum(
      () => jsToMap(GroupRecvMsgEnum.TYPES)["MSG_REMIND_DISCARD"], "Discard");

  static int convertMsgRecvOpt(String opt) {
    if (opt == MSG_REMIND_ACPT_AND_NOTE) {
      return 0;
    }

    if (opt == MSG_REMIND_DISCARD) {
      return 1;
    }

    if (opt == MSG_REMIND_ACPT_NOT_NOTE) {
      return 2;
    }
    return 0;
  }

  static String? convertMsgRecvOptToWeb(int opt) {
    if (opt == 0) {
      return MSG_REMIND_ACPT_AND_NOTE;
    }

    if (opt == 1) {
      return MSG_REMIND_DISCARD;
    }

    if (opt == 2) {
      return MSG_REMIND_ACPT_NOT_NOTE;
    }
    return null;
  }
}
