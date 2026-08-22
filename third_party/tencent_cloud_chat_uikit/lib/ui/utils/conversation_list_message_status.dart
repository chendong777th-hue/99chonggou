import 'package:tencent_cloud_chat_sdk/enum/message_status.dart';

/// 会话列表右上角发送中 / 已读勾：优先内存消息状态，没有暖窗则用 lastMessage 快照。
///
/// 只给图标子树用，不改会话行 fingerprint，避免整表刷新。
class ConversationListMessageStatus {
  ConversationListMessageStatus._();

  /// 自己发出的消息才查内存列表；对方消息仍用快照。
  static int resolve({
    required bool isSelf,
    required int lastMessageStatus,
    int? liveStatus,
  }) {
    if (!isSelf) {
      return lastMessageStatus;
    }
    return liveStatus ?? lastMessageStatus;
  }

  static bool showsFail(int status) {
    return status == MessageStatus.V2TIM_MSG_STATUS_SEND_FAIL;
  }

  static bool showsSending(int status) {
    return status == MessageStatus.V2TIM_MSG_STATUS_SENDING;
  }

  static bool showsReceipt({
    required bool isSelf,
    required int status,
  }) {
    return isSelf && status == MessageStatus.V2TIM_MSG_STATUS_SEND_SUCC;
  }
}
