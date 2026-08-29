// ignore_for_file: empty_catches

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_group_at_info.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_group_at_info.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_message.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_message.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_user_status.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_user_status.dart';
import 'package:tencent_cloud_chat_sdk/enum/message_status.dart';
import 'package:tim_ui_kit_sticker_plugin/utils/tim_custom_face_data.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/conversation_list_message_status.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/screen_utils.dart';
import 'package:tencent_cloud_chat_uikit/base_widgets/tim_ui_kit_statelesswidget.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/view_models/tui_chat_global_model.dart';
import 'package:tencent_cloud_chat_uikit/data_services/services_locatar.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/time_ago.dart';
import 'package:tencent_cloud_chat_uikit/ui/views/TIMUIKitConversation/tim_uikit_conversation_last_msg.dart';
import 'package:tencent_cloud_chat_uikit/ui/widgets/avatar.dart';
import 'package:tencent_cloud_chat_uikit/ui/widgets/unread_message.dart';
import 'package:tencent_cloud_chat_uikit/base_widgets/tim_ui_kit_base.dart';
import 'package:tencent_cloud_chat_uikit/theme/color.dart';
import 'package:tencent_cloud_chat_uikit/theme/tui_theme.dart';

typedef LastMessageBuilder = Widget? Function(
    V2TimMessage? lastMsg, List<V2TimGroupAtInfo?> groupAtInfoList);

/// Custom last-message abstract text. Non-null return replaces default switch text;
/// null falls through to [TIMUIKitLastMsg] built-in elem-type handling.
/// Draft priority stays inside [TIMUIKitLastMsg] only.
typedef LastMessageAbstractBuilder = String? Function(
  V2TimMessage lastMsg,
  List<V2TimGroupAtInfo?> groupAtInfoList,
);

class TIMUIKitConversationItem extends TIMUIKitStatelessWidget {
  final String? conversationID;
  final String faceUrl;
  final String nickName;
  final V2TimMessage? lastMsg;
  final int unreadCount;
  final bool isPined;
  final List<V2TimGroupAtInfo?> groupAtInfoList;
  final String? draftText;
  final int? draftTimestamp;
  final int? lastActiveTimestamp;
  final bool isDisturb;
  final LastMessageBuilder? lastMessageBuilder;
  final LastMessageAbstractBuilder? lastMessageAbstractBuilder;
  final V2TimUserStatus? onlineStatus;
  final int? convType;
  final bool isCurrent;
  final BorderRadius? avatarBorderRadius;
  final double? avatarSize;
  final double? titleFontSize;
  final double? subtitleFontSize;
  final double? timestampFontSize;

  final Widget? nickNameWidget;

  final Widget? avatarWidget;

  final List<CustomEmojiFaceData> customEmojiStickerList;

  TIMUIKitConversationItem({
    Key? key,
    this.conversationID,
    required this.faceUrl,
    required this.nickName,
    required this.lastMsg,
    this.onlineStatus,
    required this.isPined,
    this.isCurrent = false,
    required this.unreadCount,
    required this.groupAtInfoList,
    required this.isDisturb,
    this.draftText,
    this.draftTimestamp,
    this.lastActiveTimestamp,
    this.lastMessageBuilder,
    this.lastMessageAbstractBuilder,
    this.convType,
    this.avatarBorderRadius,
    this.avatarSize,
    this.titleFontSize,
    this.subtitleFontSize,
    this.timestampFontSize,
    this.nickNameWidget,
    this.avatarWidget,
    this.customEmojiStickerList = const [],
  }) : super(key: key);

  Widget _getShowMsgWidget(BuildContext context) {
    final isDesktopScreen =
        TUIKitScreenUtils.getFormFactor(context) == DeviceType.Desktop;
    final resolvedSubtitleFontSize =
        subtitleFontSize ?? (isDesktopScreen ? 12.0 : 14.0);
    final hasDraft = draftText != null && draftText!.trim().isNotEmpty;
    // Draft or string abstract path must go through TIMUIKitLastMsg so CUSTOM
    // previews cannot bypass draft priority via Widget lastMessageBuilder.
    if (!hasDraft &&
        lastMessageAbstractBuilder == null &&
        lastMsg != null &&
        lastMessageBuilder != null) {
      final customPreview = lastMessageBuilder!(lastMsg, groupAtInfoList);
      if (customPreview != null) {
        return Align(
          alignment: Alignment.centerLeft,
          child: customPreview,
        );
      }
    }

    if (lastMsg != null || hasDraft) {
      return Align(
        alignment: Alignment.centerLeft,
        child: TIMUIKitLastMsg(
          key: ValueKey<String>('last_msg_${conversationID ?? ''}'),
          conversationID: conversationID,
          fontSize: resolvedSubtitleFontSize,
          groupAtInfoList: groupAtInfoList,
          lastMsg: lastMsg,
          isDisturb: isDisturb,
          unreadCount: unreadCount,
          context: context,
          draftText: draftText ?? "",
          customEmojiStickerList: customEmojiStickerList,
          lastMessageAbstractBuilder: lastMessageAbstractBuilder,
        ),
      );
    }

    // 清空聊天记录后没有预览消息：用同字号空白文本占住第二行高度，
    // 昵称保持在双行布局的原位置，不因单行内容而垂直居中。
    return Text(
      " ",
      maxLines: 1,
      style: TextStyle(
        fontSize: resolvedSubtitleFontSize,
        height: 1.2,
      ),
    );
  }

