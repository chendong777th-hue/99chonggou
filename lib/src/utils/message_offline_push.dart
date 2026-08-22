import 'dart:convert';

import 'package:tencent_cloud_chat_demo/config.dart';
import 'package:tencent_cloud_chat_demo/src/utils/notification_push_text.dart';
import 'package:tencent_cloud_chat_demo/src/utils/push_identity_cache.dart';
import 'package:tencent_cloud_chat_sdk/enum/offlinePushInfo.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_message.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_message.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/view_models/tui_chat_global_model.dart'
    show ConvType;

class MessageOfflinePush {
  MessageOfflinePush._();

  static const String messageChannelId = 'message_push_channel';
  static const String messageChannelName = 'Message notifications';

  static OfflinePushInfo build({
    required V2TimMessage message,
    required String convID,
    required ConvType convType,
  }) {
    final conversationID = _conversationID(
      message: message,
      convID: convID,
      convType: convType,
    );
    final desc = NotificationPushText.summarizeMessage(message);

    final isGroup = convType == ConvType.group;
    final cache = PushIdentityCache.instance;
    final chatType = isGroup ? 'group' : 'c2c';

    var senderName = (cache.selfNickName ?? '').trim();
    if (senderName.isEmpty) {
      senderName = (message.nickName ?? '').trim();
    }
    final senderFaceUrl = cache.selfFaceUrlOrBest();

    var groupName = '';
    var groupFaceUrl = '';
    if (isGroup) {
      final convInfo = cache.lookupConversation(
        conversationID,
        groupId: message.groupID ?? convID,
      );
      groupName = (convInfo?.showName ?? '').trim();
      groupFaceUrl = (convInfo?.faceUrl ?? '').trim();
    }

    final avatarUrl = isGroup
        ? (groupFaceUrl.isNotEmpty ? groupFaceUrl : senderFaceUrl)
        : senderFaceUrl;

    final title = isGroup
        ? (groupName.isNotEmpty ? groupName : IMDemoConfig.appName)
        : (senderName.isNotEmpty ? senderName : IMDemoConfig.appName);

    return OfflinePushInfo(
      title: title,
      desc: desc,
      disablePush: IMDemoConfig.selfHostedPushEnabled,
      ext: jsonEncode(<String, dynamic>{
        'conversationID': conversationID,
        'type': 'chat_message',
        'convType': chatType,
        'chatType': chatType,
        'senderName': senderName,
        'senderFaceUrl': senderFaceUrl,
        'groupName': groupName,
        'groupFaceUrl': groupFaceUrl,
        if (avatarUrl.isNotEmpty) 'avatarUrl': avatarUrl,
      }),
      iOSSound: '',
      androidSound: '',
      ignoreIOSBadge: false,
      androidOPPOChannelID: messageChannelId,
      androidVIVOClassification: 1,
    );
  }

  static String _conversationID({
    required V2TimMessage message,
    required String convID,
    required ConvType convType,
  }) {
    if (convType == ConvType.group) {
      final groupID = _firstNonEmpty(<String?>[
        message.groupID,
        convID,
      ]);
      if (groupID.startsWith('group_')) return groupID;
      return 'group_$groupID';
    }

    final userID = _firstNonEmpty(<String?>[
      message.sender,
      message.userID,
      convID,
    ]);
    if (userID.startsWith('c2c_')) return userID;
    return 'c2c_$userID';
  }

  static String _firstNonEmpty(List<String?> values) {
    for (final value in values) {
      final text = value?.trim();
      if (text != null && text.isNotEmpty) return text;
    }
    return '';
  }
}
