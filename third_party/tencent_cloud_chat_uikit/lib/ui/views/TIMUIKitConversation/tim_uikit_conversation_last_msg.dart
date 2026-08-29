// ignore_for_file: unrelated_type_equality_checks

import 'dart:async';

import 'package:extended_text/extended_text.dart';
import 'package:flutter/material.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_local/conversation_perf_flags.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_local/conversation_preview_text_cache.dart';
import 'package:tencent_cloud_chat_demo/src/utils/revoked_message_preview.dart';
import 'package:tencent_cloud_chat_demo/utils/custom_message/custom_last_message.dart';
import 'package:tencent_chat_i18n_tool/tencent_chat_i18n_tool.dart';
import 'package:tencent_cloud_chat_demo/utils/custom_message/contact_card_message.dart';
import 'package:tencent_cloud_chat_demo/src/services/group_local/group_change_event_sync_service.dart';
import 'package:tencent_cloud_chat_demo/src/services/group_local/group_tips_operator_patch_service.dart';
import 'package:tencent_cloud_chat_demo/src/utils/group_tips_operator_live_cache.dart';
import 'package:tencent_cloud_chat_demo/utils/group_tips_message_helper.dart';
import 'package:tencent_cloud_chat_sdk/enum/message_elem_type.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_group_at_info.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_group_at_info.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_message.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_message.dart';
import 'package:tencent_cloud_chat_uikit/base_widgets/tim_ui_kit_base.dart';
import 'package:tencent_cloud_chat_uikit/base_widgets/tim_ui_kit_state.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/services/display_name_store.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/services/group_member_store.dart';
import 'package:tencent_cloud_chat_uikit/tencent_cloud_chat_uikit.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/message.dart';
import 'package:tencent_cloud_chat_uikit/ui/views/TIMUIKitChat/TIMUIKitTextField/special_text/DefaultSpecialTextSpanBuilder.dart';
import 'package:tencent_cloud_chat_uikit/theme/tui_theme.dart';

/// 群聊会话预览第二行：发送者并入摘要，避免单独占第三行。
String buildGroupConversationPreviewLine({
  required String previewText,
  required String senderName,
  bool isDraft = false,
}) {
  final preview = previewText.trim();
  final sender = senderName.trim();
  if (isDraft || sender.isEmpty) {
    return preview;
  }
  if (preview.isEmpty) {
    return sender;
  }
  return '$sender: $preview';
}

class TIMUIKitLastMsg extends StatefulWidget {
  final String? conversationID;
  final V2TimMessage? lastMsg;
  final List<V2TimGroupAtInfo?> groupAtInfoList;
  final BuildContext context;
  final double fontSize;
  final List<CustomEmojiFaceData> customEmojiStickerList;
  final bool isDisturb;
  final int unreadCount;
  final String draftText;

  /// Same contract as [LastMessageAbstractBuilder] on conversation item.
  final String? Function(
    V2TimMessage lastMsg,
    List<V2TimGroupAtInfo?> groupAtInfoList,
  )? lastMessageAbstractBuilder;

  const TIMUIKitLastMsg(
      {Key? key,
      this.conversationID,
      this.lastMsg,
      required this.groupAtInfoList,
      this.isDisturb = false,
      this.unreadCount = 0,
      required this.draftText,
      required this.context,
      this.fontSize = 14.0,
      this.customEmojiStickerList = const [],
      this.lastMessageAbstractBuilder})
      : super(key: key);

  @override
  State<TIMUIKitLastMsg> createState() => _TIMUIKitLastMsgState();
}

class _TIMUIKitLastMsgState extends TIMUIKitState<TIMUIKitLastMsg> {
  String groupTipsAbstractText = "";
  String groupSenderName = "";
  int _previewResolveGeneration = 0;
  String _resolvedPreviewKey = "";

  @override
  void initState() {
    super.initState();
    _getMsgElem(notify: false);
  }

  @override
  void dispose() {
    _previewResolveGeneration++;
    super.dispose();
  }

  String _currentPreviewKey(V2TimMessage? message) {
    if (message == null) {
      return '';
    }
    return conversationPreviewCacheMessageKey(message);
  }

