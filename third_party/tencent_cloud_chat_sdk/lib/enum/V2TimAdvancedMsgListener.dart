// void 	onRecvNewMessage (V2TIMMessage msg)

// void 	onRecvC2CReadReceipt (List< V2TIMMessageReceipt > receiptList)

// ignore_for_file: file_names, prefer_function_declarations_over_variables

// void 	onRecvMessageRevoked (String msgID)
//
import 'package:tencent_cloud_chat_sdk/models/v2_tim_group_member_info.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_group_member_info.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_message.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_message.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_message_download_progress.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_message_download_progress.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_message_extension.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_message_extension.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_message_reaction_change_info.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_message_reaction_change_info.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_message_receipt.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_message_receipt.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_user_full_info.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_user_full_info.dart';

import 'callbacks.dart';

class V2TimAdvancedMsgListener {
  OnRecvNewMessageCallback onRecvNewMessage = (
    V2TimMessage message,
  ) {};
  OnRecvMessageModified onRecvMessageModified = (
    V2TimMessage message,
  ) {};
  OnSendMessageProgressCallback onSendMessageProgress = (
    V2TimMessage message,
    int progress,
  ) {};
  OnRecvC2CReadReceiptCallback onRecvC2CReadReceipt = (
    List<V2TimMessageReceipt> receiptList,
  ) {};
  OnRecvMessageRevokedCallback onRecvMessageRevoked = (
    String msgID,
  ) {};
  OnRecvMessageReadReceipts onRecvMessageReadReceipts = (
    List<V2TimMessageReceipt> receiptList,
  ) {};
  OnRecvMessageExtensionsChanged onRecvMessageExtensionsChanged = (
    String msgID,
    List<V2TimMessageExtension> extensions,
  ) {};
  OnRecvMessageExtensionsDeleted onRecvMessageExtensionsDeleted = (
    String msgID,
    List<String> extensionKeys,
  ) {};
  OnMessageDownloadProgressCallback onMessageDownloadProgressCallback = (
    V2TimMessageDownloadProgress messageDownloadProgress,
  ) {};
  OnRecvMessageReactionsChanged onRecvMessageReactionsChanged =
      (List<V2TIMMessageReactionChangeInfo> changeInfos) {};

  OnRecvMessageRevoked onRecvMessageRevokedWithInfo =
      (String msgID, V2TimUserFullInfo operateUser, String reason) {};

  OnGroupMessagePinned onGroupMessagePinned = (String groupID,
      V2TimMessage message, bool isPinned, V2TimGroupMemberInfo opUser) {};

  V2TimAdvancedMsgListener({
    OnRecvC2CReadReceiptCallback? onRecvC2CReadReceipt,
    OnRecvMessageRevokedCallback? onRecvMessageRevoked,
    OnRecvNewMessageCallback? onRecvNewMessage,
    OnSendMessageProgressCallback? onSendMessageProgress,
    OnRecvMessageModified? onRecvMessageModified,
    OnRecvMessageReadReceipts? onRecvMessageReadReceipts,
    OnRecvMessageExtensionsChanged? onRecvMessageExtensionsChanged,
    OnRecvMessageExtensionsDeleted? onRecvMessageExtensionsDeleted,
    OnMessageDownloadProgressCallback? onMessageDownloadProgressCallback,
    OnRecvMessageReactionsChanged? onRecvMessageReactionsChanged,
    OnRecvMessageRevoked? onRecvMessageRevokedWithInfo,
    OnGroupMessagePinned? onGroupMessagePinned,
  }) {
    if (onRecvMessageRevokedWithInfo != null) {
      this.onRecvMessageRevokedWithInfo = onRecvMessageRevokedWithInfo;
    }
    if (onRecvMessageReactionsChanged != null) {
      this.onRecvMessageReactionsChanged = onRecvMessageReactionsChanged;
    }
    if (onRecvC2CReadReceipt != null) {
      this.onRecvC2CReadReceipt = onRecvC2CReadReceipt;
    }
    if (onRecvMessageRevoked != null) {
      this.onRecvMessageRevoked = onRecvMessageRevoked;
    }
    if (onRecvNewMessage != null) {
      this.onRecvNewMessage = onRecvNewMessage;
    }
    if (onSendMessageProgress != null) {
      this.onSendMessageProgress = onSendMessageProgress;
    }
    if (onRecvMessageModified != null) {
      this.onRecvMessageModified = onRecvMessageModified;
    }
    if (onRecvMessageReadReceipts != null) {
      this.onRecvMessageReadReceipts = onRecvMessageReadReceipts;
    }
    if (onRecvMessageExtensionsChanged != null) {
      this.onRecvMessageExtensionsChanged = onRecvMessageExtensionsChanged;
    }
    if (onRecvMessageExtensionsDeleted != null) {
      this.onRecvMessageExtensionsDeleted = onRecvMessageExtensionsDeleted;
    }
    if (onMessageDownloadProgressCallback != null) {
      this.onMessageDownloadProgressCallback =
          onMessageDownloadProgressCallback;
    }
    if (onGroupMessagePinned != null) {
      this.onGroupMessagePinned = onGroupMessagePinned;
    }
  }
}
