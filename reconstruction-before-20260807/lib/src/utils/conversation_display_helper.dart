import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:tencent_cloud_chat_demo/utils/conversation_face_url.dart';
import 'package:tencent_cloud_chat_demo/utils/friend_display_name.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_conversation.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_conversation.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_friend_info.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_friend_info.dart';

class ConversationDisplayHelper {
  ConversationDisplayHelper._();

  static bool isGroupConversation(V2TimConversation conversation) {
    return conversation.type == 2 ||
        (conversation.groupID?.trim().isNotEmpty ?? false);
  }

  static String showName({
    required V2TimConversation conversation,
    List<V2TimFriendInfo>? friendList,
  }) {
    return FriendDisplayName.resolveConversation(
      conversation: conversation,
      friendList: friendList,
    );
  }

  static String faceUrl({
    required V2TimConversation conversation,
    List<V2TimFriendInfo>? friendList,
  }) {
    return ConversationFaceUrl.resolve(
      userId: conversation.userID,
      conversationFaceUrl: conversation.faceUrl,
      isGroup: isGroupConversation(conversation),
      friendList: friendList,
    );
  }

  static Widget? avatarWidget({
    required V2TimConversation conversation,
    List<V2TimFriendInfo>? friendList,
  }) {
    final resolvedFaceUrl = faceUrl(
      conversation: conversation,
      friendList: friendList,
    );
    if (resolvedFaceUrl != ConversationFaceUrl.defaultGroupFaceAsset) {
      return null;
    }
    return ClipOval(
      child: SvgPicture.asset(
        ConversationFaceUrl.defaultGroupFaceAsset,
        fit: BoxFit.cover,
      ),
    );
  }
}
