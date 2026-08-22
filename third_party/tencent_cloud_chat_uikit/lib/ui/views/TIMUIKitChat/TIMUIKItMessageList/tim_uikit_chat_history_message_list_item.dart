import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:provider/provider.dart';
import 'package:tencent_chat_i18n_tool/tencent_chat_i18n_tool.dart';
import 'package:tencent_cloud_chat_sdk/enum/message_elem_type.dart';
import 'package:tencent_cloud_chat_sdk/enum/message_status.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_group_member_full_info.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_group_member_full_info.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_message.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_message.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_sound_elem.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_sound_elem.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_message_change_info.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_message_change_info.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_user_full_info.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_user_full_info.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_value_callback.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_value_callback.dart';
import 'package:tencent_cloud_chat_uikit/base_widgets/tim_ui_kit_base.dart';
import 'package:tencent_cloud_chat_uikit/base_widgets/tim_ui_kit_state.dart';
import 'package:tencent_cloud_chat_uikit/base_widgets/tim_ui_kit_statelesswidget.dart';
import 'package:tencent_cloud_chat_uikit/base_widgets/tim_callback.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/separate_models/tui_chat_separate_view_model.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/view_models/chat_ui_state_store.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/view_models/tui_chat_global_model.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/view_models/tui_friendship_view_model.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/view_models/tui_self_info_view_model.dart';
import 'package:tencent_cloud_chat_uikit/data_services/core/tim_uikit_wide_modal_operation_key.dart';
import 'package:tencent_cloud_chat_uikit/data_services/friendShip/friendship_services.dart';
import 'package:tencent_cloud_chat_uikit/data_services/message/message_services.dart';
import 'package:tencent_cloud_chat_uikit/data_services/services_locatar.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/add_friend_navigator.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/friend_add_source.dart';
import 'package:tencent_cloud_chat_uikit/ui/views/TIMUIKitAddFriend/tim_uikit_send_application.dart';
import 'package:tencent_cloud_chat_uikit/tencent_cloud_chat_uikit.dart';
import 'package:tencent_cloud_chat_uikit/ui/constants/history_message_constant.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/error_message_converter.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/message.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/platform.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/screen_utils.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/time_ago.dart';
import 'package:tencent_cloud_chat_uikit/ui/views/TIMUIKitChat/TIMUIKItMessageList/tim_uikit_chat_message_tooltip.dart';
import 'package:tencent_cloud_chat_uikit/ui/views/TIMUIKitChat/TIMUIKItMessageList/tim_uikit_telegram_message_context_controller.dart';
import 'package:tencent_cloud_chat_uikit/ui/views/TIMUIKitChat/TIMUIKItMessageList/tim_uikit_message_read_receipt.dart';
import 'package:tencent_cloud_chat_uikit/ui/widgets/chat_message_input_anchor.dart';
import 'package:tencent_cloud_chat_uikit/ui/views/TIMUIKitChat/TIMUIKitMessageItem/TIMUIKitMessageReaction/tim_uikit_message_reaction_utils.dart';
import 'package:tencent_cloud_chat_uikit/ui/views/TIMUIKitChat/TIMUIKitMessageItem/main.dart';
import 'package:tencent_cloud_chat_uikit/ui/views/TIMUIKitChat/TIMUIKitMessageItem/tim_uikit_chat_custom_elem.dart';
import 'package:tencent_cloud_chat_uikit/ui/views/TIMUIKitChat/TIMUIKitMessageItem/tim_uikit_chat_face_elem.dart';
import 'package:tencent_cloud_chat_uikit/ui/views/TIMUIKitChat/TIMUIKitMessageItem/tim_uikit_chat_text_translate_elem.dart';
import 'package:tencent_cloud_chat_uikit/ui/views/TIMUIKitChat/tim_uikit_cloud_custom_data.dart';
import 'package:tencent_cloud_chat_uikit/ui/widgets/avatar.dart';
import 'package:tencent_cloud_chat_uikit/ui/widgets/forward_message_screen.dart';
import 'package:tencent_cloud_chat_uikit/ui/widgets/radio_button.dart';
import 'package:tencent_cloud_chat_uikit/ui/views/TIMUIKitChat/TIMUIKitMessageItem/tim_uikit_media_upload_overlay.dart';
import 'package:tencent_cloud_chat_uikit/ui/widgets/message_bubble_watermark.dart';
import 'package:tencent_cloud_chat_uikit/ui/widgets/wide_popup.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/wide_popup_layout.dart';
import 'package:tencent_super_tooltip/tencent_super_tooltip.dart';
import 'package:visibility_detector/visibility_detector.dart';

import 'package:tencent_cloud_chat_uikit/theme/color.dart';
import 'package:tencent_cloud_chat_uikit/theme/tui_theme.dart';
import 'package:tencent_cloud_chat_uikit/theme/tui_theme_view_model.dart';
import '../TIMUIKitMessageItem/TIMUIKitMessageReaction/tim_uikit_message_reaction_select_emoji.dart';

bool _isDarkMessageTooltipTheme(TUITheme? theme) {
  if (theme == null) return false;
  final wide = theme.wideBackgroundColor ?? Colors.white;
  return wide.computeLuminance() < 0.5;
}

bool _isDarkChatTheme(TUITheme? theme) {
  if (theme == null) return false;
  final background = theme.wideBackgroundColor ??
      theme.conversationItemBgColor ??
      Colors.white;
  return background.computeLuminance() < 0.5;
}

Color _messageTooltipSurfaceColor(TUITheme? theme) {
  if (theme == null) return Colors.white;
  if (_isDarkMessageTooltipTheme(theme)) {
    return theme.conversationItemBgColor ?? const Color(0xFF2A2D33);
  }
  return theme.white ?? Colors.white;
}

Color _messageTooltipBorderColor(TUITheme? theme) {
  if (theme == null) return Colors.white;
  if (_isDarkMessageTooltipTheme(theme)) {
    return theme.weakDividerColor ?? const Color(0xFF3A3A3A);
  }
  return theme.white ?? Colors.white;
}

/// 聊天消息列表头像（固定 40x40 正圆）。
Widget timUIKitCircularMessageAvatar({
  required String faceUrl,
  required String showName,
  double size = 40,
}) {
  return ClipOval(
    child: SizedBox(
      width: size,
      height: size,
      child: Avatar(
        faceUrl: faceUrl,
        showName: showName,
        borderRadius: BorderRadius.zero,
      ),
    ),
  );
}

typedef MessageRowBuilder = Widget? Function(
  /// current message
  V2TimMessage message,

  /// the message widget for current message, build by your custom builder or our default builder
  Widget messageWidget,

  /// scroll to the specific message, it will shows in the screen center, and call isNeedShowJumpStatus if necessary
  Function onScrollToIndex,

  /// if current message been called to jumped by other message
  bool isNeedShowJumpStatus,

  /// clear the been jumped status, recommend to execute after get 'isNeedShowJumpStatus'
  VoidCallback clearJumpStatus,

  /// scroll to specific message, it will shows on the screen top, without the call isNeedShowJumpStatus
  Function onScrollToIndexBegin,
);

typedef MessageNickNameBuilder = Widget Function(
    BuildContext context, V2TimMessage message, TUIChatSeparateViewModel model);

typedef MessageItemContent = Widget? Function(
  V2TimMessage message,
  bool isShowJump,
  VoidCallback clearJump,
);

class RenderingDirectionResult {
  final bool? isSelf;
  final V2TimUserFullInfo? userInfo;

  const RenderingDirectionResult({
    this.isSelf,
    this.userInfo,
  });
}

typedef RenderingDirectionCallback = RenderingDirectionResult? Function(
    V2TimMessage message);

class MessageHoverControlItem {
  String name;
  Widget icon;
  ValueChanged<TapDownDetails> onClick;

  MessageHoverControlItem(
      {required this.name, required this.icon, required this.onClick});
}

typedef MessageBottomRowBuilder = Widget? Function(
  BuildContext context,
  V2TimMessage message,
);

class MessageItemBuilder {
  /// text message builder, returns null means using default widget.
  final MessageItemContent? textMessageItemBuilder;

  /// text message builder for reply message, returns null means using default widget.
  final MessageItemContent? textReplyMessageItemBuilder;

  /// custom message builder, returns null means using default widget.
  final MessageItemContent? customMessageItemBuilder;

  /// image message builder, returns null means using default widget.
  final MessageItemContent? imageMessageItemBuilder;

  /// sound message builder, returns null means using default widget.
  final MessageItemContent? soundMessageItemBuilder;

  /// video message builder, returns null means using default widget.
  final MessageItemContent? videoMessageItemBuilder;

  /// file message builder, returns null means using default widget.
  final MessageItemContent? fileMessageItemBuilder;

  /// location message (LBS) item builder;
  /// recommend to use our LBS plug-in: https://pub.dev/packages/tim_ui_kit_lbs_plugin
  final MessageItemContent? locationMessageItemBuilder;

  /// face message, like emoji, message builder, returns null means using default widget.
  final MessageItemContent? faceMessageItemBuilder;

  /// group tips message builder, returns null means using default widget.
  final MessageItemContent? groupTipsMessageItemBuilder;

  /// merger message builder, returns null means using default widget.
  final MessageItemContent? mergerMessageItemBuilder;

  /// The builder for the whole message line, expect for those message type without avatar and nickname.
  /// [Update] You can only re-define the message types you need, returns null means using default row layout.
  final MessageRowBuilder? messageRowBuilder;

  /// The builder for content shown below the message bubble (e.g. delivery hints).
  final MessageBottomRowBuilder? messageBottomRowBuilder;

  /// message nick name builder
  final MessageNickNameBuilder? messageNickNameBuilder;

  final RenderingDirectionCallback? renderingDirectionCallback;

  MessageItemBuilder({
    this.locationMessageItemBuilder,
    this.textMessageItemBuilder,
    this.textReplyMessageItemBuilder,
    this.customMessageItemBuilder,
    this.imageMessageItemBuilder,
    this.soundMessageItemBuilder,
    this.videoMessageItemBuilder,
    this.fileMessageItemBuilder,
    this.faceMessageItemBuilder,
    this.groupTipsMessageItemBuilder,
    this.mergerMessageItemBuilder,
    this.messageRowBuilder,
    this.messageBottomRowBuilder,
    this.messageNickNameBuilder,
    this.renderingDirectionCallback,
  });
}

class MessageToolTipItem {
  final String label;
  final String id;
  final String? iconImageAsset;
  final IconData? icon;
  final Color? iconColor;
  final VoidCallback onClick;

  MessageToolTipItem({
    required this.label,
    required this.id,
    this.iconImageAsset,
    this.icon,
    this.iconColor,
    required this.onClick,
  }) : assert(
          icon != null ||
              (iconImageAsset != null && iconImageAsset!.isNotEmpty),
        );
}

class ToolTipsConfig {
  /// Whether to show the reply to a message option.
  bool showReplyMessage;

  /// Whether to show the multiple-choice option for messages.
  bool showMultipleChoiceMessage;

  /// Whether to show the option to delete a message.
  bool showDeleteMessage;

  /// Whether to show the option to recall a message.
  bool showRecallMessage;

  /// Whether to show the option to copy a message.
  bool showCopyMessage;

  /// Whether to show the option to forward a message.
  bool showForwardMessage;

  /// Whether to show the option to translate a text message. This module is not available by default. Please contact your Tencent Cloud sales representative or customer service team to enable this feature.
  bool showTranslation;

  /// A builder for additional custom items. We recommend using `additionalMessageToolTips` instead of this field since version 2.0, as you only need to provide the data rather than the whole widget. This makes usage easier and you don't need to worry about the UI display.
  final Widget? Function(V2TimMessage message, Function() closeTooltip,
      [Key? key, BuildContext? context])? additionalItemBuilder;

  /// A list of additional message tooltip menu items, provided with the data only. We recommend using this field instead of the previous `additionalItemBuilder`.
  List<MessageToolTipItem> Function(
      V2TimMessage message, Function() closeTooltip)? additionalMessageToolTips;

  ToolTipsConfig(
      {this.showDeleteMessage = true,
      this.showMultipleChoiceMessage = true,
      this.showRecallMessage = true,
      this.showReplyMessage = true,
      this.showTranslation = true,
      this.showCopyMessage = true,
      this.showForwardMessage = true,
      this.additionalMessageToolTips,
      @Deprecated(
          "Please use `additionalMessageToolTips` instead. You are now only expected to specify the data, rather than providing a whole widget. This makes usage easier, as you no longer need to worry about the UI display.")
      this.additionalItemBuilder});
}

class TIMUIKitHistoryMessageListItem extends StatefulWidget {
  /// message instance
  final V2TimMessage message;

  /// tap remote user avatar callback function
  final void Function(String userID, TapDownDetails tapDetails)?
      onTapForOthersPortrait;

  /// secondary tap remote user avatar callback function
  final void Function(String userID, TapDownDetails tapDetails)?
      onSecondaryTapForOthersPortrait;

  /// the function use for reply message, when click replied message can scroll to it.
  final Function? onScrollToIndex;

  /// message is too long should scroll this message to begin so that the tool tips panel can show correctly.
  final Function? onScrollToIndexBegin;

  /// the callback for long press event, except myself avatar
  final Function(String? userId, String? nickName)?
      onLongPressForOthersHeadPortrait;

  /// 鍥炲娑堟伅鏃?@ 瀵规柟
  final Function(String? userId, String? nickName)? onAtUserWhenReply;

  /// message item builder, works for customize all message types and row layout.
  final MessageItemBuilder? messageItemBuilder;

  /// Control avatar hide or show
  final bool showAvatar;

  /// message is read status
  final bool showMessageReadReceipt;

  /// allow message can long press
  final bool allowLongPress;

  /// allow avatar can tap
  final bool allowAvatarTap;

  /// Auto mention user when send reply message
  final bool allowAtUserWhenReply;

  @Deprecated(
      "Nickname will not show in one-to-one chat, if you tend to control it in group chat, please use `isShowSelfNameInGroup` and `isShowOthersNameInGroup` from `config: TIMUIKitChatConfig` instead")

  /// allow show user nick name
  final bool showNickName;

  /// on message long press callback
  final Function(BuildContext context, V2TimMessage message)? onLongPress;

  /// tool tips panel configuration, long press message will show tool tips panel
  final ToolTipsConfig? toolTipsConfig;

  /// padding for each message item
  final EdgeInsetsGeometry? padding;

  /// The controller for text field.
  final TIMUIKitInputTextFieldController? textFieldController;

