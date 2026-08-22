import 'package:tencent_cloud_chat_sdk/enum/message_status.dart';

class MessageStatusWeb {
  static int convertMessageStatus(dynamic message) {
    final String status = message["status"];
    final bool isRevoked = message["isRevoked"];
    final bool isDeleted = message["isDeleted"];

    if (isDeleted) {
      return MessageStatus.V2TIM_MSG_STATUS_HAS_DELETED;
    }

    if (isRevoked) {
      return MessageStatus.V2TIM_MSG_STATUS_LOCAL_REVOKED;
    }

    if (status == 'success') {
      return MessageStatus.V2TIM_MSG_STATUS_SEND_SUCC;
    }

    if (status == 'fail') {
      return MessageStatus.V2TIM_MSG_STATUS_SEND_FAIL;
    }

    return 0;
  }
}
