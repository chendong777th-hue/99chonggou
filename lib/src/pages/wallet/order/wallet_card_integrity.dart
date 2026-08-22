import 'package:tencent_cloud_chat_demo/utils/chat_id_format.dart';

enum WalletCardInvalidReason {
  none,
  notFound,
  senderMismatch,
  conversationMismatch,
}

/// REST 订单与 IM 消息是否匹配。金额/状态以 REST 为准，这里只判无效卡。
class WalletCardIntegrity {
  const WalletCardIntegrity._();

  static bool isNotFoundOrForbiddenStatus(int? statusCode) {
    return statusCode == 401 || statusCode == 403 || statusCode == 404;
  }

  static WalletCardInvalidReason evaluate({
    int? httpStatus,
    String restSenderUserId = '',
    String messageSender = '',
    String restGroupId = '',
    String messageGroupId = '',
    bool isGroupMessage = false,
  }) {
    if (isNotFoundOrForbiddenStatus(httpStatus)) {
      return WalletCardInvalidReason.notFound;
    }

    final restSender = ChatIdFormat.rawUserUid(restSenderUserId).toLowerCase();
    final fromAccount = ChatIdFormat.rawUserUid(messageSender).toLowerCase();
    if (restSender.isNotEmpty &&
        fromAccount.isNotEmpty &&
        restSender != fromAccount) {
      return WalletCardInvalidReason.senderMismatch;
    }

    final restGroup = restGroupId.trim();
    final messageGroup = messageGroupId.trim();
    if (isGroupMessage) {
      if (restGroup.isNotEmpty &&
          messageGroup.isNotEmpty &&
          !ChatIdFormat.groupIdsEquivalent(restGroup, messageGroup)) {
        return WalletCardInvalidReason.conversationMismatch;
      }
      return WalletCardInvalidReason.none;
    }

    if (restGroup.isNotEmpty) {
      return WalletCardInvalidReason.conversationMismatch;
    }
    return WalletCardInvalidReason.none;
  }
}
