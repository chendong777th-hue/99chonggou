import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tencent_cloud_chat_demo/src/services/platform_official_account_service.dart';
import 'package:tencent_cloud_chat_demo/src/widgets/app_user_avatar.dart';
import 'package:tencent_cloud_chat_demo/src/widgets/conversation_peek/conversation_peek_face_bubble.dart';
import 'package:tencent_cloud_chat_demo/src/widgets/conversation_peek/conversation_peek_media_bubble.dart';
import 'package:tencent_cloud_chat_demo/src/widgets/conversation_peek/conversation_peek_sound_bubble.dart';
import 'package:tencent_cloud_chat_demo/utils/custom_message/custom_message_element.dart';
import 'package:tencent_cloud_chat_demo/utils/custom_message/friend_became_friends_message.dart';
import 'package:tencent_cloud_chat_demo/utils/user_avatar.dart';
import 'package:tencent_cloud_chat_sdk/enum/message_elem_type.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_message.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_message.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/separate_models/tui_chat_separate_view_model.dart';
import 'package:tencent_cloud_chat_uikit/ui/controller/tim_uikit_chat_controller.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/message.dart';
import 'package:tencent_cloud_chat_uikit/ui/views/TIMUIKitChat/TIMUIKitMessageItem/tim_uikit_chat_file_elem.dart';
import 'package:tencent_cloud_chat_uikit/ui/views/TIMUIKitChat/TIMUIKitMessageItem/tim_uikit_chat_text_elem.dart';

class ConversationPeekMessageItem extends StatelessWidget {
  const ConversationPeekMessageItem({
    super.key,
    required this.message,
    required this.chatModel,
    required this.chatController,
    required this.isGroup,
    required this.subtitleColor,
    this.peerFaceUrl,
    this.peerShowName,
    this.peerUserId,
    this.groupId,
  });

  final V2TimMessage message;
  final TUIChatSeparateViewModel chatModel;
  final TIMUIKitChatController chatController;
  final bool isGroup;
  final Color subtitleColor;

  /// C2C 会话头像兜底（消息未带 faceUrl 时使用）。
  final String? peerFaceUrl;
  final String? peerShowName;
  final String? peerUserId;
  final String? groupId;

  static const double _avatarSize = 40;
  static const double _avatarGap = 10;

  bool get _isSelf => message.isSelf ?? false;

  String get _displayName {
    final fromMessage = MessageUtils.getDisplayName(message).trim();
    if (fromMessage.isNotEmpty) {
      return fromMessage;
    }
    final fromPeer = peerShowName?.trim() ?? '';
    if (fromPeer.isNotEmpty) {
      return fromPeer;
    }
    return (message.sender ?? message.userID ?? '').trim();
  }

  String _resolvePeerFaceUrl() {
    final sender = (message.sender ?? message.userID ?? '').trim();
    if (isGroup) {
      final fromStore = UserAvatarHelper.groupMemberFaceUrl(groupId, sender);
      final faceCandidate = <String?>[
        fromStore,
        message.faceUrl,
      ].firstWhere(
        (e) => (e?.trim().isNotEmpty ?? false),
        orElse: () => message.faceUrl,
      );
      return UserAvatarHelper.pickBest(imFaceUrl: faceCandidate);
    }

    if (PlatformOfficialAccountService.isPlatformOfficialAccount(peerUserId)) {
      return PlatformOfficialAccountService.resolveFaceUrl(
        userId: peerUserId,
        conversationFaceUrl: message.faceUrl ?? peerFaceUrl,
      );
    }

    final faceCandidate = <String?>[
      message.faceUrl,
      peerFaceUrl,
    ].firstWhere(
      (e) => (e?.trim().isNotEmpty ?? false),
      orElse: () => message.faceUrl,
    );
    return UserAvatarHelper.pickBest(imFaceUrl: faceCandidate);
  }

