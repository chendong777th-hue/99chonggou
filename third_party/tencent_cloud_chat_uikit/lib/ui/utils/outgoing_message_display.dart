import 'package:tencent_cloud_chat_sdk/enum/message_status.dart';

/// Shared rules for outgoing message meta (time + delivery check).
class OutgoingMessageDisplay {
  OutgoingMessageDisplay._();

  /// Delivery/read check is shown only after SDK reports send success.
  /// Client-side [msgID] or status `0` must not imply success.
  static bool shouldShowDeliveryCheck({required int status}) {
    return status == MessageStatus.V2TIM_MSG_STATUS_SEND_SUCC;
  }
}