  @override
  void didUpdateWidget(covariant TIMUIKitLastMsg oldWidget) {
    super.didUpdateWidget(oldWidget);
    final currentKey = _currentPreviewKey(widget.lastMsg);
    // 撤回常原地改同一条 lastMessage；old/new 引用相同，字段对比全相等。
    // 用上次已渲染的 key 才能发现「您撤回了一条消息」。
    if (currentKey != _resolvedPreviewKey ||
        (oldWidget.lastMsg?.msgID != widget.lastMsg?.msgID) ||
        (oldWidget.conversationID != widget.conversationID) ||
        (oldWidget.lastMsg?.seq != widget.lastMsg?.seq) ||
        (oldWidget.lastMsg?.timestamp != widget.lastMsg?.timestamp) ||
        (oldWidget.lastMsg?.elemType != widget.lastMsg?.elemType) ||
        (oldWidget.lastMsg?.textElem?.text != widget.lastMsg?.textElem?.text) ||
        (oldWidget.lastMsg?.customElem?.data !=
            widget.lastMsg?.customElem?.data) ||
        (oldWidget.lastMsg?.id != widget.lastMsg?.id) ||
        (oldWidget.lastMsg?.status != widget.lastMsg?.status) ||
        (oldWidget.lastMsg?.cloudCustomData !=
            widget.lastMsg?.cloudCustomData) ||
        (oldWidget.lastMsg?.revokerInfo?.userID !=
            widget.lastMsg?.revokerInfo?.userID) ||
        (oldWidget.lastMsg?.isPeerRead != widget.lastMsg?.isPeerRead) ||
        (oldWidget.lastMsg?.localCustomData !=
            widget.lastMsg?.localCustomData) ||
        (oldWidget.unreadCount != widget.unreadCount) ||
        (oldWidget.draftText != widget.draftText) ||
        (oldWidget.lastMsg != null &&
            widget.lastMsg != null &&
            conversationPreviewCacheMessageKey(oldWidget.lastMsg!) !=
                conversationPreviewCacheMessageKey(widget.lastMsg!))) {
      _getMsgElem();
    }
  }

  (bool isRevoke, bool isRevokeByAdmin) isRevokeMessage(V2TimMessage? message) {
    if (message == null) {
      return (false, false);
    }
    if (!isRevokedMessage(message)) {
      return (false, false);
    }
    return (true, isRevokedByAdmin(message));
  }

  void _getMsgElem({bool notify = true}) {
    final generation = ++_previewResolveGeneration;
    final lastMsg = widget.lastMsg;
    if (lastMsg == null) {
      _resolvedPreviewKey = '';
      _setResolvedPreview(
        senderName: "",
        previewText: "",
        notify: notify,
      );
      return;
    }
    final senderName = _getGroupSenderName(lastMsg);
    final cacheConversationId = _previewCacheConversationId(lastMsg);
    final cacheMessageKey = _previewCacheMessageKey(lastMsg);
    _resolvedPreviewKey = cacheMessageKey;
    final revokeStatus = isRevokeMessage(lastMsg);
    final isRevokedMessage = revokeStatus.$1;
    final isGroupTips =
        lastMsg.elemType == MessageElemType.V2TIM_ELEM_TYPE_GROUP_TIPS;
    if (!isRevokedMessage &&
        !isGroupTips &&
        cacheConversationId.isNotEmpty &&
        cacheMessageKey.isNotEmpty) {
      final cached = ConversationPreviewTextCache.instance.getForMessage(
        cacheConversationId,
        cacheMessageKey,
      );
      if (cached != null) {
        _setResolvedPreview(
          senderName: senderName,
          previewText: cached,
          notify: notify,
        );
        return;
      }
    }
    if (isRevokedMessage) {
      final preview = buildRevokedMessagePreviewLabel(lastMsg);
      _setAndCacheResolvedPreview(
        senderName: senderName,
        previewText: preview,
        notify: notify,
        conversationID: cacheConversationId,
        messageKey: cacheMessageKey,
      );
    } else {
      final resolved = _getLastMsgShowText(lastMsg, widget.context);
      if (resolved is Future<String?>) {
        // 新摘要完成前先清掉旧行内容；代次门禁会阻止旧任务回写。
        groupTipsAbstractText = "";
        groupSenderName = senderName;
        unawaited(resolved.then((msgShowText) {
          if (mounted && generation == _previewResolveGeneration) {
            _setAndCacheResolvedPreview(
              senderName: _getGroupSenderName(widget.lastMsg ?? lastMsg),
              previewText: msgShowText ?? "",
              notify: true,
              conversationID: cacheConversationId,
              messageKey: cacheMessageKey,
            );
          }
        }));
        return;
      }
      _setAndCacheResolvedPreview(
        senderName: senderName,
        previewText: resolved ?? "",
        notify: notify,
        conversationID: cacheConversationId,
        messageKey: cacheMessageKey,
      );
    }
  }