  @override
  Widget build(BuildContext context) {
    final senderName = isGroup && !_isSelf ? _displayName : '';
    final bubble = ChangeNotifierProvider<TUIChatSeparateViewModel>.value(
      value: chatModel,
      child: IgnorePointer(
        child: _buildMessageContent(),
      ),
    );

    if (_isSelf) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Align(
          alignment: Alignment.centerRight,
          child: bubble,
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppUserAvatar(
            faceUrl: _resolvePeerFaceUrl(),
            showName: _displayName,
            size: _avatarSize,
          ),
          const SizedBox(width: _avatarGap),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (senderName.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(left: 2, bottom: 3),
                    child: Text(
                      senderName,
                      style: TextStyle(
                        fontSize: 12,
                        color: subtitleColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                bubble,
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageContent() {
    final elemType = message.elemType;
    const isShowJump = false;
    void clearJump() {}

    // 有些历史/归档消息 elemType 偶发不准，但具体 elem 仍在。
    final looksLikeImage = elemType == MessageElemType.V2TIM_ELEM_TYPE_IMAGE ||
        message.imageElem != null;
    final looksLikeVideo = elemType == MessageElemType.V2TIM_ELEM_TYPE_VIDEO ||
        (message.videoElem != null && message.imageElem == null);
    if (looksLikeImage || looksLikeVideo) {
      return ConversationPeekMediaBubble(message: message);
    }
    if (elemType == MessageElemType.V2TIM_ELEM_TYPE_SOUND ||
        message.soundElem != null) {
      if (message.soundElem == null) {
        return _fallbackText();
      }
      return ConversationPeekSoundBubble(
        message: message,
        chatModel: chatModel,
      );
    }
    if (elemType == MessageElemType.V2TIM_ELEM_TYPE_FACE ||
        message.faceElem != null) {
      return ConversationPeekFaceBubble(message: message);
    }

    switch (elemType) {
      case MessageElemType.V2TIM_ELEM_TYPE_TEXT:
        return TIMUIKitTextElem(
          chatModel: chatModel,
          message: message,
          isFromSelf: _isSelf,
          clearJump: clearJump,
          isShowJump: isShowJump,
          isShowMessageReaction: false,
        );
      case MessageElemType.V2TIM_ELEM_TYPE_IMAGE:
      case MessageElemType.V2TIM_ELEM_TYPE_VIDEO:
        return ConversationPeekMediaBubble(message: message);
      case MessageElemType.V2TIM_ELEM_TYPE_SOUND:
        if (message.soundElem == null) {
          return _fallbackText();
        }
        return ConversationPeekSoundBubble(
          message: message,
          chatModel: chatModel,
        );
      case MessageElemType.V2TIM_ELEM_TYPE_FACE:
        return ConversationPeekFaceBubble(message: message);
      case MessageElemType.V2TIM_ELEM_TYPE_FILE:
        final fileElem = message.fileElem;
        if (fileElem == null) {
          return _fallbackText();
        }
        return TIMUIKitFileElem(
          chatModel: chatModel,
          message: message,
          messageID: message.msgID,
          fileElem: fileElem,
          isSelf: _isSelf,
          clearJump: clearJump,
          isShowJump: isShowJump,
          isShowMessageReaction: false,
        );
      case MessageElemType.V2TIM_ELEM_TYPE_CUSTOM:
        if (getFriendBecameFriendsDisplayText(message.customElem).isNotEmpty) {
          return const SizedBox.shrink();
        }
        return CustomMessageElem(
          message: message,
          isShowJump: isShowJump,
          clearJump: clearJump,
          chatController: chatController,
        );
      default:
        return _fallbackText();
    }
  }

  Widget _fallbackText() {
    return TIMUIKitTextElem(
      chatModel: chatModel,
      message: message,
      isFromSelf: _isSelf,
      clearJump: () {},
      isShowJump: false,
      isShowMessageReaction: false,
    );
  }
}