  Widget? _buildMessageStatusIcon(TUITheme theme) {
    final message = lastMsg;
    if (message == null) {
      return null;
    }
    final isSelf = message.isSelf ?? false;
    final snapshotStatus =
        message.status ?? MessageStatus.V2TIM_MSG_STATUS_SEND_SUCC;
    if (!isSelf) {
      return _statusIcon(
        theme: theme,
        status: snapshotStatus,
        isSelf: false,
        isPeerRead: false,
      );
    }
    final chatModel = serviceLocator<TUIChatGlobalModel>();
    // Read status synchronously without ListenableBuilder. Per-row
    // ListenableBuilder on the entire ChatGlobalModel caused all
    // visible rows to rebuild on every message status change across
    // the app. The feed-level fingerprint already includes
    // lastMessage.status, so status changes propagate through the
    // ConversationListNotifier rebuild cycle without a per-row
    // listener.
    final convId = conversationID?.trim() ?? '';
    final liveStatus = convId.isEmpty
        ? null
        : chatModel.messageStatusInConversation(
            convId,
            clientId: message.id,
            msgID: message.msgID,
            fallback: snapshotStatus,
            elemType: message.elemType,
          );
    final status = ConversationListMessageStatus.resolve(
      isSelf: true,
      lastMessageStatus: snapshotStatus,
      liveStatus: liveStatus,
    );
    final isPeerRead = ConversationListMessageStatus.showsReceipt(
          isSelf: true,
          status: status,
        ) &&
        _resolveLastMessagePeerRead(chatModel, message);
    return _statusIcon(
          theme: theme,
          status: status,
          isSelf: true,
          isPeerRead: isPeerRead,
        ) ??
        const SizedBox.shrink();
  }