  void _setResolvedPreview({
    required String senderName,
    required String previewText,
    bool notify = true,
  }) {
    if (!notify || !mounted) {
      groupSenderName = senderName;
      groupTipsAbstractText = previewText;
      return;
    }
    if (groupSenderName == senderName && groupTipsAbstractText == previewText) {
      return;
    }
    setState(() {
      groupSenderName = senderName;
      groupTipsAbstractText = previewText;
    });
  }

  String _getGroupSenderName(V2TimMessage message) {
    if (message.groupID?.trim().isEmpty ?? true) {
      return "";
    }
    if (message.elemType == MessageElemType.V2TIM_ELEM_TYPE_GROUP_TIPS) {
      return "";
    }
    return MessageUtils.getDisplayName(message).trim();
  }

  String _previewCacheConversationId(V2TimMessage message) {
    final direct = widget.conversationID?.trim() ?? '';
    if (direct.isNotEmpty) {
      return direct;
    }
    final groupId = message.groupID?.trim() ?? '';
    if (groupId.isNotEmpty) {
      return 'group_$groupId';
    }
    final userId = message.userID?.trim() ?? '';
    if (userId.isNotEmpty) {
      return 'c2c_$userId';
    }
    return '';
  }

  String _previewCacheMessageKey(V2TimMessage message) {
    return conversationPreviewCacheMessageKey(message);
  }

  void _setAndCacheResolvedPreview({
    required String senderName,
    required String previewText,
    required bool notify,
    required String conversationID,
    required String messageKey,
  }) {
    ConversationPreviewTextCache.instance.putStrong(
      conversationID,
      previewText,
      messageKey: messageKey,
    );
    _setResolvedPreview(
      senderName: senderName,
      previewText: previewText,
      notify: notify,
    );
  }

  String _getDisturbUnreadCountInfo() {
    if (widget.isDisturb && widget.unreadCount > 0) {
      final option1 = widget.unreadCount.toString();
      String unreadCountText =
          TIM_t_para("[{{option1}} 条]", "[$option1 条]")(option1: option1);
      return unreadCountText;
    }

    return "";
  }

  FutureOr<String?> _getLastMsgShowText(
      V2TimMessage? message, BuildContext context) {
    if (message == null) {
      return "";
    }
    final abstractBuilder = widget.lastMessageAbstractBuilder;
    if (abstractBuilder != null) {
      final customAbstract = abstractBuilder(message, widget.groupAtInfoList);
      if (customAbstract != null) {
        return customAbstract;
      }
    }
    final msgType = message.elemType;
    String? result;
    switch (msgType) {
      case MessageElemType.V2TIM_ELEM_TYPE_CUSTOM:
        final contactCardMessage = getContactCardMessage(message.customElem);
        if (contactCardMessage != null) {
          final displayName = contactCardMessage.nickName.isNotEmpty
              ? contactCardMessage.nickName
              : contactCardMessage.userID;
          result = TIM_t_para("[联系人] {{option1}}", "[联系人] $displayName")(
            option1: displayName,
          );
          break;
        }
        result = TIM_t("[自定义]");
        break;
      case MessageElemType.V2TIM_ELEM_TYPE_SOUND:
        result = TIM_t("[语音]");
        break;
      case MessageElemType.V2TIM_ELEM_TYPE_TEXT:
        result = (message.textElem?.text)?.trim() ?? "";
        break;
      case MessageElemType.V2TIM_ELEM_TYPE_FACE:
        result = TIM_t("[表情]");
        break;
      case MessageElemType.V2TIM_ELEM_TYPE_FILE:
        final option1 = message.fileElem?.fileName ?? "";
        result =
            TIM_t_para("[文件] {{option1}}", "[文件] $option1")(option1: option1);
        break;
      case MessageElemType.V2TIM_ELEM_TYPE_GROUP_TIPS:
        final resolved =
            GroupTipsMessageHelper.resolvedMemberTipPreview(message);
        if (resolved != null && resolved.isNotEmpty) {
          return resolved;
        }
        if (GroupTipsMessageHelper.isPendingAdministratorMemberTip(message)) {
          final groupId = message.groupID?.trim() ??
              message.groupTipsElem?.groupID.trim() ??
              '';
          if (groupId.isNotEmpty) {
            unawaited(
              GroupTipsOperatorPatchService.instance
                  .warmLiveCacheForGroup(groupId),
            );
            unawaited(
              GroupChangeEventSyncService.instance.syncForGroup(
                groupId,
                reason: 'conversation_list_operator_wait',
              ),
            );
          }
          return '';
        }
        final groupTipsElem = message.groupTipsElem;
        if (groupTipsElem == null) {
          return "";
        }
        return MessageUtils.groupTipsMessageAbstract(
          groupTipsElem,
          [],
          message: message,
        );
      case MessageElemType.V2TIM_ELEM_TYPE_IMAGE:
        result = TIM_t("[图片]");
        break;
      case MessageElemType.V2TIM_ELEM_TYPE_VIDEO:
        result = TIM_t("[视频]");
        break;
      case MessageElemType.V2TIM_ELEM_TYPE_LOCATION:
        result = TIM_t("[位置]");
        break;
      case MessageElemType.V2TIM_ELEM_TYPE_MERGER:
        result = TIM_t("[聊天记录]");
        break;
      default:
        result = null;
        break;
    }

    return result;
  }

