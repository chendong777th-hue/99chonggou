import 'package:flutter/material.dart';
import 'package:tencent_chat_i18n_tool/tencent_chat_i18n_tool.dart';
import 'package:tencent_cloud_chat_demo/src/utils/group_tip_custom_message.dart';
import 'package:tencent_cloud_chat_demo/src/utils/revoked_message_preview.dart';
import 'package:tencent_cloud_chat_demo/utils/custom_message/custom_last_message.dart';
import 'package:tencent_cloud_chat_demo/utils/custom_message/friend_became_friends_message.dart';
import 'package:tencent_cloud_chat_demo/src/widgets/app_network_image.dart';
import 'package:tencent_cloud_chat_demo/utils/custom_message/red_packet_claim_notice_message.dart';
import 'package:tencent_cloud_chat_sdk/enum/message_elem_type.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_message.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_message.dart';
import 'package:tencent_cloud_chat_uikit/ui/constants/history_message_constant.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/image_mem_cache_utils.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/message.dart';

class ConversationPeekMessageSummary {
  ConversationPeekMessageSummary._();

  static bool isCenterSystemMessage(V2TimMessage message) {
    if (centerSystemText(message) != null) {
      return true;
    }
    return message.elemType == MessageElemType.V2TIM_ELEM_TYPE_GROUP_TIPS &&
        message.groupTipsElem != null;
  }

  static String? centerSystemText(V2TimMessage message) {
    if (isRevokedMessage(message)) {
      return buildRevokedMessagePreviewLabel(message);
    }

    final friendTip = getFriendBecameFriendsDisplayText(message.customElem);
    if (friendTip.isNotEmpty) {
      return friendTip;
    }

    // App→IMSDK group_tip：居中灰字，禁止再包进带头像的气泡行。
    final groupTipPayload = parseGroupTipPayload(message.customElem);
    if (groupTipPayload != null) {
      final tipText = groupTipDisplayText(groupTipPayload).trim();
      if (tipText.isNotEmpty) {
        return tipText;
      }
    }

    final claimNotice = getRedPacketClaimNoticeDisplayText(message.customElem);
    if (claimNotice.isNotEmpty) {
      return claimNotice;
    }

    if (message.customElem?.data == 'group_create') {
      return TIM_t('群聊创建成功！');
    }

    final groupCustom =
        MessageUtils.getCustomGroupCreatedOrDismissedString(message);
    if (groupCustom.isNotEmpty) {
      return groupCustom;
    }

    return null;
  }

  static String text({
    required V2TimMessage message,
    required bool isGroup,
  }) {
    if (isRevokedMessage(message)) {
      return buildRevokedMessagePreviewLabel(message);
    }

    final elemType = message.elemType;
    if (elemType == MessageElemType.V2TIM_ELEM_TYPE_CUSTOM) {
      return buildConversationLastCustomMessagePreview(message);
    }

    final abstract = MessageUtils.getAbstractMessageAsync(message, const []);
    if (!isGroup || (message.isSelf ?? false)) {
      return abstract;
    }

    final sender = MessageUtils.getDisplayName(message).trim();
    if (sender.isEmpty) {
      return abstract;
    }
    return '$sender: $abstract';
  }

  static Widget? thumbnail(BuildContext context, V2TimMessage message) {
    if (isRevokedMessage(message)) {
      return null;
    }
    if (message.elemType != MessageElemType.V2TIM_ELEM_TYPE_IMAGE) {
      return null;
    }
    final image = MessageUtils.getImageFromImgList(
      message.imageElem?.imageList,
      HistoryMessageDartConstant.smallImgPrior,
    );
    final url = image?.url?.trim() ?? '';
    if (url.isEmpty) {
      return null;
    }
    const thumbSize = 48.0;
    final cacheSize = ImageMemCacheSize.forLogicalSize(thumbSize, context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: url.startsWith('http')
          ? AppNetworkImage(
              url: url,
              width: thumbSize,
              height: thumbSize,
              fit: BoxFit.cover,
              memCacheWidth: cacheSize,
              memCacheHeight: cacheSize,
              errorWidget: (_, __, ___) => const SizedBox.shrink(),
            )
          : Image.asset(
              url,
              width: thumbSize,
              height: thumbSize,
              fit: BoxFit.cover,
              cacheWidth: cacheSize,
              cacheHeight: cacheSize,
              errorBuilder: (_, __, ___) => const SizedBox.shrink(),
            ),
    );
  }

}