  /// padding for text message銆乻ound message銆乺eply message
  final EdgeInsetsGeometry? textPadding;

  /// avatar builder
  final Widget Function(BuildContext context, V2TimMessage message)?
      userAvatarBuilder;

  /// theme info for message and avatar
  final MessageThemeData? themeData;

  /// builder for nick name row
  final Widget Function(BuildContext context, V2TimMessage message)?
      topRowBuilder;

  /// builder for bottom raw which under message content
  final Widget Function(BuildContext context, V2TimMessage message)?
      bottomRowBuilder;

  // open MessageReaction
  final bool? isUseMessageReaction;

  final List<CustomEmojiFaceData> customEmojiStickerList;

  final V2TimGroupMemberFullInfo? groupMemberInfo;

  /// This parameter accepts a custom widget to be displayed when the mouse hovers over a message,
  /// replacing the default message hover action bar.
  /// Applicable only on desktop platforms.
  /// If provided, the default message action functionality will appear in the right-click context menu instead.
  final Widget? Function(V2TimMessage message)? customMessageHoverBarOnDesktop;

  final RenderingDirectionCallback? renderingDirectionCallback;

  TIMUIKitHistoryMessageListItem({
    Key? key,
    required this.message,
    @Deprecated(
        "Nickname will not show in one-to-one chat, if you tend to control it in group chat, please use `isShowSelfNameInGroup` and `isShowOthersNameInGroup` from `config: TIMUIKitChatConfig` instead")
    this.showNickName = false,
    this.onScrollToIndex,
    this.onScrollToIndexBegin,
    this.onTapForOthersPortrait,
    this.messageItemBuilder,
    this.onLongPressForOthersHeadPortrait,
    this.onAtUserWhenReply,
    this.showAvatar = true,
    this.showMessageReadReceipt = true,
    this.allowLongPress = true,
    this.toolTipsConfig,
    this.onLongPress,
    this.allowAtUserWhenReply = true,
    this.allowAvatarTap = true,
    this.userAvatarBuilder,
    this.themeData,
    this.padding,
    this.textPadding,
    this.topRowBuilder,
    this.isUseMessageReaction,
    this.bottomRowBuilder,
    this.customEmojiStickerList = const [],
    this.textFieldController,
    this.onSecondaryTapForOthersPortrait,
    this.groupMemberInfo,
    this.customMessageHoverBarOnDesktop,
    this.renderingDirectionCallback,
  }) : super(key: key);

  @override
  State<StatefulWidget> createState() => _TIMUIKItHistoryMessageListItemState();
}

class TipsActionItem extends TIMUIKitStatelessWidget {
  final String label;
  final String icon;
  final String? package;

  TipsActionItem(
      {Key? key, required this.label, required this.icon, this.package})
      : super(key: key);

  @override
  Widget tuiBuild(BuildContext context, TUIKitBuildValue value) {
    return Column(
      children: [
        Image.asset(
          icon,
          package: package,
          width: 20,
          height: 20,
        ),
        const SizedBox(
          height: 4,
        ),
        Text(
          label,
          style: const TextStyle(
            decoration: TextDecoration.none,
            color: Color(0xFF444444),
            fontSize: 10,
          ),
        )
      ],
    );
  }
}