  String _getAtMessage() {
    bool atMe = false;
    bool atAll = false;
    String msg = "";
    for (var item in widget.groupAtInfoList) {
      if (item == null) {
        continue;
      }
      if (item.atType == 1) {
        atMe = true;
        continue;
      } else if (item.atType == 2) {
        atAll = true;
        continue;
      } else if (item.atType == 3) {
        atMe = true;
        atAll = true;
        continue;
      }
    }

    if (atAll && atMe) {
      msg = TIM_t("[@所有人][有人@我]");
    } else if (atAll) {
      msg = TIM_t("[@所有人]");
    } else if (atMe) {
      msg = TIM_t("[有人@我]");
    }

    return msg;
  }

  String _getDraftShowText() {
    final draftShowText = TIM_t("草稿");
    return '[$draftShowText]';
  }

  Widget _buildPreviewText(String text, TextStyle style) {
    if (text.isEmpty) {
      return const SizedBox.shrink();
    }
    // 纯 Text 无法渲染 [superciliousLook] 等内置表情；含 '[' 时走 ExtendedText。
    final needsEmojiSpan = text.contains('[');
    if (ConversationPerfFlags.conversationListPlainPreviewText &&
        !needsEmojiSpan) {
      return Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        softWrap: false,
        style: style,
      );
    }
    return ExtendedText(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: style,
      specialTextSpanBuilder: DefaultSpecialTextSpanBuilder(
        isUseQQPackage: true,
        isUseTencentCloudChatPackage: true,
        customEmojiStickerList: widget.customEmojiStickerList,
        checkHttpLink: false,
        checkChatIdMention: false,
      ),
    );
  }

  @override
  Widget tuiBuild(BuildContext context, TUIKitBuildValue value) {
    final TUITheme theme = value.theme;
    String disturbUnreadCountInfo = _getDisturbUnreadCountInfo();
    final hasDraft = widget.draftText.trim().isNotEmpty;
    final previewText = buildGroupConversationPreviewLine(
      previewText: hasDraft ? widget.draftText.trim() : groupTipsAbstractText,
      senderName: groupSenderName,
      isDraft: hasDraft,
    );
    final previewColor =
        hasDraft ? theme.conversationItemDraftTextColor : theme.weakTextColor;
    final hasAtMessage = widget.groupAtInfoList.any((item) => item != null);
    final hasPreviewLine = hasAtMessage ||
        hasDraft ||
        disturbUnreadCountInfo.isNotEmpty ||
        TencentUtils.checkString(previewText) != null;

    if (!hasPreviewLine) {
      return const SizedBox.shrink();
    }

    final previewLineStyle = TextStyle(
      fontSize: widget.fontSize,
      height: 1.2,
    );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (widget.groupAtInfoList.isNotEmpty)
          Text(
            _getAtMessage(),
            style: previewLineStyle.copyWith(color: theme.cautionColor),
          ),
        if (hasDraft)
          Text(
            _getDraftShowText(),
            style: previewLineStyle.copyWith(
              color: theme.conversationItemDraftTextColor,
            ),
          ),
        if (disturbUnreadCountInfo != "")
          Text(
            disturbUnreadCountInfo,
            style: previewLineStyle.copyWith(color: theme.weakTextColor),
          ),
        if (TencentUtils.checkString(previewText) != null)
          Expanded(
            child: _buildPreviewText(
              previewText,
              previewLineStyle.copyWith(color: previewColor),
            ),
          ),
      ],
    );
  }
}