  Widget? _statusIcon({
    required TUITheme theme,
    required int status,
    required bool isSelf,
    required bool isPeerRead,
  }) {
    if (ConversationListMessageStatus.showsFail(status)) {
      return Padding(
        padding: const EdgeInsets.only(right: 4),
        child: Icon(Icons.error, color: theme.cautionColor, size: 16),
      );
    }
    if (ConversationListMessageStatus.showsSending(status)) {
      return Padding(
        padding: const EdgeInsets.only(right: 4),
        child: Icon(Icons.arrow_back, color: theme.weakTextColor, size: 16),
      );
    }
    if (!ConversationListMessageStatus.showsReceipt(
      isSelf: isSelf,
      status: status,
    )) {
      return null;
    }
    final readColor = theme.primaryColor ?? const Color(0xFF1E90FF);
    final unreadColor = theme.weakTextColor ?? Colors.grey;
    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: SvgPicture.asset(
        isPeerRead ? 'assets/2.svg' : 'assets/1.svg',
        width: isPeerRead ? 16 : 12,
        height: 10,
        colorFilter: ColorFilter.mode(
          isPeerRead ? readColor : unreadColor,
          BlendMode.srcIn,
        ),
      ),
    );
  }

  bool _resolveLastMessagePeerRead(
    TUIChatGlobalModel chatModel,
    V2TimMessage message,
  ) {
    if (message.isPeerRead == true) {
      return true;
    }
    final convId = conversationID?.trim() ?? '';
    if (convId.isNotEmpty &&
        chatModel.isOutgoingC2CMessagePeerRead(
          conversationID: convId,
          message: message,
        )) {
      return true;
    }
    final msgID = message.msgID?.trim() ?? '';
    if (msgID.isEmpty) {
      return false;
    }
    final receipt = chatModel.getMessageReadReceipt(msgID);
    if (receipt == null) {
      return false;
    }
    if (receipt.isPeerRead == true) {
      return true;
    }
    final unread = receipt.unreadCount;
    final read = receipt.readCount ?? 0;
    return unread != null && unread == 0 && read > 0;
  }

  Widget _getTimeStringForChatWidget(BuildContext context, TUITheme theme) {
    try {
      if (draftTimestamp != null && draftTimestamp != 0) {
        return Text(TimeAgo().getTimeStringForChat(draftTimestamp as int) ?? "",
            style: TextStyle(
              fontSize: timestampFontSize ?? 12,
              color: theme.conversationItemTitmeTextColor,
            ));
      } else if (lastMsg != null) {
        return Text(
            TimeAgo().getTimeStringForChat(lastMsg!.timestamp as int) ?? "",
            style: TextStyle(
              fontSize: timestampFontSize ?? 11,
              color: theme.conversationItemTitmeTextColor,
            ));
      } else if (lastActiveTimestamp != null && lastActiveTimestamp != 0) {
        return Text(
            TimeAgo().getTimeStringForChat(lastActiveTimestamp as int) ?? "",
            style: TextStyle(
              fontSize: timestampFontSize ?? 11,
              color: theme.conversationItemTitmeTextColor,
            ));
      }
    } catch (err) {}

    return Container();
  }

  Widget _buildPinIcon(BuildContext context, TUITheme theme) {
    final isDesktopScreen =
        TUIKitScreenUtils.getFormFactor(context) == DeviceType.Desktop;
    final pinColor = theme.conversationItemTitmeTextColor ??
        theme.weakTextColor ??
        CommonColor.weakTextColor;
    return Transform.rotate(
      angle: 0.785398,
      child: Icon(
        Icons.push_pin,
        size: isDesktopScreen ? 14 : 16,
        color: pinColor,
      ),
    );
  }

  @override
  Widget tuiBuild(BuildContext context, TUIKitBuildValue value) {
    final TUITheme theme = value.theme;
    final isDesktopScreen =
        TUIKitScreenUtils.getFormFactor(context) == DeviceType.Desktop;
    final resolvedAvatarSize = avatarSize ?? (isDesktopScreen ? 40 : 44);
    final messageStatusIcon = _buildMessageStatusIcon(theme);
    final contentRow = Padding(
      padding: const EdgeInsets.only(right: 16),
      child: Row(
        // 昵称/预览相对头像顶对齐，避免单聊行垂直居中造成上方留白。
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.only(top: 0, bottom: 2, right: 0),
            child: avatarWidget != null
                ? SizedBox(
                    width: resolvedAvatarSize,
                    child: Stack(
                      clipBehavior: Clip.none,
                      fit: StackFit.passthrough,
                      children: [
                        avatarWidget!,
                        if (unreadCount != 0)
                          Positioned(
                            top: isDisturb ? -2.5 : -4.5,
                            right: isDisturb ? -2.5 : -4.5,
                            child: UnconstrainedBox(
                              child: UnreadMessage(
                                  width: isDisturb ? 10 : 18,
                                  height: isDisturb ? 10 : 18,
                                  unreadCount: isDisturb ? 0 : unreadCount),
                            ),
                          )
                      ],
                    ),
                  )
                : SizedBox(
                    width: resolvedAvatarSize,
                    height: resolvedAvatarSize,
                    child: Stack(
                      fit: StackFit.expand,
                      clipBehavior: Clip.none,
                      children: [
                        Avatar(
                          onlineStatus: onlineStatus,
                          faceUrl: faceUrl,
                          showName: nickName,
                          type: convType,
                          borderRadius: avatarBorderRadius,
                        ),
                        if (unreadCount != 0)
                          Positioned(
                            top: isDisturb ? -2.5 : -4.5,
                            right: isDisturb ? -2.5 : -4.5,
                            child: UnconstrainedBox(
                              child: UnreadMessage(
                                  width: isDisturb ? 10 : 18,
                                  height: isDisturb ? 10 : 18,
                                  unreadCount: isDisturb ? 0 : unreadCount),
                            ),
                          )
                      ],
                    ),
                  ),
          ),
          Expanded(
            child: Container(
              margin: EdgeInsets.only(left: isDesktopScreen ? 10 : 12),
              padding: const EdgeInsets.only(
                top: 0,
                bottom: 11,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Flexible(
                                    child: nickNameWidget ??
                                        Text(
                                          nickName,
                                          softWrap: false,
                                          textAlign: TextAlign.left,
                                          overflow: TextOverflow.ellipsis,
                                          maxLines: 1,
                                          style: TextStyle(
                                            height: 1.2,
                                            color: theme
                                                .conversationItemTitleTextColor,
                                            fontSize: titleFontSize ?? 16,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                  ),
                                  if (isDisturb) ...[
                                    const SizedBox(width: 6),
                                    SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: Icon(
                                        Icons.notifications_off,
                                        color: theme
                                            .conversationItemNoNotificationIconColor,
                                        size: isDesktopScreen ? 14 : 16.0,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Expanded(child: _getShowMsgWidget(context)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (messageStatusIcon != null) messageStatusIcon,
                          _getTimeStringForChatWidget(context, theme),
                        ],
                      ),
                      if (isPined) ...[
                        const SizedBox(height: 4),
                        _buildPinIcon(context, theme),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          )
        ],
      ),
    );
    // No LayoutBuilder: with itemExtent set on ListView, the row height
    // is always finite and known at build time. LayoutBuilder forces a
    // deferred rebuild during layout phase and prevents widget caching.
    return Container(
      padding: const EdgeInsets.only(top: 8, left: 16),
      child: contentRow,
    );
  }
}