class _TIMUIKItHistoryMessageListItemState
    extends TIMUIKitState<TIMUIKitHistoryMessageListItem> {
  SuperTooltip? tooltip;
  OverlayEntry? _mobileTelegramMenuOverlay;
  OverlayEntry? _tooltipBlurOverlay;
  Rect? _tooltipBlurHoleRect;
  bool _tooltipLayoutSyncActive = false;
  Rect? _lastTooltipSyncAnchor;
  DateTime? _mobileMenuOpenedAt;
  bool _isBubbleExtracted = false;
  ui.Image? _contextMenuSnapshot;

  /// Tracks whether this item has called beginMessageContextMenuOverlay.
  bool _contextMenuPresentationActive = false;
  bool _contextMenuDismisserRegistered = false;

  late final VoidCallback _dismissContextMenuOverlays = () {
    closeTooltip();
  };

  // ignore: unused_field
  final MessageService _messageService = serviceLocator<MessageService>();
  final TUISelfInfoViewModel selfInfoModel =
      serviceLocator<TUISelfInfoViewModel>();
  final TUIThemeViewModel themeModel = serviceLocator<TUIThemeViewModel>();

  // bool isChecked = false;
  final GlobalKey _key = GlobalKey();
  final GlobalKey _messageBubbleKey = GlobalKey();
  final GlobalKey _messageExtractBoundaryKey = GlobalKey();
  bool isShowWideToolTip = false;
  bool _readReceiptVisibilityHandled = false;
  TapDownDetails? _tapDetails;
  final CoreServicesImpl _coreServicesImpl = serviceLocator<CoreServicesImpl>();

  double? _messageRowHeight() {
    final box = _key.currentContext?.findRenderObject() as RenderBox?;
    if (box?.hasSize == true) {
      return box!.size.height;
    }
    return context.size?.height;
  }

  Rect? _messageAnchorRect() {
    final bubbleContext =
        _messageBubbleKey.currentContext ?? _key.currentContext;
    final rootBox = bubbleContext?.findRenderObject() as RenderBox?;
    if (rootBox == null || !rootBox.hasSize) {
      return null;
    }
    return rootBox.localToGlobal(Offset.zero) & rootBox.size;
  }

  Rect _messageViewportRect() {
    final media = MediaQuery.of(context);
    // Prefer the chat list scrollable bounds (below AppBar). Using only
    // MediaQuery.padding.top lets long bubbles paint into the header.
    final scrollable = Scrollable.maybeOf(context);
    final scrollBox = scrollable?.context.findRenderObject() as RenderBox?;
    if (scrollBox != null && scrollBox.hasSize && scrollBox.attached) {
      final origin = scrollBox.localToGlobal(Offset.zero);
      final size = scrollBox.size;
      if (size.width > 1 && size.height > 1) {
        return origin & size;
      }
    }
    // Fallback when scrollable is unavailable: reserve status bar + toolbar.
    final top = media.padding.top + kToolbarHeight;
    return Rect.fromLTWH(
      0,
      top,
      media.size.width,
      media.size.height -
          top -
          media.padding.bottom -
          media.viewInsets.bottom,
    );
  }

  Rect? _visibleMessageAnchorRect() {
    final anchor = _messageAnchorRect();
    if (anchor == null) {
      return null;
    }
    final visible = anchor.intersect(_messageViewportRect());
    if (visible.width <= 0 || visible.height <= 0) {
      return anchor;
    }
    return visible;
  }

  Rect? _messageFullContentRect() {
    final anchor = _messageAnchorRect();
    final bubbleContext =
        _messageBubbleKey.currentContext ?? _key.currentContext;
    final root = bubbleContext?.findRenderObject();
    if (root != null) {
      final painted = _findBubblePaintRect(root);
      if (painted != null) {
        return painted;
      }
    }
    return _findMessageContentRect() ?? anchor;
  }

  bool _isSuperLongMessage([Rect? messageRect]) {
    final rect =
        messageRect ?? _messageFullContentRect() ?? _messageAnchorRect();
    if (rect == null) {
      return false;
    }
    return rect.height >= _messageViewportRect().height * 0.45;
  }

  /// iOS-Notes-style preview region for any super-long bubble (text, image,
  /// video, custom, ...): the reaction bar is pinned near the top, the action
  /// menu sits at the bottom, and the whole space in between is given to the
  /// (scrollable) full bubble snapshot. The bubble stops growing once it can be
  /// shown in full, so moderately long messages still get the menu directly
  /// below them.
  /// Whether we must use the combined bubble+menu scroll layout. This is only
  /// needed when the bubble together with the full action menu (and the
  /// optional reaction bar) cannot fit inside the safe content area at once.
  /// Everything that fits keeps the in-place menu, so the bubble is shown at its
  /// original position instead of being pinned to the top.
  bool _shouldUseScrollableMenu(
    Rect? boundaryRect,
    Rect? fullContentRect,
    bool showReaction,
  ) {
    final bubble = boundaryRect ?? fullContentRect;
    if (bubble == null) {
      // Without a reliable bubble rect, fall back to the height heuristic.
      return _isSuperLongMessage(fullContentRect);
    }
    const gap = 8.0;
    final menuHeight =
        TIMUIKitMessageTooltipState.estimateTelegramActionMenuHeight(
      _estimateMobileTooltipItemCount(_resolvedToolTipsConfig()),
    );
    final reactionBlock = showReaction
        ? TIMUIKitMessageTooltipState.mobileTelegramReactionBarHeight + gap
        : 0.0;
    final available = _chatContextMenuSafeBottom() - _chatContextMenuSafeTop();
    final needed = bubble.height + gap + menuHeight + reactionBlock;
    return needed > available;
  }

  Rect? _superLongPreviewRect({required bool showReaction}) {
    // Base the geometry on the bubble/boundary rect, which is exactly what the
    // captured snapshot contains 鈥?so its width/height always match (no squish
    // for red-packet / transfer / other custom cards).
    final full = _messageAnchorRect() ?? _messageFullContentRect();
    if (full == null) {
      return null;
    }
    const gap = 8.0;
    const minPreview = 160.0;
    final safeTop = _chatContextMenuSafeTop();
    final safeBottom = _chatContextMenuSafeBottom();
    final reactionBlock = showReaction
        ? TIMUIKitMessageTooltipState.mobileTelegramReactionBarHeight + gap
        : 0.0;
    final menuHeight =
        TIMUIKitMessageTooltipState.estimateTelegramActionMenuHeight(
      _estimateMobileTooltipItemCount(_resolvedToolTipsConfig()),
    );

    final top = safeTop + reactionBlock;
    var bottom = safeBottom - menuHeight - gap;
    // Don't reserve more height than the bubble actually needs.
    if (bottom - top > full.height) {
      bottom = top + full.height;
    }
    if (bottom - top < minPreview) {
      bottom = min(safeBottom - gap, top + minPreview);
    }
    return Rect.fromLTRB(full.left, top, full.right, bottom);
  }

  Rect _extractedWindowAtPointer(
    Offset pointer,
    Rect full,
    Rect viewport,
  ) {
    final visible = full.intersect(viewport);
    final base = visible.width > 0 && visible.height > 0 ? visible : full;
    const minHeight = 88.0;
    final maxHeight = min(viewport.height * 0.42, 240.0);
    final height = max(minHeight, min(maxHeight, base.height));
    final centerY = pointer.dy.clamp(
      base.top + height * 0.5,
      base.bottom - height * 0.5,
    );
    var top = centerY - height / 2;
    var bottom = centerY + height / 2;
    top = max(top, base.top);
    bottom = min(bottom, base.bottom);
    return Rect.fromLTRB(full.left, top, full.right, bottom);
  }

  Rect? _messageExtractedContentRect() {
    final full = _messageFullContentRect() ?? _messageAnchorRect();
    if (full == null) {
      return null;
    }
    final viewport = _messageViewportRect();
    final pointer = _tapDetails?.globalPosition;

    if (_isSuperLongMessage(full) && pointer != null) {
      return _extractedWindowAtPointer(pointer, full, viewport);
    }

    final visible = full.intersect(viewport);
    if (visible.width > 0 && visible.height > 0) {
      return visible;
    }
    return full;
  }

  Rect? _messageMenuPlacementAnchor() {
    final fullContent = _messageFullContentRect();
    final viewport = _messageViewportRect();
    final pointer = _tapDetails?.globalPosition;

    if (fullContent != null &&
        pointer != null &&
        _isSuperLongMessage(fullContent)) {
      return _extractedWindowAtPointer(pointer, fullContent, viewport);
    }

    final content = _findMessageContentRect();
    if (content != null) {
      if (_shouldUsePointerMenuAnchor(content) && pointer != null) {
        return _menuPlacementBandAtPointer(
            pointer, fullContent ?? content, viewport);
      }
      return content;
    }

    final extracted = _messageExtractedContentRect();
    if (extracted != null) {
      return extracted;
    }

    final anchor = _visibleMessageAnchorRect() ?? _messageAnchorRect();
    if (anchor != null) {
      return anchor.intersect(viewport).width > 0
          ? anchor.intersect(viewport)
          : anchor;
    }

    if (pointer == null) {
      return null;
    }
    return Rect.fromCenter(
      center: pointer,
      width: 160,
      height: 48,
    );
  }

  bool _isMediaMessage(V2TimMessage message) {
    return message.elemType == MessageElemType.V2TIM_ELEM_TYPE_IMAGE ||
        message.elemType == MessageElemType.V2TIM_ELEM_TYPE_VIDEO ||
        message.elemType == MessageElemType.V2TIM_ELEM_TYPE_SOUND;
  }

  bool _shouldUsePointerMenuAnchor(Rect content) {
    final viewport = _messageViewportRect();
    final full = _messageFullContentRect() ?? content;
    if (_isSuperLongMessage(full)) {
      return true;
    }
    if (_isViewportTallMessage(full)) {
      return true;
    }
    if (!_isMediaMessage(widget.message)) {
      return false;
    }
    if (content.height > viewport.height * 0.42) {
      return true;
    }
    if (_chatContextMenuSafeBottom() - content.bottom < 120) {
      return true;
    }
    final pointer = _tapDetails?.globalPosition;
    if (pointer == null) {
      return false;
    }
    final spaceBelow = _chatContextMenuSafeBottom() - content.bottom;
    final spaceAbove = content.top - _chatContextMenuSafeTop();
    return spaceBelow < 280 && spaceAbove >= spaceBelow;
  }

  Rect _menuPlacementBandAtPointer(
    Offset pointer,
    Rect content,
    Rect viewport,
  ) {
    const bandHeight = 52.0;
    final safeTop = _chatContextMenuSafeTop();
    final safeBottom = _chatContextMenuSafeBottom();
    final centerY = pointer.dy.clamp(
      content.top + bandHeight * 0.5,
      content.bottom - bandHeight * 0.5,
    );
    var top = centerY - bandHeight / 2;
    var bottom = centerY + bandHeight / 2;
    if (top < safeTop) {
      top = safeTop;
      bottom = top + bandHeight;
    }
    if (bottom > safeBottom) {
      bottom = safeBottom;
      top = bottom - bandHeight;
    }
    return Rect.fromLTRB(content.left, top, content.right, bottom);
  }

  Rect? _findMessageContentRect() {
    final bubbleContext =
        _messageBubbleKey.currentContext ?? _key.currentContext;
    final root = bubbleContext?.findRenderObject();
    if (root == null) {
      return null;
    }

    final screenWidth = MediaQuery.sizeOf(context).width;
    final maxBubbleWidth = screenWidth * 0.82;
    final viewport = _messageViewportRect();
    final pointer = _tapDetails?.globalPosition;
    final mediaCandidates = <Rect>[];
    final decoratedCandidates = <Rect>[];

    void visit(RenderObject object) {
      if (object is! RenderBox || !object.hasSize) {
        object.visitChildren(visit);
        return;
      }

      final rect = object.localToGlobal(Offset.zero) & object.size;
      if (rect.width > maxBubbleWidth || rect.width < 20) {
        object.visitChildren(visit);
        return;
      }

      if (object is RenderImage &&
          rect.width >= 40 &&
          rect.height >= 40 &&
          rect.height <= viewport.height * 0.98) {
        mediaCandidates.add(rect);
      }

      if (object is RenderDecoratedBox) {
        final decoration = object.decoration;
        if (decoration is BoxDecoration) {
          final color = decoration.color;
          if (color != null &&
              color.a > 0 &&
              rect.height >= 14 &&
              rect.height <= viewport.height * 0.98) {
            decoratedCandidates.add(rect);
          }
        }
      }

      if (rect.width >= 60 &&
          rect.height >= 60 &&
          rect.height <= viewport.height * 0.98) {
        final aspect = rect.width / rect.height;
        if (aspect > 0.15 && aspect < 6) {
          mediaCandidates.add(rect);
        }
      }

      object.visitChildren(visit);
    }

    visit(root);

    Rect? pickBest(List<Rect> candidates) {
      if (candidates.isEmpty) {
        return null;
      }
      if (pointer != null) {
        final hit = candidates
            .where((rect) => rect.contains(pointer))
            .toList(growable: false);
        if (hit.isNotEmpty) {
          hit.sort(
            (a, b) => (b.width * b.height).compareTo(a.width * a.height),
          );
          return hit.first;
        }
      }
      candidates.sort(
        (a, b) => (b.width * b.height).compareTo(a.width * a.height),
      );
      return candidates.first;
    }

    return pickBest(mediaCandidates) ?? pickBest(decoratedCandidates);
  }

  Rect? _messageMenuAnchorRect() => _messageMenuPlacementAnchor();

  double _chatContextMenuSafeTop() {
    final viewportTop = _messageViewportRect().top;
    final media = MediaQuery.of(context);
    // Never claim the status-bar + AppBar band even if scrollable lookup fails.
    final chromeFloor = media.padding.top + kToolbarHeight;
    return max(viewportTop, chromeFloor) + 6;
  }

  double _chatContextMenuSafeBottom() {
    final viewport = _messageViewportRect();
    final media = MediaQuery.of(context);
    final inputAnchor = ChatMessageInputAnchor.maybeOf(context);
    if (inputAnchor != null) {
      final box = inputAnchor.inputAnchorKey.currentContext?.findRenderObject()
          as RenderBox?;
      if (box != null && box.hasSize) {
        final inputTop = box.localToGlobal(Offset.zero).dy;
        if (inputTop > viewport.top && inputTop < media.size.height) {
          return inputTop - 6;
        }
      }
    }
    return viewport.bottom - 6;
  }

  Rect _chatContextMenuContentArea() {
    final media = MediaQuery.sizeOf(context);
    return Rect.fromLTRB(
      0,
      _chatContextMenuSafeTop(),
      media.width,
      _chatContextMenuSafeBottom(),
    );
  }

  OverlayState _rootOverlayState() {
    return Overlay.of(context, rootOverlay: true);
  }

  Future<void> _triggerMobileBubbleContextMenu(
    BuildContext bubbleContext,
    V2TimMessage message,
    TUIChatSeparateViewModel model,
    TUITheme theme,
  ) async {
    if (widget.onLongPress != null) {
      widget.onLongPress!(bubbleContext, message);
      return;
    }
    if (!widget.allowLongPress) {
      return;
    }
    await _onOpenToolTip(
      bubbleContext,
      message,
      model,
      theme,
      _tapDetails,
      false,
      false,
    );
  }

  void _openMobileTelegramContextMenu({
    required V2TimMessage message,
    required TUIChatSeparateViewModel model,
    required ToolTipsConfig toolTipsConfig,
    required bool isUseMessageReaction,
  }) {
    // 长按后立刻屏蔽气泡内 tap（红包/转账卡片等），避免菜单弹出前后误触进详情。
    _beginMessageContextMenuOverlayPresentation();
    void present() {
      if (!mounted) {
        _endMessageContextMenuOverlayPresentation();
        return;
      }
      unawaited(_presentMobileTelegramContextMenu(
        message: message,
        model: model,
        toolTipsConfig: toolTipsConfig,
        isUseMessageReaction: isUseMessageReaction,
      ));
    }

    if (_isMessageBubbleLaidOut()) {
      present();
      return;
    }
    // IntrinsicWidth / freshly inserted voice bubbles may need one frame.
    WidgetsBinding.instance.addPostFrameCallback((_) => present());
  }

  void _dismissTooltipIfAllowed() {
    if (_mobileMenuOpenedAt != null &&
        DateTime.now().difference(_mobileMenuOpenedAt!) <
            const Duration(milliseconds: 320)) {
      return;
    }
    closeTooltip();
  }

  bool _isViewportTallMessage([Rect? messageRect]) {
    final rect = messageRect ?? _messageAnchorRect();
    if (rect == null) {
      return false;
    }
    final viewport = _messageViewportRect();
    return rect.height >= viewport.height * 0.68;
  }

  Offset _clampTooltipPointer(Offset pointer) {
    final viewport = _messageViewportRect();
    const horizontalPadding = 16.0;
    return Offset(
      pointer.dx.clamp(horizontalPadding, viewport.width - horizontalPadding),
      pointer.dy.clamp(viewport.top + 8, viewport.bottom - 8),
    );
  }

  bool _isMessageBubbleLaidOut() {
    final anchor = _messageAnchorRect();
    return anchor != null && anchor.width > 1 && anchor.height > 1;
  }

  /// Fallback bubble bounds when [RepaintBoundary] has not finished layout yet
  /// (common for freshly sent voice messages using [IntrinsicWidth]).
  Rect? _pointerFallbackBubbleRect({V2TimMessage? message}) {
    final pointer = _tapDetails?.globalPosition;
    if (pointer == null) {
      return null;
    }
    final clamped = _clampTooltipPointer(pointer);
    const fallbackHeight = 52.0;
    const minWidth = 120.0;
    const maxWidth = 220.0;
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isSelf = (message ?? widget.message).isSelf ?? true;
    final width = min(maxWidth, max(minWidth, screenWidth * 0.42));
    final left = isSelf
        ? (clamped.dx - width).clamp(8.0, screenWidth - width - 8.0)
        : clamped.dx.clamp(8.0, screenWidth - width - 8.0);
    final top = (clamped.dy - fallbackHeight / 2).clamp(
      _chatContextMenuSafeTop(),
      _chatContextMenuSafeBottom() - fallbackHeight,
    );
    return Rect.fromLTWH(left, top, width, fallbackHeight);
  }

  ({Rect extracted, Rect layout})? _resolveMobileContextMenuRects({
    required V2TimMessage message,
    Rect? previewRect,
    Rect? boundaryRect,
  }) {
    var extractedRect =
        previewRect ?? boundaryRect ?? _messageExtractedContentRect();
    var layoutAnchor = previewRect ??
        boundaryRect ??
        _messageMenuAnchorRect() ??
        extractedRect;

    if (extractedRect == null && layoutAnchor != null) {
      extractedRect = layoutAnchor;
    }
    if (layoutAnchor == null && extractedRect != null) {
      layoutAnchor = extractedRect;
    }
    if (extractedRect == null || layoutAnchor == null) {
      final fallback = _pointerFallbackBubbleRect(message: message);
      if (fallback == null) {
        return null;
      }
      extractedRect = fallback;
      layoutAnchor = fallback;
    }

    return (extracted: extractedRect, layout: layoutAnchor);
  }

  Rect? _messageHighlightRect() => _messageExtractedContentRect();

  Rect? _findBubblePaintRect(RenderObject root) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final maxBubbleWidth = screenWidth * 0.82;
    final candidates = <Rect>[];

    void visit(RenderObject object) {
      if (object is RenderDecoratedBox) {
        final decoration = object.decoration;
        Color? color;
        if (decoration is BoxDecoration) {
          color = decoration.color;
        }
        if (color != null && color.alpha > 0) {
          final box = object as RenderBox;
          if (box.hasSize) {
            final rect = box.localToGlobal(Offset.zero) & box.size;
            if (rect.width <= maxBubbleWidth &&
                rect.width >= 20 &&
                rect.height >= 14) {
              candidates.add(rect);
            }
          }
        }
      }
      object.visitChildren(visit);
    }

    visit(root);

    if (candidates.isEmpty) {
      return null;
    }

    candidates
        .sort((a, b) => (b.width * b.height).compareTo(a.width * a.height));
    return candidates.first;
  }

  void _stopTooltipLayoutSync() {
    _tooltipLayoutSyncActive = false;
    _lastTooltipSyncAnchor = null;
  }

  bool _tooltipAnchorMoved(Rect? anchor) {
    final previous = _lastTooltipSyncAnchor;
    if (anchor == null && previous == null) {
      return false;
    }
    if (anchor == null || previous == null) {
      return true;
    }
    final delta = (anchor.topLeft - previous.topLeft).distance +
        (anchor.bottomRight - previous.bottomRight).distance;
    return delta > 0.5;
  }

  void _startTooltipLayoutSync(BuildContext context) {
    if (_tooltipLayoutSyncActive) {
      return;
    }
    _tooltipLayoutSyncActive = true;
    _lastTooltipSyncAnchor = _messageAnchorRect();
    _scheduleTooltipLayoutTick(context);
  }

  void _scheduleTooltipLayoutTick(BuildContext context) {
    if (!_tooltipLayoutSyncActive || !mounted) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_tooltipLayoutSyncActive || !mounted) {
        _tooltipLayoutSyncActive = false;
        return;
      }
      final menuOpen =
          _mobileTelegramMenuOverlay != null || (tooltip?.isOpen ?? false);
      if (!menuOpen) {
        _tooltipLayoutSyncActive = false;
        _lastTooltipSyncAnchor = null;
        return;
      }

      final globalModel = serviceLocator<TUIChatGlobalModel>();
      if (globalModel.isChatListUserScrolling &&
          _mobileTelegramMenuOverlay != null) {
        closeTooltip();
        return;
      }

      final anchor = _messageAnchorRect();
      if (_tooltipAnchorMoved(anchor)) {
        _lastTooltipSyncAnchor = anchor;
        if (_mobileTelegramMenuOverlay != null) {
          _mobileTelegramMenuOverlay?.markNeedsBuild();
        } else if (tooltip?.isOpen ?? false) {
          _showTooltipBlurOverlay(context);
        }
      }
      _scheduleTooltipLayoutTick(context);
    });
  }

  void _removeMobileTelegramMenuOverlay() {
    _mobileTelegramMenuOverlay?.remove();
    _mobileTelegramMenuOverlay = null;
  }

  void _registerContextMenuOverlayDismisser() {
    if (_contextMenuDismisserRegistered) {
      return;
    }
    _contextMenuDismisserRegistered = true;
    serviceLocator<TUIChatGlobalModel>().registerContextMenuOverlayDismisser(
      _dismissContextMenuOverlays,
    );
  }

  void _unregisterContextMenuOverlayDismisser() {
    if (!_contextMenuDismisserRegistered) {
      return;
    }
    _contextMenuDismisserRegistered = false;
    serviceLocator<TUIChatGlobalModel>().unregisterContextMenuOverlayDismisser(
      _dismissContextMenuOverlays,
    );
  }

  void _beginMessageContextMenuOverlayPresentation() {
    if (_contextMenuPresentationActive) {
      return;
    }
    _contextMenuPresentationActive = true;
    serviceLocator<TUIChatGlobalModel>().beginMessageContextMenuOverlay();
    if (mounted) {
      setState(() {});
    }
  }

  void _endMessageContextMenuOverlayPresentation() {
    if (!_contextMenuPresentationActive) {
      return;
    }
    _contextMenuPresentationActive = false;
    String? conversationID;
    if (mounted) {
      try {
        conversationID =
            context.read<TUIChatSeparateViewModel>().conversationID;
      } catch (_) {
        conversationID =
            serviceLocator<TUIChatGlobalModel>().currentSelectedConv;
      }
    } else {
      conversationID = serviceLocator<TUIChatGlobalModel>().currentSelectedConv;
    }
    serviceLocator<TUIChatGlobalModel>().endMessageContextMenuOverlay(
      conversationID: conversationID,
    );
    if (mounted) {
      setState(() {});
    }
  }

  void _removeTooltipBlurOverlay() {
    _stopTooltipLayoutSync();
    _removeMobileTelegramMenuOverlay();
    _tooltipBlurOverlay?.remove();
    _tooltipBlurOverlay = null;
    _tooltipBlurHoleRect = null;
    _mobileMenuOpenedAt = null;
    _contextMenuSnapshot?.dispose();
    _contextMenuSnapshot = null;
    _unregisterContextMenuOverlayDismisser();
    if (_isBubbleExtracted && mounted) {
      setState(() {
        _isBubbleExtracted = false;
      });
    } else {
      _isBubbleExtracted = false;
    }
    _endMessageContextMenuOverlayPresentation();
  }

  void _showTooltipBlurOverlay(BuildContext context) {
    final holeRect = _messageHighlightRect();
    if (holeRect == null) {
      return;
    }

    _tooltipBlurHoleRect = holeRect;
    if (_tooltipBlurOverlay != null) {
      _tooltipBlurOverlay!.markNeedsBuild();
      return;
    }

    _tooltipBlurOverlay = OverlayEntry(
      builder: (overlayContext) {
        final rect = _tooltipBlurHoleRect;
        if (rect == null) {
          return const SizedBox.shrink();
        }
        return _MessageTooltipBlurOverlay(
          holeRect: rect,
          onDismiss: _dismissTooltipIfAllowed,
        );
      },
    );
    _rootOverlayState().insert(_tooltipBlurOverlay!);
    _registerContextMenuOverlayDismisser();
  }

  closeTooltip() {
    tooltip?.close();
    _removeTooltipBlurOverlay();
  }

  Future<void> _presentMobileTelegramContextMenu({
    required V2TimMessage message,
    required TUIChatSeparateViewModel model,
    required ToolTipsConfig toolTipsConfig,
    required bool isUseMessageReaction,
    int layoutRetryCount = 0,
  }) async {
    if (!_isMessageBubbleLaidOut() && layoutRetryCount < 3) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          _endMessageContextMenuOverlayPresentation();
          return;
        }
        unawaited(_presentMobileTelegramContextMenu(
          message: message,
          model: model,
          toolTipsConfig: toolTipsConfig,
          isUseMessageReaction: isUseMessageReaction,
          layoutRetryCount: layoutRetryCount + 1,
        ));
      });
      return;
    }

    final fullContentRect = _messageFullContentRect();
    final boundaryRect = _messageAnchorRect();
    // Only fall back to the combined "bubble + menu scroll together" layout when
    // the bubble and the full action menu genuinely cannot both fit inside the
    // safe area (very tall text / image / video / card ...). Short messages keep
    // the in-place menu so the bubble stays where it is instead of jumping to
    // the top with a large empty area below.
    final useScrollableMenu = _shouldUseScrollableMenu(
        boundaryRect, fullContentRect, isUseMessageReaction);
    final previewRect = useScrollableMenu
        ? _superLongPreviewRect(showReaction: isUseMessageReaction)
        : null;

    // The snapshot is the full RepaintBoundary, so display it at the bubble
    // rect (its true bounds) to avoid any BoxFit.fill distortion. Anchor the
    // in-place menu to the whole bubble too, so it never overlaps a sub-element
    // of a custom card.
    final resolvedRects = _resolveMobileContextMenuRects(
      message: message,
      previewRect: previewRect,
      boundaryRect: boundaryRect,
    );
    if (resolvedRects == null) {
      _endMessageContextMenuOverlayPresentation();
      return;
    }
    final extractedRect = resolvedRects.extracted;
    final layoutAnchor = resolvedRects.layout;

    final openedAt = DateTime.now();
    _mobileMenuOpenedAt = openedAt;
    _contextMenuSnapshot?.dispose();
    _contextMenuSnapshot = null;
    _removeMobileTelegramMenuOverlay();
    _beginMessageContextMenuOverlayPresentation();

    final longPressY = _tapDetails?.globalPosition.dy;

    void insertMenuOverlay() {
      _mobileTelegramMenuOverlay = OverlayEntry(
        builder: (overlayContext) {
          final liveExtracted =
              previewRect ?? _messageAnchorRect() ?? extractedRect;
          final liveLayout =
              previewRect ?? _messageAnchorRect() ?? layoutAnchor;
          final source = TelegramMessageContextSource(
            extractedContentRect: liveExtracted,
            layoutAnchorRect: liveLayout,
            contentAreaInScreenSpace: _chatContextMenuContentArea(),
            isSelf: message.isSelf ?? true,
            scrollableFullContentRect: useScrollableMenu
                ? (_messageFullContentRect() ?? fullContentRect)
                : null,
            longPressGlobalY: longPressY,
          );
          return TelegramMessageContextController(
            source: source,
            extractedSnapshot: _contextMenuSnapshot,
            message: message,
            model: model,
            toolTipsConfig: toolTipsConfig,
            estimatedMenuItemCount:
                _estimateMobileTooltipItemCount(toolTipsConfig),
            showQuickReactionBar: isUseMessageReaction,
            allowAtUserWhenReply: widget.allowAtUserWhenReply,
            onLongPressForOthersHeadPortrait:
                widget.onLongPressForOthersHeadPortrait,
            onAtUserWhenReply: widget.onAtUserWhenReply,
            groupMemberInfo: widget.groupMemberInfo,
            iSUseDefaultHoverBar:
                model.chatConfig.isUseMessageHoverBarOnDesktop &&
                    widget.customMessageHoverBarOnDesktop == null,
            openedAt: openedAt,
            onDismiss: closeTooltip,
            onSelectSticker: _clickOnCurrentSticker,
          );
        },
      );
      _rootOverlayState().insert(_mobileTelegramMenuOverlay!);
      _startTooltipLayoutSync(context);
      _registerContextMenuOverlayDismisser();
    }

    Future<ui.Image?> captureMenuSnapshot() {
      return TelegramMessageContextController.captureSnapshot(
        _messageExtractBoundaryKey,
        context,
        maxPixelRatio:
            TelegramMessageContextController.menuCaptureMaxPixelRatio,
      );
    }

    // Super-long scrollable menus need the bitmap before insert. Ordinary
    // bubbles insert the menu first so open is not gated on toImage.
    if (useScrollableMenu) {
      final snapshot = await captureMenuSnapshot();
      if (!mounted) {
        snapshot?.dispose();
        _endMessageContextMenuOverlayPresentation();
        return;
      }
      _contextMenuSnapshot = snapshot;
      if (snapshot != null) {
        setState(() {
          _isBubbleExtracted = true;
        });
      }
      insertMenuOverlay();
      return;
    }

    insertMenuOverlay();
    final captureOpenedAt = openedAt;
    unawaited(() async {
      final snapshot = await captureMenuSnapshot();
      if (!mounted ||
          _mobileMenuOpenedAt != captureOpenedAt ||
          _mobileTelegramMenuOverlay == null) {
        snapshot?.dispose();
        return;
      }
      _contextMenuSnapshot?.dispose();
      _contextMenuSnapshot = snapshot;
      if (snapshot != null) {
        setState(() {
          _isBubbleExtracted = true;
        });
      }
      _mobileTelegramMenuOverlay?.markNeedsBuild();
    }());
  }

  bool isReplyMessage(V2TimMessage message) {
    final hasCustomData =
        message.cloudCustomData != null && message.cloudCustomData != "";
    if (hasCustomData) {
      try {
        final CloudCustomData messageCloudCustomData = CloudCustomData.fromJson(
            json.decode(
                TencentUtils.checkString(message.cloudCustomData) != null
                    ? message.cloudCustomData!
                    : "{}"));
        if (messageCloudCustomData.messageReply != null) {
          MessageRepliedData.fromJson(messageCloudCustomData.messageReply!);
          return true;
        }
        return false;
      } catch (error) {
        return false;
      }
    }
    return false;
  }

  (bool isRevoke, bool isRevokeByAdmin) isRevokeMessage(
      V2TimMessage message, TUIChatSeparateViewModel model) {
    if (message.status == 6) {
      return (true, false);
    }
    if (!model.chatConfig.isGroupAdminRecallEnabled) {
      return (false, false);
    }

    Map<String, dynamic>? parseCustomData(String? raw) {
      final value = raw?.trim();
      if (value == null || value.isEmpty) {
        return null;
      }
      final decoded = jsonDecode(value);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
      return null;
    }

    try {
      Map<String, dynamic>? customData =
          parseCustomData(message.cloudCustomData);
      if (customData == null &&
          (message.messageFromWeb?.trim().isNotEmpty ?? false)) {
        final webMessage = parseCustomData(message.messageFromWeb);
        final webCloudCustomData = webMessage?["cloudCustomData"]?.toString();
        customData = parseCustomData(webCloudCustomData);
      }
      final isRevoke = customData?["isRevoke"] == true;
      final revokeByAdmin = customData?["revokeByAdmin"] == true;
      return (isRevoke, revokeByAdmin);
    } catch (e) {
      return (false, false);
    }
  }

  Widget _safeUnsupportedMessage(String label) {
    final bg =
        widget.themeData?.messageBackgroundColor ?? const Color(0xFFF2F3F5);
    final radius =
        widget.themeData?.messageBorderRadius ?? BorderRadius.circular(8);
    final style = widget.themeData?.messageTextStyle ??
        const TextStyle(fontSize: 14, color: Color(0xFF666666));
    return Container(
      padding: widget.textPadding ??
          const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(color: bg, borderRadius: radius),
      child: Text(TIM_t(label), style: style),
    );
  }

  bool _hasUsableImage(V2TimMessage message) {
    final elem = message.imageElem;
    if (elem != null) {
      final path = TencentUtils.checkString(elem.path);
      if (path != null) return true;
      final list = elem.imageList;
      if (list != null && list.isNotEmpty) {
        if (list.any((img) =>
            TencentUtils.checkString(img?.url) != null ||
            TencentUtils.checkString(img?.localUrl) != null ||
            TencentUtils.checkString(img?.uuid) != null)) {
          return true;
        }
      }
    }
    if (message.elemType != MessageElemType.V2TIM_ELEM_TYPE_IMAGE) {
      return false;
    }
    // 自己发送中：SDK 可能尚未回填 path/imageList，不应展示「不可用」文案。
    if (message.isSelf == true &&
        message.status == MessageStatus.V2TIM_MSG_STATUS_SENDING) {
      return true;
    }
    final globalModel = serviceLocator<TUIChatGlobalModel>();
    for (final key in [message.id, message.msgID]) {
      final id = TencentUtils.checkString(key);
      if (id != null &&
          globalModel.getFileMessageLocation(id).trim().isNotEmpty) {
        return true;
      }
    }
    return false;
  }

  bool _hasUsableVideo(V2TimMessage message) {
    final elem = message.videoElem;
    if (elem == null) return false;
    return TencentUtils.checkString(elem.videoUrl) != null ||
        TencentUtils.checkString(elem.videoPath) != null ||
        TencentUtils.checkString(elem.localVideoUrl) != null ||
        TencentUtils.checkString(elem.UUID) != null;
  }

  bool _hasUsableFile(V2TimMessage message) {
    final elem = message.fileElem;
    if (elem == null) return false;
    return TencentUtils.checkString(elem.fileName) != null ||
        TencentUtils.checkString(elem.path) != null ||
        TencentUtils.checkString(elem.localUrl) != null ||
        TencentUtils.checkString(elem.url) != null ||
        TencentUtils.checkString(elem.UUID) != null;
  }

  /// Some web/history messages keep [elemType] but drop nested elems; recover
  /// sound payload from [V2TimMessage.messageFromWeb] when possible.
  void _tryHydrateSoundElem(V2TimMessage message) {
    if (message.soundElem != null) {
      return;
    }
    if (message.elemType != MessageElemType.V2TIM_ELEM_TYPE_SOUND) {
      return;
    }
    final raw = message.messageFromWeb?.trim();
    if (raw == null || raw.isEmpty) {
      return;
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        return;
      }
      final map = Map<String, dynamic>.from(decoded);
      final payloadRaw = map['payload'];
      if (payloadRaw is! Map) {
        return;
      }
      final payload = Map<String, dynamic>.from(payloadRaw);
      message.soundElem = V2TimSoundElem(
        localUrl: payload['url']?.toString(),
        url: payload['remoteAudioUrl']?.toString() ??
            payload['audioUrl']?.toString() ??
            payload['url']?.toString(),
        dataSize: int.tryParse(payload['size']?.toString() ?? ''),
        duration: int.tryParse(payload['second']?.toString() ?? ''),
        UUID: payload['uuid']?.toString(),
      );
    } catch (_) {
      // Malformed web snapshot: keep fallback label below.
    }
  }

  Widget _messageItemBuilder(
      V2TimMessage messageItem, TUIChatSeparateViewModel model) {
    final msgType = messageItem.elemType;
    final isShowJump = (model.jumpMsgID == messageItem.msgID) &&
        (messageItem.msgID?.isNotEmpty ?? false);
    final MessageItemBuilder? messageItemBuilder = widget.messageItemBuilder;

    RenderingDirectionResult? overrideIsSelfResult;
    if (widget.renderingDirectionCallback != null) {
      overrideIsSelfResult = widget.renderingDirectionCallback!(messageItem);
    }

    bool isFromSelf = true;
    if (overrideIsSelfResult != null && overrideIsSelfResult.isSelf != null) {
      isFromSelf = overrideIsSelfResult.isSelf!;
    } else {
      isFromSelf = messageItem.isSelf ?? true;
    }

    void clearJump() {
      Future.delayed(const Duration(milliseconds: 100), () {
        model.jumpMsgID = "";
      });
    }

    switch (msgType) {
      case MessageElemType.V2TIM_ELEM_TYPE_CUSTOM:
        final customWidget =
            messageItemBuilder?.customMessageItemBuilder != null
                ? messageItemBuilder!.customMessageItemBuilder!(
                    messageItem,
                    isShowJump,
                    () => model.jumpMsgID = "",
                  )
                : null;
        return customWidget ??
            TIMUIKitCustomElem(
              message: messageItem,
              customElem: messageItem.customElem,
              isFromSelf: isFromSelf,
              messageBackgroundColor: widget.themeData?.messageBackgroundColor,
              messageBorderRadius: widget.themeData?.messageBorderRadius,
              messageFontStyle: widget.themeData?.messageTextStyle,
              textPadding: widget.textPadding,
              isShowMessageReaction: widget.isUseMessageReaction,
            );
      case MessageElemType.V2TIM_ELEM_TYPE_SOUND:
        _tryHydrateSoundElem(messageItem);
        if (messageItem.soundElem == null) {
          return _safeUnsupportedMessage(TIM_t("[语音消息不可用]"));
        }
        final customWidget = messageItemBuilder?.soundMessageItemBuilder != null
            ? messageItemBuilder!.soundMessageItemBuilder!(
                messageItem,
                isShowJump,
                () => model.jumpMsgID = "",
              )
            : null;
        return customWidget ??
            TIMUIKitSoundElem(
              chatModel: model,
              message: messageItem,
              soundElem: messageItem.soundElem!,
              msgID: messageItem.msgID ?? "",
              isFromSelf: isFromSelf,
              clearJump: clearJump,
              isShowJump: isShowJump,
              localCustomInt: messageItem.localCustomInt,
              borderRadius: widget.themeData?.messageBorderRadius,
              fontStyle: widget.themeData?.messageTextStyle,
              backgroundColor: widget.themeData?.messageBackgroundColor,
              textPadding: widget.textPadding,
              isShowMessageReaction: widget.isUseMessageReaction,
            );
      case MessageElemType.V2TIM_ELEM_TYPE_TEXT:
        if (isReplyMessage(messageItem)) {
          final customWidget =
              messageItemBuilder?.textReplyMessageItemBuilder != null
                  ? messageItemBuilder!.textReplyMessageItemBuilder!(
                      messageItem,
                      isShowJump,
                      () => model.jumpMsgID = "",
                    )
                  : null;
          return customWidget ??
              TIMUIKitReplyElem(
                message: messageItem,
                clearJump: clearJump,
                isShowJump: isShowJump,
                scrollToIndex: widget.onScrollToIndex ?? () {},
                borderRadius: widget.themeData?.messageBorderRadius,
                fontStyle: widget.themeData?.messageTextStyle,
                backgroundColor: widget.themeData?.messageBackgroundColor,
                textPadding: widget.textPadding,
                customEmojiStickerList: widget.customEmojiStickerList,
                chatModel: model,
                isShowMessageReaction: widget.isUseMessageReaction,
              );
        }
        final customWidget = messageItemBuilder?.textMessageItemBuilder != null
            ? messageItemBuilder!.textMessageItemBuilder!(
                messageItem,
                isShowJump,
                () => model.jumpMsgID = "",
              )
            : null;
        return customWidget ??
            TIMUIKitTextElem(
              chatModel: model,
              message: messageItem,
              isFromSelf: isFromSelf,
              clearJump: clearJump,
              isShowJump: isShowJump,
              borderRadius: widget.themeData?.messageBorderRadius,
              fontStyle: widget.themeData?.messageTextStyle,
              backgroundColor: widget.themeData?.messageBackgroundColor,
              textPadding: widget.textPadding,
              isShowMessageReaction: widget.isUseMessageReaction,
              customEmojiStickerList: widget.customEmojiStickerList,
            );
      case MessageElemType.V2TIM_ELEM_TYPE_FACE:
        if (messageItem.faceElem == null) {
          return _safeUnsupportedMessage(TIM_t("[表情消息不可用]"));
        }
        final customWidget = messageItemBuilder?.faceMessageItemBuilder != null
            ? messageItemBuilder!.faceMessageItemBuilder!(
                messageItem,
                isShowJump,
                () => model.jumpMsgID = "",
              )
            : null;
        return customWidget ??
            TIMUIKitFaceElem(
              model: model,
              path: messageItem.faceElem!.data ?? "",
              clearJump: clearJump,
              isShowJump: isShowJump,
              message: messageItem,
              isShowMessageReaction: widget.isUseMessageReaction,
            );
      case MessageElemType.V2TIM_ELEM_TYPE_FILE:
        if (!_hasUsableFile(messageItem)) {
          return _safeUnsupportedMessage(TIM_t("[文件消息不可用]"));
        }
        final customWidget = messageItemBuilder?.fileMessageItemBuilder != null
            ? messageItemBuilder!.fileMessageItemBuilder!(
                messageItem,
                isShowJump,
                () => model.jumpMsgID = "",
              )
            : null;
        return customWidget ??
            TIMUIKitFileElem(
              chatModel: model,
              message: messageItem,
              messageID: messageItem.msgID,
              fileElem: messageItem.fileElem,
              isSelf: isFromSelf,
              clearJump: clearJump,
              isShowJump: isShowJump,
              isShowMessageReaction: widget.isUseMessageReaction,
            );
      case MessageElemType.V2TIM_ELEM_TYPE_GROUP_TIPS:
        final customWidget =
            messageItemBuilder?.groupTipsMessageItemBuilder != null
                ? messageItemBuilder!.groupTipsMessageItemBuilder!(
                    messageItem,
                    isShowJump,
                    () => model.jumpMsgID = "",
                  )
                : null;
        return customWidget ?? Text(TIM_t("[缇ょ郴缁熸秷鎭痌"));
      case MessageElemType.V2TIM_ELEM_TYPE_IMAGE:
        if (!_hasUsableImage(messageItem)) {
          return _safeUnsupportedMessage(TIM_t("[图片消息不可用]"));
        }
        final customWidget = messageItemBuilder?.imageMessageItemBuilder != null
            ? messageItemBuilder!.imageMessageItemBuilder!(
                messageItem,
                isShowJump,
                () => model.jumpMsgID = "",
              )
            : null;
        return customWidget ??
            TIMUIKitImageElem(
              clearJump: clearJump,
              isShowJump: isShowJump,
              chatModel: model,
              message: messageItem,
              isShowMessageReaction: widget.isUseMessageReaction,
              // 用稳定标识（clientId/msgID 优先）作为 key。原来的 seq_timestamp
              // 在自己发的图片 sending -> success 时 seq 会变，导致图片气泡重建闪烁。
              key: Key(
                'img_${TencentUtils.checkString(messageItem.id) ?? TencentUtils.checkString(messageItem.msgID) ?? "${messageItem.seq}_${messageItem.timestamp}"}',
              ),
            );
      case MessageElemType.V2TIM_ELEM_TYPE_VIDEO:
        if (!_hasUsableVideo(messageItem)) {
          return _safeUnsupportedMessage(TIM_t("[视频消息不可用]"));
        }
        final customWidget = messageItemBuilder?.videoMessageItemBuilder != null
            ? messageItemBuilder!.videoMessageItemBuilder!(
                messageItem,
                isShowJump,
                () => model.jumpMsgID = "",
              )
            : null;
        return customWidget ??
            TIMUIKitVideoElem(
              messageItem,
              isShowJump: isShowJump,
              chatModel: model,
              clearJump: clearJump,
              isShowMessageReaction: widget.isUseMessageReaction,
            );
      case MessageElemType.V2TIM_ELEM_TYPE_LOCATION:
        final customWidget =
            messageItemBuilder?.locationMessageItemBuilder != null
                ? messageItemBuilder!.locationMessageItemBuilder!(
                    messageItem,
                    isShowJump,
                    () => model.jumpMsgID = "",
                  )
                : null;
        return customWidget ?? Text(TIM_t("[位置]"));
      case MessageElemType.V2TIM_ELEM_TYPE_MERGER:
        final customWidget =
            messageItemBuilder?.mergerMessageItemBuilder != null
                ? messageItemBuilder!.mergerMessageItemBuilder!(
                    messageItem,
                    isShowJump,
                    () => model.jumpMsgID = "",
                  )
                : null;
        if (messageItem.mergerElem == null) {
          return Text(TIM_t("[聊天记录]"));
        }
        return customWidget ??
            TIMUIKitMergerElem(
                messageItemBuilder: messageItemBuilder,
                model: model,
                isShowJump: isShowJump,
                clearJump: clearJump,
                message: messageItem,
                isShowMessageReaction: widget.isUseMessageReaction,
                mergerElem: messageItem.mergerElem!,
                messageID: messageItem.msgID ?? "",
                isSelf: messageItem.isSelf ?? true);
      default:
        return Text(TIM_t("未知消息"));
    }
  }

  Widget _groupTipsMessageBuilder(TUIChatSeparateViewModel model) {
    final messageItem = widget.message;
    final groupTipsElem = messageItem.groupTipsElem;
    if (groupTipsElem == null) {
      return const SizedBox.shrink();
    }
    return Container(
        padding: const EdgeInsets.only(bottom: 4),
        child: TIMUIKitGroupTipsElem(
            groupTipsElem: groupTipsElem,
            groupMemberList: model.groupMemberList ?? [],
            message: messageItem));
  }

  Widget _revokedMessageBuilder(theme, String option2) {
    return Container(
        margin: const EdgeInsets.symmetric(vertical: 20),
        alignment: Alignment.center,
        child: Text(
          TIM_t_para("{{option2}}撤回了一条消息", "$option2撤回了一条消息")(option2: option2),
          style: TextStyle(color: theme.weakTextColor, fontSize: 10),
        ));
  }

  Widget _timeDividerBuilder(
      theme, int timeStamp, TUIChatSeparateViewModel model) {
    return Container(
      alignment: Alignment.center,
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        model.chatConfig.timeDividerConfig?.timestampParser != null
            ? (model.chatConfig.timeDividerConfig?.timestampParser!(timeStamp))!
            : TimeAgo().getTimeForMessage(timeStamp),
        style: widget.themeData?.timelineTextStyle ??
            TextStyle(
              fontSize: 10,
              color: theme.chatTimeDividerTextColor,
            ),
      ),
    );
  }

  Widget _latestDividerBuilder(TUITheme theme) {
    return Container(
      alignment: Alignment.center,
      margin: const EdgeInsets.symmetric(vertical: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            margin: const EdgeInsets.only(right: 20),
            child: SizedBox(
              height: 1,
              width: 100,
              child: Container(
                  decoration: BoxDecoration(
                gradient: LinearGradient(colors: [
                  const Color(0x00C0E1FF),
                  theme.primaryColor ?? CommonColor.lightPrimaryColor
                ]),
              )),
            ),
          ),
          Text(
            TIM_t("以下为未读消息"),
            style: widget.themeData?.timelineTextStyle ??
                TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: theme.primaryColor,
                ),
          ),
          Container(
            margin: const EdgeInsets.only(left: 20),
            child: SizedBox(
              height: 1,
              width: 100,
              child: Container(
                  decoration: BoxDecoration(
                gradient: LinearGradient(colors: [
                  theme.primaryColor ?? CommonColor.primaryColor,
                  const Color(0x00C0E1FF),
                ]),
              )),
            ),
          ),
        ],
      ),
    );
  }

  String _messageTimeText(int? timestamp) {
    if (timestamp == null || timestamp <= 0) {
      return '';
    }
    final seconds = TUIChatGlobalModel.normalizeMessageEpochSeconds(timestamp);
    if (seconds <= 0) {
      return '';
    }
    final time = DateTime.fromMillisecondsSinceEpoch(seconds * 1000);
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  Widget _messageHeader(
    BuildContext context,
    V2TimMessage message,
    TUITheme theme,
    bool isSelf,
    double maxWidth,
    String name,
    bool isGroupMessage,
  ) {
    final baseNameStyle = (widget.themeData?.nickNameTextStyle ??
            TextStyle(fontSize: 12, color: theme.weakTextColor))
        .copyWith(height: 1);
    final nameStyle = isGroupMessage && _isDarkChatTheme(theme)
        ? baseNameStyle.copyWith(color: Colors.white)
        : baseNameStyle;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Align(
        alignment: isSelf ? Alignment.centerRight : Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment:
                isSelf ? MainAxisAlignment.end : MainAxisAlignment.start,
            children: [
              Flexible(
                child: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: nameStyle,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  int _estimateMobileTooltipItemCount(ToolTipsConfig? config) {
    var count = 6;
    if (config?.showTranslation ?? false) {
      count++;
    }
    if (config?.showRecallMessage ?? true) {
      count++;
    }
    if (config?.additionalMessageToolTips != null) {
      count += 3;
    }
    return count.clamp(5, 14);
  }

  double? _mobileTooltipMaxHeight(
    BuildContext context,
    TooltipDirection direction,
  ) {
    final anchorRect = _visibleMessageAnchorRect() ?? _messageAnchorRect();
    if (anchorRect == null) {
      return null;
    }

    final media = MediaQuery.of(context);
    const outsidePadding = 8.0;
    const anchorGap = 12.0;
    final safeTop = media.padding.top + outsidePadding;
    final safeBottom = media.size.height -
        media.padding.bottom -
        media.viewInsets.bottom -
        outsidePadding;

    final available = direction == TooltipDirection.down
        ? safeBottom - anchorRect.bottom - anchorGap
        : anchorRect.top - anchorGap - safeTop;

    if (!available.isFinite || available <= 0) {
      return null;
    }
    return max(120.0, available);
  }

  ({TooltipDirection direction, SelectEmojiPanelPosition reactionPosition})
      _resolveMobileTooltipPlacement({
    required BuildContext context,
    required Rect messageRect,
    required bool isUseMessageReaction,
    required int estimatedMenuItemCount,
    Offset? pointer,
    bool isLongMessage = false,
  }) {
    final media = MediaQuery.of(context);
    final screenHeight = media.size.height;
    final viewInsetsBottom = media.viewInsets.bottom;
    const outsidePadding = 8.0;
    const anchorGap = 12.0;
    final safeTop = media.padding.top + outsidePadding;
    final placementRect =
        _visibleMessageAnchorRect()?.intersect(messageRect) ?? messageRect;

    if ((isLongMessage || _isViewportTallMessage(messageRect)) &&
        pointer != null) {
      final spaceBelow = screenHeight -
          viewInsetsBottom -
          pointer.dy -
          outsidePadding -
          anchorGap;
      final spaceAbove = pointer.dy - safeTop - anchorGap;
      if (spaceBelow >= spaceAbove) {
        return (
          direction: TooltipDirection.down,
          reactionPosition: SelectEmojiPanelPosition.up,
        );
      }
      return (
        direction: TooltipDirection.up,
        reactionPosition: SelectEmojiPanelPosition.down,
      );
    }

    final spaceBelow = screenHeight -
        viewInsetsBottom -
        placementRect.bottom -
        outsidePadding -
        anchorGap;
    final spaceAbove = placementRect.top - safeTop - anchorGap;

    const rowHeight = 46.0;
    const reactionBlock = 56.0;
    const blockSpacing = 8.0;
    final menuHeight = estimatedMenuItemCount * rowHeight + 12;
    final reactionHeight =
        isUseMessageReaction ? reactionBlock + blockSpacing : 0.0;
    final totalNeeded = menuHeight + reactionHeight + outsidePadding;

    final fitsBelow = spaceBelow >= totalNeeded;
    final fitsAbove = spaceAbove >= totalNeeded;

    if (fitsBelow && !fitsAbove) {
      return (
        direction: TooltipDirection.down,
        reactionPosition: SelectEmojiPanelPosition.up,
      );
    }
    if (fitsAbove && !fitsBelow) {
      return (
        direction: TooltipDirection.up,
        reactionPosition: SelectEmojiPanelPosition.down,
      );
    }
    if (fitsBelow || spaceBelow >= spaceAbove) {
      return (
        direction: TooltipDirection.down,
        reactionPosition: SelectEmojiPanelPosition.up,
      );
    }
    return (
      direction: TooltipDirection.up,
      reactionPosition: SelectEmojiPanelPosition.down,
    );
  }

  Offset? _messageTooltipAnchor(
    TooltipDirection direction, {
    Offset? pointer,
    bool preferPointer = false,
  }) {
    final fullRect = _messageAnchorRect();
    final rect = _visibleMessageAnchorRect() ?? fullRect;
    if (rect == null) {
      return pointer;
    }
    const gap = 12.0;

    if (preferPointer && pointer != null) {
      return _clampTooltipPointer(pointer);
    }

    if (_isViewportTallMessage(fullRect) && pointer != null) {
      final clamped = _clampTooltipPointer(pointer)!;
      switch (direction) {
        case TooltipDirection.down:
          return Offset(clamped.dx, clamped.dy + gap);
        case TooltipDirection.up:
          return Offset(clamped.dx, clamped.dy - gap);
        default:
          return clamped;
      }
    }

    switch (direction) {
      case TooltipDirection.down:
        return Offset(rect.center.dx, rect.bottom + gap);
      case TooltipDirection.up:
        return Offset(rect.center.dx, rect.top - gap);
      default:
        return rect.center;
    }
  }

  Future<void> _onOpenToolTip(
    c,
    V2TimMessage message,
    TUIChatSeparateViewModel model,
    TUITheme theme,
    TapDownDetails? details,
    bool? isFromWideTooltip,
    bool? isShowMoreSticker, {
    bool withHaptic = false,
  }) async {
    if ((tooltip != null && tooltip!.isOpen) ||
        _mobileTelegramMenuOverlay != null) {
      closeTooltip();
      return;
    }
    tooltip = null;

    final isDesktopScreen =
        TUIKitScreenUtils.getFormFactor(context) == DeviceType.Desktop;
    // Every long message (text/image/video/...) is now captured in full and
    // scrolled inside the menu overlay, so we never scroll the list before
    // opening 鈥?that avoids a jarring jump on long-press.
    final tapDetails = isDesktopScreen ? (details ?? _tapDetails) : details;
    final pointer = tapDetails?.globalPosition;
    final isSelf = message.isSelf ?? true;

    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    final rowHeight = _messageRowHeight() ?? 80.0;
    final isLongMessage = rowHeight + 350 > screenHeight && !isDesktopScreen;
    final targetWidth = isDesktopScreen
        ? min(MediaQuery.of(context).size.width * 0.84, 350).toDouble()
        : TIMUIKitMessageTooltipState.mobileTooltipPanelWidth(context);
    final double dx = !isSelf
        ? min(tapDetails?.globalPosition.dx ?? targetWidth,
            screenWidth - targetWidth)
        : max(tapDetails?.globalPosition.dx ?? targetWidth, targetWidth)
            .toDouble();
    final double dy = min(
            tapDetails?.globalPosition.dy ?? MediaQuery.of(context).size.height,
            MediaQuery.of(context).size.height - 320)
        .toDouble();
    final finalTapDetail = tapDetails != null
        ? TapDownDetails(
            globalPosition: Offset(dx, dy),
          )
        : null;

    if (!isDesktopScreen) {
      if (withHaptic) {
        HapticFeedback.mediumImpact();
      }
      _openMobileTelegramContextMenu(
        message: message,
        model: model,
        toolTipsConfig: _resolvedToolTipsConfig(),
        isUseMessageReaction: false,
      );
      return;
    }

    initTools(
        context: c,
        model: model,
        isLongMessage: isLongMessage,
        isShowMoreSticker: isShowMoreSticker,
        details: finalTapDetail,
        theme: theme,
        isFromWideToolTip: isFromWideTooltip,
        pointer: pointer);
    final tooltipTargetCenter =
        finalTapDetail?.globalPosition ?? _messageAnchorRect()?.center;
    _beginMessageContextMenuOverlayPresentation();
    // 桌面/Web：轻量定位菜单，不要手机 Telegram 全屏毛玻璃。
    tooltip!.show(c, targetCenter: tooltipTargetCenter);
  }

  _clickOnCurrentSticker(int sticker) async {
    for (int i = 0; i < 5; i++) {
      final res = await _modifySticker(sticker);
      if (res.code == 0) {
        break;
      }
    }
  }

  Future<V2TimValueCallback<V2TimMessageChangeInfo>> _modifySticker(
      int sticker) async {
    return await Future.delayed(const Duration(milliseconds: 50), () async {
      return await MessageReactionUtils.clickOnSticker(widget.message, sticker);
    });
  }

  initTools(
      {BuildContext? context,
      bool isLongMessage = false,
      required TUIChatSeparateViewModel model,
      TUITheme? theme,
      bool? isShowMoreSticker,
      TapDownDetails? details,
      bool? isFromWideToolTip,
      Offset? pointer}) {
    final isUseMessageReaction = widget.message.elemType == 2
        ? false
        : model.chatConfig.isUseMessageReaction;
    final isDesktopScreen =
        TUIKitScreenUtils.getFormFactor(context) == DeviceType.Desktop;
    final isSelf = widget.message.isSelf ?? true;
    final resolvedToolTipsConfig = _resolvedToolTipsConfig();
    double arrowTipDistance = 30;
    double arrowBaseWidth = 10;
    double arrowLength = 10;
    bool hasArrow = true;
    TooltipDirection popupDirection = TooltipDirection.up;
    double? left;
    double? right;
    SelectEmojiPanelPosition selectEmojiPanelPosition =
        SelectEmojiPanelPosition.down;
    double? mobileMaxHeight;
    if (context != null) {
      RenderBox? box = _key.currentContext?.findRenderObject() as RenderBox?;
      final placementRect = _visibleMessageAnchorRect() ??
          _messageAnchorRect() ??
          (box != null ? box.localToGlobal(Offset.zero) & box.size : null);
      if (details != null && box != null) {
        double screenWidth = MediaQuery.of(context).size.width;
        final mousePosition = details.globalPosition;
        hasArrow = isDesktopScreen ? false : true;
        arrowTipDistance = 0;
        arrowBaseWidth = 0;
        arrowLength = 0;
        if (isDesktopScreen) {
          popupDirection = TooltipDirection.down;
          if (isSelf || (isFromWideToolTip ?? false)) {
            right = screenWidth - mousePosition.dx;
          } else {
            left = mousePosition.dx;
          }
        } else {
          if (placementRect != null) {
            final placement = _resolveMobileTooltipPlacement(
              context: context,
              messageRect: placementRect,
              isUseMessageReaction: isUseMessageReaction,
              estimatedMenuItemCount:
                  _estimateMobileTooltipItemCount(resolvedToolTipsConfig),
              pointer: pointer,
              isLongMessage: isLongMessage,
            );
            popupDirection = placement.direction;
            selectEmojiPanelPosition = placement.reactionPosition;
          }
        }
      } else {
        if (box != null) {
          double screenWidth = MediaQuery.of(context).size.width;
          double boxWidth = box.size.width;
          if (isDesktopScreen) {
            Offset offset = box.localToGlobal(Offset.zero);
            if (isSelf) {
              right = screenWidth -
                  offset.dx -
                  ((isUseMessageReaction) ? boxWidth : (boxWidth / 1.3));
            } else {
              left = offset.dx;
            }
          } else {
            if (placementRect != null) {
              final placement = _resolveMobileTooltipPlacement(
                context: context,
                messageRect: placementRect,
                isUseMessageReaction: isUseMessageReaction,
                estimatedMenuItemCount:
                    _estimateMobileTooltipItemCount(resolvedToolTipsConfig),
                pointer: pointer,
                isLongMessage: isLongMessage,
              );
              popupDirection = placement.direction;
              selectEmojiPanelPosition = placement.reactionPosition;
            }
          }
        }
        arrowTipDistance = ((_messageRowHeight() ?? 80.0) / 2).roundToDouble() +
            (isLongMessage ? -120 : 10);
      }
      if (!isDesktopScreen) {
        hasArrow = false;
        arrowTipDistance = 0;
        arrowBaseWidth = 0;
        arrowLength = 0;
        mobileMaxHeight = _mobileTooltipMaxHeight(context, popupDirection);
      }
    }

    tooltip = SuperTooltip(
      popupDirection: popupDirection,
      minimumOutSidePadding: 8,
      maxWidth: isDesktopScreen
          ? null
          : TIMUIKitMessageTooltipState.mobileTooltipPanelWidth(
              context ?? this.context),
      maxHeight: isDesktopScreen ? null : mobileMaxHeight,
      arrowTipDistance: arrowTipDistance,
      arrowBaseWidth: arrowBaseWidth,
      arrowLength: arrowLength,
      right: right,
      left: left,
      hasArrow: isDesktopScreen ? hasArrow : false,
      borderColor: _messageTooltipBorderColor(theme),
      backgroundColor: isDesktopScreen
          ? _messageTooltipSurfaceColor(theme)
          : Colors.transparent,
      // 桌面不铺半透明遮罩，贴近系统右键菜单；点击外侧由 SuperTooltip 关闭。
      outsideBackgroundColor: isDesktopScreen
          ? Colors.transparent
          : Colors.black.withValues(alpha: 0.28),
      shadowColor: _isDarkMessageTooltipTheme(theme)
          ? Colors.black.withValues(alpha: 0.55)
          : Colors.black26,
      hasShadow: isDesktopScreen,
      borderWidth: isDesktopScreen ? 1.0 : 0,
      containsBackgroundOverlay: isDesktopScreen,
      onClose: _removeTooltipBlurOverlay,
      showCloseButton: ShowCloseButton.none,
      touchThroughAreaShape: ClipAreaShape.rectangle,
      content: TIMUIKitMessageTooltip(
        iSUseDefaultHoverBar: model.chatConfig.isUseMessageHoverBarOnDesktop &&
            widget.customMessageHoverBarOnDesktop == null,
        model: model,
        groupMemberInfo: widget.groupMemberInfo,
        isShowMoreSticker: isShowMoreSticker ?? false,
        toolTipsConfig: resolvedToolTipsConfig,
        isUseMessageReaction: isUseMessageReaction,
        message: widget.message,
        allowAtUserWhenReply: widget.allowAtUserWhenReply,
        onLongPressForOthersHeadPortrait:
            widget.onLongPressForOthersHeadPortrait,
        onAtUserWhenReply: widget.onAtUserWhenReply,
        selectEmojiPanelPosition: selectEmojiPanelPosition,
        onCloseTooltip: () => tooltip?.close(),
        onSelectSticker: (int value) {
          tooltip?.close();
          _clickOnCurrentSticker(value);
        },
      ),
    );
  }

  Widget _buildMessageContent(
    V2TimMessage message,
    int? messageStatus,
    TUIChatSeparateViewModel model,
    TUITheme theme,
  ) {
    if (message.elemType == MessageElemType.V2TIM_ELEM_TYPE_CUSTOM &&
        (_isWalletCardCustomMessage(message) ||
            _isCallCustomMessage(message))) {
      return _getMessageItemBuilder(message, messageStatus, model);
    }

    return wrapMessageBubbleWithWatermark(
      child: _getMessageItemBuilder(message, messageStatus, model),
      message: message,
      model: model,
      theme: theme,
    );
  }

  Widget _getMessageItemBuilder(V2TimMessage message, int? messageStatues,
      TUIChatSeparateViewModel model) {
    final messageBuilder = _messageItemBuilder;

    return messageBuilder(message, model);
  }

  bool _isContactCardCustomMessage(V2TimMessage message) {
    try {
      final raw = message.customElem?.data;
      if (raw == null || raw.trim().isEmpty) return false;
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return false;
      final data = Map<String, dynamic>.from(decoded);
      return data['businessID']?.toString() == 'contact_card';
    } catch (_) {
      return false;
    }
  }

  bool _isWalletCardCustomMessage(V2TimMessage message) {
    try {
      final raw = message.customElem?.data;
      if (raw == null || raw.trim().isEmpty) return false;
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return false;
      final data = Map<String, dynamic>.from(decoded);
      final customType = data['customType']?.toString() ?? '';
      final legacyType = data['type']?.toString() ?? '';
      final businessID = data['businessID']?.toString() ?? '';
      return customType == 'wallet_transfer' ||
          legacyType == 'wallet_transfer' ||
          customType == 'wallet_red_packet' ||
          legacyType == 'wallet_red_packet' ||
          businessID == 'wallet_order';
    } catch (_) {
      return false;
    }
  }

  /// C2C/group call bubbles embed time + read state themselves.
  bool _isCallCustomMessage(V2TimMessage message) {
    if (message.elemType != MessageElemType.V2TIM_ELEM_TYPE_CUSTOM) {
      return false;
    }
    final localRaw = message.localCustomData?.trim() ?? '';
    if (localRaw.contains('localCallBubble')) {
      return true;
    }
    final raw = message.customElem?.data?.trim() ?? '';
    if (raw.isEmpty) {
      return false;
    }
    return raw.contains('av_call') ||
        raw.contains('rtc_call') ||
        raw.contains('lk_call') ||
        raw.contains('inviteID') ||
        raw.contains('callId');
  }

  ToolTipsConfig _resolvedToolTipsConfig() {
    final source = widget.toolTipsConfig ?? ToolTipsConfig();
    final baseShowReply = source.showReplyMessage;
    final baseShowForward = source.showForwardMessage;
    return ToolTipsConfig(
      showDeleteMessage: source.showDeleteMessage &&
          !_isWalletCardCustomMessage(widget.message),
      showMultipleChoiceMessage: source.showMultipleChoiceMessage,
      showRecallMessage: source.showRecallMessage &&
          !_isWalletCardCustomMessage(widget.message),
      showReplyMessage: baseShowReply &&
          widget.message.status != MessageStatus.V2TIM_MSG_STATUS_SEND_FAIL,
      showTranslation: source.showTranslation,
      showCopyMessage: source.showCopyMessage,
      showForwardMessage: baseShowForward &&
          widget.message.status != MessageStatus.V2TIM_MSG_STATUS_SEND_FAIL &&
          widget.message.elemType !=
              MessageElemType.V2TIM_ELEM_TYPE_GROUP_TIPS &&
          !(widget.message.hasRiskContent ?? false) &&
          !_isWalletCardCustomMessage(widget.message) &&
          !_isContactCardCustomMessage(widget.message),
      additionalMessageToolTips: source.additionalMessageToolTips,
      additionalItemBuilder: source.additionalItemBuilder,
    );
  }

  // 弹出对话框
  Future<bool?> showResendMsgFailDialog(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (context) {
        return CupertinoAlertDialog(
          title: Text(TIM_t("您确定要重发这条消息吗？")),
          actions: [
            CupertinoDialogAction(
              child: Text(TIM_t("确定")),
              onPressed: () {
                Navigator.of(context).pop(true);
              },
            ),
            CupertinoDialogAction(
              child: Text(TIM_t("取消")),
              isDestructiveAction: true,
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  @override
  void deactivate() {
    // 长按菜单挂在 root Overlay；聊天路由离栈时必须在 dispose 前移除，
    // 否则透明遮罩可能继续拦截底层会话列表的点击。
    _removeTooltipBlurOverlay();
    super.deactivate();
  }

  @override
  void dispose() {
    _unregisterContextMenuOverlayDismisser();
    _removeTooltipBlurOverlay();
    if (tooltip?.isOpen ?? false) {
      tooltip?.close();
    }
    super.dispose();
  }

  List<MessageHoverControlItem> getWideMessageHoverControlBar(
      TUIChatSeparateViewModel model, TUITheme theme) {
    final resolvedToolTipsConfig = _resolvedToolTipsConfig();
    return [
      if (widget.isUseMessageReaction ?? false)
        MessageHoverControlItem(
          name: TIM_t("表情回应"),
          icon: Icon(
            Icons.emoji_emotions,
            size: 13,
            color: hexToColor("8f959e"),
          ),
          onClick: (details) {
            _onOpenToolTip(
                context, widget.message, model, theme, details, true, true);
          },
        ),
      if (resolvedToolTipsConfig.showReplyMessage)
        MessageHoverControlItem(
          name: TIM_t("回复"),
          icon: Icon(
            Icons.message,
            size: 13,
            color: hexToColor("8f959e"),
          ),
          onClick: (_) {
            model.repliedMessage = widget.message;
            final isSelf = widget.message.isSelf ?? true;
            final isGroup =
                TencentUtils.checkString(widget.message.groupID) != null;
            final atWhenReply = widget.onAtUserWhenReply ??
                widget.onLongPressForOthersHeadPortrait;
            final isAtWhenReply = !isSelf &&
                isGroup &&
                widget.allowAtUserWhenReply &&
                atWhenReply != null;

            /// If replying to a self message, do not add a at tag, only requestFocus.
            atWhenReply?.call(
              !isAtWhenReply ? null : widget.message.sender,
              !isAtWhenReply
                  ? null
                  : model.getGroupMessageDisplayName(widget.message),
            );
          },
        ),
      if (resolvedToolTipsConfig.showForwardMessage &&
          !model.isVoteMessage(widget.message) &&
          !model.isWalletCardMessage(widget.message) &&
          !model.isContactCardMessage(widget.message))
        MessageHoverControlItem(
          name: TIM_t("杞彂"),
          icon: Icon(
            Icons.send,
            size: 13,
            color: hexToColor("8f959e"),
          ),
          onClick: (_) {
            model.updateMultiSelectStatus(false);
            model.setMessageItemChecked(widget.message, true);
            TUIKitWidePopup.showPopupWindow(
                operationKey: TUIKitWideModalOperationKey.forward,
                context: context,
                title: TIM_t("转发"),
                width: WidePopupLayout.large(context).width,
                height: WidePopupLayout.large(context).height,
                onCancel: () {},
                onConfirm: () {
                  forwardMessageScreenKey.currentState?.handleForwardMessage();
                },
                confirmText: TIM_t("发送"),
                child: (onClose) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: ForwardMessageScreen(
                        conversationType:
                            model.conversationType ?? ConvType.c2c,
                        key: forwardMessageScreenKey,
                        onClose: onClose,
                        model: model,
                      ),
                    ),
                theme: theme);
          },
        ),
      MessageHoverControlItem(
        name: TIM_t("鏇村"),
        icon: Icon(
          Icons.more_horiz,
          size: 13,
          color: hexToColor("8f959e"),
        ),
        onClick: (details) {
          _onOpenToolTip(
              context, widget.message, model, theme, details, true, false);
        },
      ),
      ...?model.chatConfig.additionalDesktopMessageHoverBarItem
    ];
  }

  Future<void> _onMsgSendFailIconTap(
      V2TimMessage message, TUIChatSeparateViewModel model) async {
    final convID = model.conversationID;
    final convType = model.conversationType;
    final res = await model.reSendFailMessage(
      message: message,
      convType: convType ?? ConvType.c2c,
      convID: convID,
    );
    if (res == null) {
      _coreServicesImpl.callOnCallback(
        TIMCallback(
          type: TIMCallbackType.INFO,
          infoRecommendText: TIM_t("无法重发该消息"),
          infoCode: 6661099,
        ),
      );
      return;
    }
    MessageUtils.handleMessageErrorCode(res, context);
  }

  int _liveMessageStatus(
    BuildContext context,
    TUIChatSeparateViewModel model,
    V2TimMessage message,
  ) {
    final fallback = message.status ?? MessageStatus.V2TIM_MSG_STATUS_SEND_SUCC;
    final isSelf = message.isSelf ?? true;
    if (!isSelf) {
      return fallback;
    }
    final globalModel = context.read<TUIChatGlobalModel>();
    return globalModel.messageStatusInConversation(
      model.conversationID,
      clientId: message.id,
      msgID: message.msgID,
      fallback: fallback,
      elemType: message.elemType,
    );
  }

  bool _showMessageSideStatusColumnForStatus(
      int status, V2TimMessage message, bool isSelf) {
    final isC2CCallMessage = MessageUtils.isC2CCallOutgoing(message) != null;
    if (isC2CCallMessage) {
      return false;
    }
    if (!isSelf) {
      return message.elemType == MessageElemType.V2TIM_ELEM_TYPE_SOUND &&
          message.localCustomInt != null &&
          message.localCustomInt != HistoryMessageDartConstant.read;
    }
    return status == MessageStatus.V2TIM_MSG_STATUS_SEND_FAIL ||
        (status == MessageStatus.V2TIM_MSG_STATUS_SENDING &&
            !TimUIKitMediaUploadOverlay.supportsInlineUploadOverlay(
              message.elemType,
            ));
  }

  bool _showMessageSideStatusColumn(V2TimMessage message, bool isSelf) {
    return _showMessageSideStatusColumnForStatus(
      message.status ?? MessageStatus.V2TIM_MSG_STATUS_SEND_SUCC,
      message,
      isSelf,
    );
  }

  Widget renderHoverTipAndReadStatus(
      TUIChatSeparateViewModel model,
      bool isSelf,
      V2TimMessage message,
      int liveStatus,
      bool isPeerRead,
      TUITheme theme,
      bool isDownloadWaiting) {
    final isDesktopScreen =
        TUIKitScreenUtils.getFormFactor(context) == DeviceType.Desktop;
    final customHoverBar = widget.customMessageHoverBarOnDesktop != null
        ? widget.customMessageHoverBarOnDesktop!(message)
        : null;
    final wideHoverTipList = (model.chatConfig.isUseMessageHoverBarOnDesktop &&
            customHoverBar == null)
        ? getWideMessageHoverControlBar(model, theme)
        : [];
    final lastItemName =
        wideHoverTipList.isNotEmpty ? wideHoverTipList.last.name : "";

    return Column(
      mainAxisSize: MainAxisSize.max,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (isDesktopScreen &&
            isShowWideToolTip &&
            customHoverBar == null &&
            !((widget.message.elemType == 6 && isDownloadWaiting)))
          Container(
            decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: hexToColor("d9dde0"), width: 1)),
            margin: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              children: wideHoverTipList
                  .map((e) => Tooltip(
                        message: e.name,
                        preferBelow: false,
                        textStyle: TextStyle(fontSize: 12, color: theme.white),
                        child: Row(
                          children: [
                            InkWell(
                              onTapDown: e.onClick,
                              child: SizedBox(
                                width: 22,
                                height: 22,
                                child: e.icon,
                              ),
                            ),
                            if (lastItemName != e.name)
                              SizedBox(
                                width: 1,
                                height: 22,
                                child: Container(
                                  color: theme.weakDividerColor,
                                ),
                              )
                          ],
                        ),
                      ))
                  .toList(),
            ),
          ),
        if (isDesktopScreen && isShowWideToolTip && customHoverBar != null)
          customHoverBar,
        if (!isDesktopScreen ||
            (model.chatConfig.isUseMessageHoverBarOnDesktop &&
                customHoverBar == null &&
                !isShowWideToolTip))
          const SizedBox(
            height: 20,
          ),
        if (isSelf && liveStatus == MessageStatus.V2TIM_MSG_STATUS_SEND_FAIL)
          Container(
              padding: const EdgeInsets.only(bottom: 3),
              margin: const EdgeInsets.only(right: 6),
              child: GestureDetector(
                onTap: () async {
                  final reSend = await showResendMsgFailDialog(context);
                  if (reSend != null) {
                    _onMsgSendFailIconTap(message, model);
                  }
                },
                child: Icon(Icons.error, color: theme.cautionColor, size: 18),
              )),
        if (isSelf && liveStatus == MessageStatus.V2TIM_MSG_STATUS_SENDING)
          Container(
            padding: const EdgeInsets.only(bottom: 3),
            margin: const EdgeInsets.only(right: 6),
            width: 12.0,
            height: 15.0,
            child: CircularProgressIndicator(strokeWidth: 1.0),
          ),
      ],
    );
  }

  Future<void> _openReAddFriendPage(BuildContext context, String userID) async {
    if (userID.isEmpty) {
      return;
    }
    final friendshipServices = serviceLocator<FriendshipServices>();
    final selfInfoViewModel = serviceLocator<TUISelfInfoViewModel>();
    final users = await friendshipServices.getUsersInfo(userIDList: [userID]);
    if (!context.mounted) {
      return;
    }
    final friendInfo = (users != null && users.isNotEmpty)
        ? users.first
        : V2TimUserFullInfo(userID: userID);

    final openAddFriend = AddFriendNavigator.openAddFriendPage;
    if (openAddFriend != null) {
      await openAddFriend(
        context,
        userID: userID,
        friendInfo: friendInfo,
        addSource: FriendAddSource.chat,
      );
      return;
    }

    final isDesktopScreen =
        TUIKitScreenUtils.getFormFactor(context) == DeviceType.Desktop;
    if (isDesktopScreen) {
      TUIKitWidePopup.showPopupWindow(
        operationKey: TUIKitWideModalOperationKey.addFriend,
        context: context,
        width: MediaQuery.of(context).size.width * 0.3,
        height: MediaQuery.of(context).size.width * 0.4,
        title: TIM_t("娣诲姞濂藉弸"),
        child: (_) => SendApplication(
          friendInfo: friendInfo,
          model: selfInfoViewModel,
          addSource: FriendAddSource.chat,
        ),
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SendApplication(
          friendInfo: friendInfo,
          model: selfInfoViewModel,
          addSource: FriendAddSource.chat,
        ),
      ),
    );
  }

  Widget _buildFriendDeletedHint(
    BuildContext context,
    TUITheme theme,
    String peerUserId,
  ) {
    final linkColor = theme.primaryColor ?? const Color(0xFF1E90FF);
    final textColor = theme.cautionColor ?? const Color(0xFFE54545);
    const textStyle = TextStyle(fontSize: 12, height: 1.35);
    return Wrap(
      alignment: WrapAlignment.end,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          ErrorMessageConverter.friendDeletedByOtherHintPrefix,
          style: textStyle.copyWith(color: textColor),
        ),
        GestureDetector(
          onTap: () => _openReAddFriendPage(context, peerUserId),
          child: Text(
            ErrorMessageConverter.friendDeletedByOtherHintLink,
            style: textStyle.copyWith(color: linkColor),
          ),
        ),
      ],
    );
  }

  @override
  Widget tuiBuild(BuildContext context, TUIKitBuildValue value) {
    final TUIChatSeparateViewModel model =
        context.read<TUIChatSeparateViewModel>();
    final TUIFriendShipViewModel friendshipModel =
        context.read<TUIFriendShipViewModel>();
    final isDownloadWaiting = context.select<TUIChatGlobalModel, bool>(
        (value) => value.isWaiting(widget.message.msgID ?? ""));
    final TUITheme theme = value.theme;
    final baseMessage = widget.message;
    final messageKey = ChatUiStateStore.messageKeyOf(baseMessage);
    final rowUiState = context.select<ChatUiStateStore, ChatRowUiSnapshot>(
      (store) => store.rowSnapshot(
        conversationID: model.conversationID,
        messageKey: messageKey,
      ),
    );
    final lookedUp =
        context.read<TUIChatGlobalModel>().messageInConversationByKey(
              model.conversationID,
              messageKey,
            );
    // key 回查可能命中同秒 stub；elemType 不一致时绝不能把文字行渲染成图片。
    final message =
        (lookedUp != null && lookedUp.elemType == baseMessage.elemType)
            ? lookedUp
            : baseMessage;
    // 只订阅本行的显示名，而不是全局 groupMemberVersion。
    // 成员信息加载会推动版本号变化，整行订阅会导致所有消息行重建。
    final messageDisplayName = context.select<TUIChatSeparateViewModel, String>(
      (value) => value.getMessageDisplayName(message),
    );
    final liveStatus = _liveMessageStatus(context, model, message);
    final msgType = message.elemType;

    RenderingDirectionResult? renderingDirectionResult;
    if (widget.renderingDirectionCallback != null) {
      renderingDirectionResult = widget.renderingDirectionCallback!(message);
    }

    bool isSelf = true;
    String? faceUrl = message.faceUrl;
    if (renderingDirectionResult != null &&
        renderingDirectionResult.isSelf != null) {
      isSelf = renderingDirectionResult.isSelf!;
      faceUrl = renderingDirectionResult.userInfo?.faceUrl;
    } else {
      isSelf = message.isSelf ?? true;
    }

    final isGroupTipsMsg =
        msgType == MessageElemType.V2TIM_ELEM_TYPE_GROUP_TIPS;

    final revokeStatus = isRevokeMessage(message, model);
    final isRevokedMsg = revokeStatus.$1;
    final isAdminRevoke = revokeStatus.$2;

    final isTimeDivider = msgType == 11;
    final isLatestDivider = msgType == 101;
    final isPeerRead = message.isPeerRead ?? false;
    final isGroupMessage = model.conversationType == ConvType.group;
    final isShowNickNameForSelf =
        isGroupMessage && model.chatConfig.isShowSelfNameInGroup;
    final isShowNickNameForOthers =
        isGroupMessage && model.chatConfig.isShowOthersNameInGroup;
    final shouldShowOtherAvatar = !isSelf && widget.showAvatar;
    final shouldShowDefaultHeader = !isSelf && isShowNickNameForOthers;
    final isDesktopScreen =
        TUIKitScreenUtils.getFormFactor(context) == DeviceType.Desktop;
    if (isTimeDivider) {
      return _timeDividerBuilder(theme, message.timestamp ?? 0, model);
    }
    if (isLatestDivider) {
      return _latestDividerBuilder(theme);
    }
    void clearJump() {
      Future.delayed(const Duration(milliseconds: 100), () {
        model.jumpMsgID = "";
      });
    }

    if (isGroupTipsMsg) {
      if (widget.messageItemBuilder?.groupTipsMessageItemBuilder != null) {
        final groupTipsMessage =
            widget.messageItemBuilder!.groupTipsMessageItemBuilder!(
          message,
          (model.jumpMsgID == message.msgID),
          clearJump,
        );
        return groupTipsMessage ?? _groupTipsMessageBuilder(model);
      }
      return _groupTipsMessageBuilder(model);
    }

    if (isRevokedMsg) {
      final displayName = isAdminRevoke
          ? TIM_t("管理员")
          : (isSelf
              ? TIM_t("您")
              : TencentUtils.checkString(messageDisplayName) ??
                  TencentUtils.checkString(message.sender) ??
                  message.userID);
      return _revokedMessageBuilder(theme, displayName ?? "");
    }

    // 浣跨敤鑷畾涔夎
    if (widget.messageItemBuilder?.messageRowBuilder != null) {
      final customRow = widget.messageItemBuilder!.messageRowBuilder!(
        message,
        _buildMessageContent(message, liveStatus, model, theme),
        widget.onScrollToIndex ?? () {},
        message.msgID == model.jumpMsgID,
        clearJump,
        widget.onScrollToIndexBegin ?? () {},
      );
      if (customRow != null) {
        return customRow;
      }
    }

    final screenWidth = MediaQuery.sizeOf(context).width;
    final maxContentWidth =
        isDesktopScreen ? min(screenWidth * 0.55, 720.0) : screenWidth * 0.77;
    Widget messageRow = Container(
      padding: EdgeInsets.only(left: isSelf ? 0 : 16, right: isSelf ? 16 : 0),
      margin: widget.padding ?? const EdgeInsets.only(bottom: 12),
      child: Row(
        key: _key,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (rowUiState.isMultiSelect)
            Container(
              margin:
                  EdgeInsets.only(right: 12, top: 10, left: isSelf ? 16 : 0),
              child: CheckBoxButton(
                isChecked: rowUiState.isSelected,
                onChanged: (value) {
                  model.setMessageItemChecked(message, value);
                },
              ),
            ),
          Expanded(
            child: MouseRegion(
              onEnter: (_) {
                if (isDesktopScreen &&
                    model.chatConfig.isUseMessageHoverBarOnDesktop &&
                    mounted) {
                  setState(() {
                    isShowWideToolTip = true;
                  });
                }
              },
              onExit: (_) {
                if (isDesktopScreen &&
                    model.chatConfig.isUseMessageHoverBarOnDesktop) {
                  Tooltip.dismissAllToolTips();
                  Future.delayed(const Duration(milliseconds: 100), () {
                    if (!mounted) {
                      return;
                    }
                    setState(() {
                      isShowWideToolTip = false;
                    });
                  });
                }
              },
              child: GestureDetector(
                behavior: rowUiState.isMultiSelect
                    ? HitTestBehavior.translucent
                    : null,
                onTap: () {
                  if (rowUiState.isMultiSelect) {
                    final checked = rowUiState.isSelected;
                    model.setMessageItemChecked(message, !checked);
                  } else {
                    return;
                  }
                },
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment:
                      isSelf ? MainAxisAlignment.end : MainAxisAlignment.start,
                  children: [
                    if (shouldShowOtherAvatar)
                      GestureDetector(
                        onLongPress: () {
                          if (widget.onLongPressForOthersHeadPortrait !=
                              null) {}
                          if (model.chatConfig.isAllowLongPressAvatarToAt) {
                            widget.onLongPressForOthersHeadPortrait!(
                                message.sender, messageDisplayName);
                          }
                        },
                        onTapDown: isDesktopScreen
                            ? (details) {
                                if (widget.onTapForOthersPortrait != null &&
                                    widget.allowAvatarTap) {
                                  widget.onTapForOthersPortrait!(
                                      message.sender ?? "", details);
                                }
                              }
                            : null,
                        onTap: isDesktopScreen
                            ? null
                            : () {
                                if (widget.onTapForOthersPortrait != null &&
                                    widget.allowAvatarTap) {
                                  widget.onTapForOthersPortrait!(
                                      message.sender ?? "", TapDownDetails());
                                }
                              },
                        onSecondaryTap: isDesktopScreen
                            ? null
                            : () {
                                if (widget.onSecondaryTapForOthersPortrait !=
                                        null &&
                                    widget.allowAvatarTap) {
                                  widget.onSecondaryTapForOthersPortrait!(
                                      message.sender ?? "", TapDownDetails());
                                }
                              },
                        onSecondaryTapDown: isDesktopScreen
                            ? (details) {
                                if (widget.onSecondaryTapForOthersPortrait !=
                                        null &&
                                    widget.allowAvatarTap) {
                                  widget.onSecondaryTapForOthersPortrait!(
                                      message.sender ?? "", details);
                                }
                              }
                            : null,
                        child: widget.userAvatarBuilder != null
                            ? widget.userAvatarBuilder!(context, message)
                            : Container(
                                margin: (isSelf && isShowNickNameForSelf) ||
                                        (!isSelf && isShowNickNameForOthers)
                                    ? const EdgeInsets.only(top: 2)
                                    : null,
                                child: timUIKitCircularMessageAvatar(
                                  faceUrl: faceUrl ?? '',
                                  showName: messageDisplayName,
                                  size: 36,
                                ),
                              ),
                      ),
                    if (isSelf && message.elemType == 6 && isDownloadWaiting)
                      Container(
                        margin: const EdgeInsets.only(top: 46, right: 10),
                        child: LoadingAnimationWidget.threeArchedCircle(
                          color: theme.weakTextColor ?? Colors.grey,
                          size: 20,
                        ),
                      ),
                    Container(
                      margin: shouldShowOtherAvatar
                          ? const EdgeInsets.only(left: 13)
                          : null,
                      child: Column(
                        crossAxisAlignment: isSelf
                            ? CrossAxisAlignment.end
                            : CrossAxisAlignment.start,
                        children: [
                          if (widget.topRowBuilder != null)
                            widget.topRowBuilder!(context, message)
                          else if (shouldShowDefaultHeader)
                            _messageHeader(
                              context,
                              message,
                              theme,
                              isSelf,
                              maxContentWidth,
                              messageDisplayName,
                              isGroupMessage,
                            ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: isSelf
                                ? MainAxisAlignment.end
                                : MainAxisAlignment.start,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              if (isSelf &&
                                  !isGroupMessage &&
                                  _showMessageSideStatusColumnForStatus(
                                      liveStatus, message, isSelf))
                                renderHoverTipAndReadStatus(
                                    model,
                                    isSelf,
                                    message,
                                    liveStatus,
                                    isPeerRead,
                                    theme,
                                    isDownloadWaiting),
                              KeyedSubtree(
                                key: _messageBubbleKey,
                                child: Opacity(
                                  opacity: _isBubbleExtracted ? 0.0 : 1.0,
                                  child: RepaintBoundary(
                                    key: _messageExtractBoundaryKey,
                                    child: Container(
                                      constraints: BoxConstraints(
                                        maxWidth: maxContentWidth,
                                      ),
                                      child: Builder(builder: (context) {
                                        final bubbleContent = IgnorePointer(
                                          ignoring: rowUiState.isMultiSelect ||
                                              _contextMenuPresentationActive ||
                                              _isBubbleExtracted,
                                          child: _buildMessageContent(message,
                                              liveStatus, model, theme),
                                        );
                                        void openDesktopMessageMenu(
                                            TapDownDetails? details) {
                                          if (widget.onLongPress != null) {
                                            widget.onLongPress!(
                                                context, message);
                                            return;
                                          }
                                          if (!widget.allowLongPress) {
                                            return;
                                          }
                                          unawaited(_onOpenToolTip(
                                            context,
                                            message,
                                            model,
                                            theme,
                                            details ?? _tapDetails,
                                            false,
                                            false,
                                          ));
                                        }

                                        void onSecondaryTapDown(
                                            TapDownDetails details) {
                                          if (PlatformUtils().isMobile) {
                                            return;
                                          }
                                          openDesktopMessageMenu(details);
                                        }

                                        Widget wrapBubblePressHandlers(
                                            Widget child) {
                                          if (rowUiState.isMultiSelect) {
                                            return child;
                                          }
                                          if (isDesktopScreen) {
                                            // 桌面/Web：右键 + 长按都走桌面菜单，不进手机毛玻璃。
                                            return GestureDetector(
                                              onTapDown: (details) {
                                                _tapDetails = details;
                                              },
                                              onSecondaryTapDown:
                                                  onSecondaryTapDown,
                                              onLongPressStart: (details) {
                                                _tapDetails = TapDownDetails(
                                                  globalPosition:
                                                      details.globalPosition,
                                                );
                                              },
                                              onLongPress: () {
                                                openDesktopMessageMenu(
                                                    _tapDetails);
                                              },
                                              child: child,
                                            );
                                          }
                                          return TelegramMessageLongPressDetector(
                                            onLongPressStart: (details) {
                                              _tapDetails = TapDownDetails(
                                                globalPosition:
                                                    details.globalPosition,
                                              );
                                            },
                                            onLongPress: () {
                                              unawaited(
                                                  _triggerMobileBubbleContextMenu(
                                                context,
                                                message,
                                                model,
                                                theme,
                                              ));
                                            },
                                            child: GestureDetector(
                                              child: child,
                                              onSecondaryTapDown:
                                                  onSecondaryTapDown,
                                              onTapDown: (details) {
                                                _tapDetails = details;
                                              },
                                            ),
                                          );
                                        }

                                        if (message.elemType ==
                                            MessageElemType
                                                .V2TIM_ELEM_TYPE_SOUND) {
                                          // Voice bubbles already handle tap-to-play
                                          // internally; avoid an extra deferToChild
                                          // GestureDetector that stalls iOS gesture
                                          // gate resolution near the screen bottom.
                                          return wrapBubblePressHandlers(
                                            bubbleContent,
                                          );
                                        }
                                        return wrapBubblePressHandlers(
                                          bubbleContent,
                                        );
                                      }),
                                    ),
                                  ),
                                ),
                              ),
                              if (!isSelf &&
                                  message.elemType ==
                                      MessageElemType.V2TIM_ELEM_TYPE_SOUND &&
                                  message.localCustomInt != null &&
                                  message.localCustomInt !=
                                      HistoryMessageDartConstant.read)
                                Padding(
                                    padding: const EdgeInsets.only(
                                        left: 5, bottom: 12),
                                    child: Icon(Icons.circle,
                                        color: theme.cautionColor, size: 10)),
                              if (!isSelf &&
                                  _showMessageSideStatusColumnForStatus(
                                      liveStatus, message, isSelf))
                                renderHoverTipAndReadStatus(
                                    model,
                                    isSelf,
                                    message,
                                    liveStatus,
                                    isPeerRead,
                                    theme,
                                    isDownloadWaiting),
                            ],
                          ),
                          if (isSelf &&
                              model.conversationType == ConvType.c2c &&
                              liveStatus ==
                                  MessageStatus.V2TIM_MSG_STATUS_SEND_FAIL &&
                              ErrorMessageConverter.shouldShowFriendDeletedHint(
                                message,
                                c2cPeerUserId: model.conversationID,
                                friendList: friendshipModel.friendList,
                              ))
                            Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: ConstrainedBox(
                                constraints: BoxConstraints(
                                  maxWidth: maxContentWidth,
                                ),
                                child: Align(
                                  alignment: Alignment.centerRight,
                                  child: _buildFriendDeletedHint(
                                    context,
                                    theme,
                                    ErrorMessageConverter.normalizedPeerUserId(
                                      model.conversationID,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          TIMUIKitTextTranslationElem(
                              message: message,
                              customEmojiStickerList:
                                  widget.customEmojiStickerList,
                              isFromSelf: isSelf,
                              isShowJump: false,
                              clearJump: () {},
                              chatModel: model),
                        ],
                      ),
                    ),
                    if (!isSelf && message.elemType == 6 && isDownloadWaiting)
                      Container(
                        margin: const EdgeInsets.only(top: 46, left: 10),
                        child: LoadingAnimationWidget.threeArchedCircle(
                          color: theme.weakTextColor ?? Colors.grey,
                          size: 20,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );

    if (widget.bottomRowBuilder != null) {
      final bottomRow = widget.bottomRowBuilder!(context, message);
      messageRow = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          messageRow,
          bottomRow,
        ],
      );
    }

    final needReadReceiptVisibility = model.chatConfig.isShowReadingStatus &&
        !(message.isSelf ?? true) &&
        (message.needReadReceipt ?? false) &&
        !(message.isRead ?? false);

    if (!needReadReceiptVisibility) {
      return messageRow;
    }

    final globalModel = Provider.of<TUIChatGlobalModel>(context, listen: false);
    return VisibilityDetector(
      key: Key(message.id ?? message.msgID!),
      onVisibilityChanged: (visibilityInfo) {
        if (_readReceiptVisibilityHandled ||
            globalModel.isChatListUserScrolling) {
          return;
        }
        final visiblePercentage = visibilityInfo.visibleFraction * 100;
        if (visiblePercentage > 75) {
          _readReceiptVisibilityHandled = true;
          model.addToMessageReadReceiptList(message);
        }
      },
      child: messageRow,
    );
  }
}

class _MessageSpotlightClipper extends CustomClipper<Path> {
  final Rect hole;
  final double radius;

  const _MessageSpotlightClipper({
    required this.hole,
    required this.radius,
  });

  @override
  Path getClip(Size size) {
    final fullScreen = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    final holePath = Path()
      ..addRRect(RRect.fromRectAndRadius(hole, Radius.circular(radius)));
    return Path.combine(PathOperation.difference, fullScreen, holePath);
  }

  @override
  bool shouldReclip(covariant _MessageSpotlightClipper oldClipper) {
    return oldClipper.hole != hole || oldClipper.radius != radius;
  }
}

class _MessageTooltipBlurOverlay extends StatefulWidget {
  final Rect holeRect;
  final VoidCallback onDismiss;

  const _MessageTooltipBlurOverlay({
    required this.holeRect,
    required this.onDismiss,
  });

  @override
  State<_MessageTooltipBlurOverlay> createState() =>
      _MessageTooltipBlurOverlayState();
}

class _MessageTooltipBlurOverlayState extends State<_MessageTooltipBlurOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    _opacity = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: GestureDetector(
        onTap: widget.onDismiss,
        behavior: HitTestBehavior.opaque,
        child: ClipPath(
          clipBehavior: Clip.hardEdge,
          clipper: _MessageSpotlightClipper(
            hole: widget.holeRect,
            radius: 10,
          ),
          // Solid scrim (no live GPU blur) — same policy as Telegram menu shell.
          child: const ColoredBox(
            color: Color(0x61000000), // ~38% black
          ),
        ),
      ),
    );
  }
}
