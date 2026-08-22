// ignore_for_file: non_constant_identifier_names, avoid_print

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:open_file/open_file.dart';
import 'package:provider/provider.dart';
import 'package:tencent_chat_i18n_tool/tencent_chat_i18n_tool.dart';
import 'package:tencent_cloud_chat_sdk/enum/message_elem_type.dart';
import 'package:tencent_cloud_chat_sdk/enum/message_status.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_group_member_full_info.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_group_member_full_info.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_message.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_message.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/view_models/tui_self_info_view_model.dart';
import 'package:tencent_cloud_chat_uikit/data_services/services_locatar.dart';
import 'package:tencent_cloud_chat_uikit/tencent_cloud_chat_uikit.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/common_utils.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/message.dart';
import 'package:tencent_cloud_chat_uikit/ui/views/TIMUIKitChat/TIMUIKitMessageItem/TIMUIKitMessageReaction/tim_uikit_message_reaction_select_emoji.dart';
import 'package:tencent_cloud_chat_uikit/base_widgets/tim_ui_kit_base.dart';
import 'package:tencent_cloud_chat_uikit/base_widgets/tim_ui_kit_state.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/separate_models/tui_chat_separate_view_model.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/view_models/tui_chat_global_model.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/platform.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/uikit_root_navigator.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/sound_record.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/screen_utils.dart';
import 'package:tencent_cloud_chat_uikit/ui/views/TIMUIKitChat/TIMUIKItMessageList/tim_uikit_chat_history_message_list_item.dart';
import 'package:tencent_cloud_chat_uikit/ui/widgets/forward_message_screen.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:path/path.dart' as path;

import 'package:tencent_cloud_chat_uikit/base_widgets/tim_callback.dart';
import 'package:tencent_cloud_chat_uikit/theme/color.dart';
import 'package:tencent_cloud_chat_uikit/theme/tui_theme.dart';

enum TelegramMobileTooltipLayout {
  combined,
  reactionBarOnly,
  actionMenuOnly,
}

class TIMUIKitMessageTooltip extends StatefulWidget {
  /// tool tips panel configuration, long press message will show tool tips panel
  final ToolTipsConfig? toolTipsConfig;

  /// current message
  final V2TimMessage message;

  /// allow notifi user when send reply message
  final bool allowAtUserWhenReply;

  /// the callback for long press event, except myself avatar
  final Function(String? userId, String? nickName)?
      onLongPressForOthersHeadPortrait;

  /// 回复消息时 @ 对方或仅聚焦输入框（与头像长按菜单分离）。
  final Function(String? userId, String? nickName)? onAtUserWhenReply;

  final bool isUseMessageReaction;

  /// direction
  final SelectEmojiPanelPosition selectEmojiPanelPosition;

  /// on add sticker reaction to a message
  final ValueChanged<int> onSelectSticker;

  /// on close tooltip area
  final VoidCallback onCloseTooltip;

  final TUIChatSeparateViewModel model;

  final bool isShowMoreSticker;

  final V2TimGroupMemberFullInfo? groupMemberInfo;

  final bool iSUseDefaultHoverBar;

  final TelegramMobileTooltipLayout mobileLayout;
  final double? mobileMenuMaxHeight;

  const TIMUIKitMessageTooltip(
      {Key? key,
      this.toolTipsConfig,
      this.isUseMessageReaction = true,
      required this.model,
      required this.message,
      required this.allowAtUserWhenReply,
      this.onLongPressForOthersHeadPortrait,
      this.onAtUserWhenReply,
      required this.selectEmojiPanelPosition,
      required this.onCloseTooltip,
      required this.onSelectSticker,
      this.isShowMoreSticker = false,
      this.groupMemberInfo,
      required this.iSUseDefaultHoverBar,
      this.mobileLayout = TelegramMobileTooltipLayout.combined,
      this.mobileMenuMaxHeight})
      : super(key: key);

  @override
  State<StatefulWidget> createState() => TIMUIKitMessageTooltipState();
}

class TIMUIKitMessageTooltipState
    extends TIMUIKitState<TIMUIKitMessageTooltip> {
  /// 微信风格：每行最多 5 个，图标在上、文案在下。
  static const int mobileTooltipColumns = 5;
  static const double mobileTooltipItemWidth = 56;
  static const double mobileTooltipSpacing = 0;
  static const double mobileTooltipHorizontalPadding = 10;
  static const double mobileTooltipVerticalPadding = 8;
  static const double mobileTooltipContentWidth =
      mobileTooltipColumns * mobileTooltipItemWidth +
          (mobileTooltipColumns - 1) * mobileTooltipSpacing;
  static const double mobileTooltipWidth =
      mobileTooltipContentWidth + mobileTooltipHorizontalPadding * 2;

  /// 单行网格高度（图标 + 间距 + 文案）。
  static const double mobileTelegramMenuRowHeight = 58;
  static const double mobileTelegramReactionBarHeight = 46;
  static const double mobileWeChatMenuCellHeight = 52;

  static double estimateTelegramActionMenuHeight(int itemCount) {
    final count = itemCount <= 0 ? 1 : itemCount;
    final rows = (count / mobileTooltipColumns).ceil();
    return rows * mobileTelegramMenuRowHeight +
        mobileTooltipVerticalPadding * 2;
  }

  static const double _mobileTooltipItemWidth = mobileTooltipItemWidth;

  static double mobileTelegramMenuWidth(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    return min(mobileTooltipWidth, screenWidth - 24);
  }

  static double mobileTooltipContentMaxWidth(BuildContext context) {
    final media = MediaQuery.maybeOf(context);
    final screenWidth = media?.size.width ?? mobileTooltipWidth;
    final limit = screenWidth - 24 - mobileTooltipHorizontalPadding * 2;
    if (limit <= 0) {
      return mobileTooltipContentWidth;
    }
    return min(limit, mobileTooltipContentWidth)
        .clamp(mobileTooltipItemWidth, mobileTooltipContentWidth)
        .toDouble();
  }

  static double mobileTooltipPanelWidth(BuildContext context) {
    return mobileTelegramMenuWidth(context);
  }

  String _tipLabel(String zh) => zh;

  String _stableTipLabel(MessageToolTipItem item) {
    switch (item.id) {
      case 'open':
        return '打开';
      case 'finder':
        return PlatformUtils().isMacOS ? '访达' : '文件夹';
      case 'copyMessage':
        return '拷贝';
      case 'forwardMessage':
        return '转发';
      case 'replyMessage':
        return item.label.contains('回复') ? '回复' : '引用';
      case 'multiSelect':
        return '选择';
      case 'delete':
        return '删除';
      case 'translate':
        return '翻译';
      case 'voiceToText':
        return '转文字';
      case 'revoke':
        return '撤回';
      case 'toggleAudioRoute':
        return SoundPlayer.speakerOn ? '听筒' : '扬声器';
      case 'favorite_message':
        return '收藏';
      case 'add_sticker':
        return '表情';
      default:
        final label = item.label.trim();
        if (label.isEmpty) {
          return '';
        }
        return label;
    }
  }

  final TUIChatGlobalModel globalModal = serviceLocator<TUIChatGlobalModel>();
  final TUISelfInfoViewModel selfInfoViewModel =
      serviceLocator<TUISelfInfoViewModel>();
  bool isShowMoreSticker = false;
  bool fileBeenDownloaded = false;
  String filePath = "";

  bool _isDarkTheme(TUITheme theme) {
    final bg = theme.wideBackgroundColor ?? Colors.white;
    return bg.computeLuminance() < 0.5;
  }

  Color _tooltipSurfaceColor(TUITheme theme) {
    if (_isDarkTheme(theme)) {
      return theme.conversationItemBgColor ?? const Color(0xFF2A2D33);
    }
    return theme.white ?? Colors.white;
  }

  Color _tooltipBorderColor(TUITheme theme) {
    if (_isDarkTheme(theme)) {
      return theme.weakDividerColor ?? const Color(0xFF3A3A3A);
    }
    return hexToColor('dee0e3');
  }

  Color _tooltipLabelColor(TUITheme theme) {
    return _isDarkTheme(theme)
        ? const Color(0xFFEDEDED)
        : const Color(0xFF222222);
  }

  Color _tooltipIconColor(TUITheme theme, MessageToolTipItem item) {
    if (item.iconColor != null) {
      return item.iconColor!;
    }
    return _isDarkTheme(theme)
        ? const Color(0xFFEDEDED)
        : const Color(0xFF333333);
  }

  Widget _buildMobileTooltipGrid(BuildContext context, List<Widget> children) {
    final contentMaxWidth = mobileTooltipContentMaxWidth(context);

    return SizedBox(
      width: contentMaxWidth,
      child: Wrap(
        spacing: mobileTooltipSpacing,
        runSpacing: 6,
        alignment: WrapAlignment.start,
        children: children
            .map(
              (child) => _buildMobileTooltipCell(child),
            )
            .toList(),
      ),
    );
  }

  Widget _buildMobileTooltipCell(Widget child) {
    return SizedBox(
      width: _mobileTooltipItemWidth,
      height: mobileWeChatMenuCellHeight,
      child: ClipRect(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: _mobileTooltipItemWidth,
              maxHeight: mobileWeChatMenuCellHeight,
            ),
            child: child,
          ),
        ),
      ),
    );
  }

  Widget _buildMobileExtraTooltipCell(Widget child) {
    return SizedBox(
      width: _mobileTooltipItemWidth,
      height: mobileWeChatMenuCellHeight,
      child: ClipRect(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.center,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: _mobileTooltipItemWidth,
              maxHeight: mobileWeChatMenuCellHeight,
            ),
            child: child,
          ),
        ),
      ),
    );
  }

  Widget _buildReactionPanel({
    required bool isDesktopScreen,
  }) {
    final panel = TIMUIKitMessageReactionEmojiSelectPanel(
      isShowMoreSticker: isShowMoreSticker,
      onSelect: (int value) => widget.onSelectSticker(value),
      onClickShowMore: (bool value) {
        if (!mounted) {
          return;
        }
        setState(() {
          isShowMoreSticker = value;
        });
      },
    );

    if (isDesktopScreen) {
      return panel;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: panel,
    );
  }

  List<MessageToolTipItem> _orderMobileTooltipItems(
      List<MessageToolTipItem> items) {
    int rank(String id) {
      switch (id) {
        case 'replyMessage':
          return 0;
        case 'copyMessage':
          return 1;
        case 'forwardMessage':
          return 2;
        case 'revoke':
          return 3;
        case 'translate':
          return 4;
        case 'voiceToText':
          return 4;
        case 'toggleAudioRoute':
          return 5;
        case 'open':
          return 6;
        case 'finder':
          return 7;
        case 'favorite_message':
          return 8;
        case 'add_sticker':
          return 9;
        case 'sangong_stats':
          return 10;
        default:
          return 50;
      }
    }

    final deleteItems = items.where((e) => e.id == 'delete').toList();
    final multiItems = items.where((e) => e.id == 'multiSelect').toList();
    final bankerItems =
        items.where((e) => e.id == 'sangong_quick_setup_banker').toList();
    final others = items
        .where((e) =>
            e.id != 'delete' &&
            e.id != 'multiSelect' &&
            e.id != 'sangong_quick_setup_banker')
        .toList();
    others.sort((a, b) => rank(a.id).compareTo(rank(b.id)));
    return [
      ...others,
      ...deleteItems,
      ...multiItems,
      ...bankerItems,
    ];
  }

  Widget _buildMobileActionIcon(
    MessageToolTipItem item,
    TUITheme theme,
    Set<String> defaultTipsIds,
    Color color,
  ) {
    if (item.icon != null) {
      return Icon(item.icon, size: 22, color: color);
    }
    if (item.iconImageAsset != null) {
      Widget image = Image.asset(
        item.iconImageAsset!,
        package: defaultTipsIds.contains(item.id)
            ? 'tencent_cloud_chat_uikit'
            : null,
        width: 22,
        height: 22,
      );
      // 微信深色菜单：浅色主题下也要把资源图标染成面板前景色。
      if (item.iconColor == null) {
        image = ColorFiltered(
          colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
          child: image,
        );
      }
      return image;
    }
    return Icon(Icons.more_horiz_rounded, size: 22, color: color);
  }

  /// 微信风格操作格：图标在上、文案在下；深色面板上统一浅色字。
  Widget _buildWeChatActionCell(
    MessageToolTipItem item,
    TUITheme theme,
    Set<String> defaultTipsIds,
  ) {
    // 对齐微信：深色菜单内删除也用浅色，靠文案区分危险操作。
    final color = item.iconColor ?? const Color(0xFFFFFFFF);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        HapticFeedback.selectionClick();
        item.onClick();
      },
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildMobileActionIcon(item, theme, defaultTipsIds, color),
          const SizedBox(height: 4),
          Text(
            _stableTipLabel(item),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 10,
              height: 1.1,
              color: color,
              fontWeight: FontWeight.w400,
              decoration: TextDecoration.none,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTelegramActionMenu(
    BuildContext context,
    List<MessageToolTipItem> items,
    TUITheme theme,
    Widget? extraTipsActionItem, {
    double? maxHeight,
  }) {
    final ordered = _orderMobileTooltipItems(items);
    final defaultTipsIds = ordered.map((e) => e.id).toSet();

    final grid = Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: mobileTooltipHorizontalPadding,
        vertical: mobileTooltipVerticalPadding,
      ),
      child: _buildMobileTooltipGrid(
        context,
        [
          for (final item in ordered)
            _buildWeChatActionCell(item, theme, defaultTipsIds),
          if (extraTipsActionItem != null) extraTipsActionItem,
        ],
      ),
    );

    final menuWidth = mobileTelegramMenuWidth(context);
    if (maxHeight == null) {
      return SizedBox(width: menuWidth, child: grid);
    }

    return SizedBox(
      width: menuWidth,
      height: maxHeight,
      child: SingleChildScrollView(
        physics: const ClampingScrollPhysics(),
        child: grid,
      ),
    );
  }

  Widget _toolTipLeadingIcon(
    MessageToolTipItem item,
    TUITheme theme,
    Set<String> defaultTipsIds,
  ) {
    final iconColor = _tooltipIconColor(theme, item);
    if (item.icon != null) {
      return Icon(
        item.icon,
        size: 18,
        color: iconColor,
      );
    }
    Widget image = Image.asset(
      item.iconImageAsset!,
      package:
          defaultTipsIds.contains(item.id) ? 'tencent_cloud_chat_uikit' : null,
      width: 18,
      height: 18,
    );
    if (_isDarkTheme(theme) && item.iconColor == null) {
      image = ColorFiltered(
        colorFilter: ColorFilter.mode(iconColor, BlendMode.srcIn),
        child: image,
      );
    }
    return image;
  }

  List<Widget> _buildDesktopTooltipWidgets(
    List<MessageToolTipItem> formattedTipsList,
    TUITheme theme,
  ) {
    final defaultTipsIds = formattedTipsList.map((e) => e.id).toSet();
    final labelColor = _tooltipLabelColor(theme);

    return formattedTipsList
        .map(
          (item) => Material(
            type: MaterialType.transparency,
            child: InkWell(
              onTap: () {
                HapticFeedback.selectionClick();
                item.onClick();
              },
              child: Container(
                padding: const EdgeInsets.all(6),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _toolTipLeadingIcon(item, theme, defaultTipsIds),
                    const SizedBox(
                      height: 4,
                      width: 8,
                    ),
                    Text(
                      _stableTipLabel(item),
                      style: TextStyle(
                        decoration: TextDecoration.none,
                        color: labelColor,
                        fontSize: 12,
                      ),
                    )
                  ],
                ),
              ),
            ),
          ),
        )
        .toList();
  }

  @override
  void initState() {
    super.initState();
    hasFile();
    isShowMoreSticker = widget.isShowMoreSticker;
    SoundPlayer.outputRouteListenable.addListener(_onVoiceOutputRouteChanged);
  }

  @override
  void dispose() {
    SoundPlayer.outputRouteListenable
        .removeListener(_onVoiceOutputRouteChanged);
    super.dispose();
  }

  void _onVoiceOutputRouteChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  hasFile() {
    if (PlatformUtils().isMobile ||
        (widget.message.fileElem == null &&
            widget.message.imageElem == null &&
            widget.message.videoElem == null)) {
      fileBeenDownloaded = false;
      return;
    }
    if (PlatformUtils().isWeb) {
      fileBeenDownloaded = true;
      return;
    }
    if (PlatformUtils().isDesktop) {
      if (widget.message.fileElem != null) {
        String savePath = TencentUtils.checkString(
                globalModal.getFileMessageLocation(widget.message.msgID)) ??
            TencentUtils.checkString(widget.message.fileElem!.localUrl) ??
            widget.message.fileElem?.path ??
            "";
        File f = File(savePath);
        if (f.existsSync() && widget.message.msgID != null) {
          filePath = savePath;
          fileBeenDownloaded = true;
          return;
        }
      } else if (widget.message.imageElem != null) {
        if (TencentUtils.checkString(
                    widget.message.imageElem!.imageList![0]!.localUrl) !=
                null &&
            File(widget.message.imageElem!.imageList![0]!.localUrl!)
                .existsSync()) {
          fileBeenDownloaded = true;
          return;
        }
      } else if (widget.message.videoElem != null) {
        if (TencentUtils.checkString(widget.message.videoElem!.localVideoUrl) !=
                null &&
            File(widget.message.videoElem!.localVideoUrl!).existsSync()) {
          fileBeenDownloaded = true;
          return;
        }
      }
    }
    fileBeenDownloaded = false;
  }

  bool isRevocable(int timestamp, int upperTimeLimit) =>
      ((DateTime.now().millisecondsSinceEpoch / 1000).ceil() - timestamp <
          upperTimeLimit) &&
      (widget.message.isSelf ?? true);

  Widget ItemInkWell({
    required TUITheme theme,
    Widget? child,
    GestureTapCallback? onTap,
  }) {
    return SizedBox(
      width: _mobileTooltipItemWidth,
      child: InkWell(
        onTap: onTap,
        splashColor: _isDarkTheme(theme)
            ? Colors.white.withValues(alpha: 0.08)
            : Colors.black12,
        child: Container(
          padding: const EdgeInsets.only(bottom: 6, top: 6),
          child: child,
        ),
      ),
    );
  }

  bool isAdminCanRecall() {
    if (widget.model.chatConfig.isGroupAdminRecallEnabled) {
      final selfMemberInfo =
          widget.groupMemberInfo ?? widget.model.selfMemberInfo;
      return GroupRolePolicy.isManagerRole(selfMemberInfo?.role);
    } else {
      return false;
    }
  }

  List<MessageToolTipItem> _collectTooltipItems(
      TUITheme theme, TUIChatSeparateViewModel model, V2TimMessage message) {
    final isDesktopScreen =
        TUIKitScreenUtils.getFormFactor(context) == DeviceType.Desktop;
    final messageTimestamp = widget.message.timestamp;
    final isOwnMessage = widget.message.isSelf ?? false;
    final isCanRevokeSelf = isOwnMessage &&
        (messageTimestamp == null ||
            isRevocable(messageTimestamp, model.chatConfig.upperRecallTime));
    final shouldShowRevokeAction = (isCanRevokeSelf || isAdminCanRecall()) &&
        widget.message.status != MessageStatus.V2TIM_MSG_STATUS_SEND_FAIL &&
        !model.isWalletCardMessage(widget.message);
    final shouldShowReplyAction = !(widget.message.customElem?.data != null &&
        MessageUtils.isCallingData(widget.message.customElem!.data!));
    final shouldShowForwardAction = !(widget.message.customElem?.data != null &&
            MessageUtils.isCallingData(widget.message.customElem!.data!)) &&
        !model.isWalletCardMessage(widget.message) &&
        !model.isContactCardMessage(widget.message);
    final tooltipsConfig = widget.toolTipsConfig;
    final messageCanCopy = widget.message.elemType ==
            MessageElemType.V2TIM_ELEM_TYPE_TEXT ||
        (isDesktopScreen &&
            widget.message.elemType == MessageElemType.V2TIM_ELEM_TYPE_IMAGE &&
            fileBeenDownloaded);
    bool showTranslation = true;
    if (widget.message.localCustomData != null) {
      final LocalCustomDataModel localCustomData = LocalCustomDataModel.fromMap(
          json.decode(
              TencentUtils.checkString(widget.message.localCustomData) ??
                  "{}"));
      if (localCustomData.translatedText != null &&
          localCustomData.translatedText != "") {
        showTranslation = false;
      }
    }
    bool showVoiceToText =
        widget.message.elemType == MessageElemType.V2TIM_ELEM_TYPE_SOUND;
    if (widget.message.localCustomData != null) {
      final LocalCustomDataModel voiceCustomData = LocalCustomDataModel.fromMap(
          json.decode(
              TencentUtils.checkString(widget.message.localCustomData) ??
                  "{}"));
      if (TencentUtils.checkString(voiceCustomData.voiceToText) != null ||
          voiceCustomData.voiceToTextStatus == 'loading') {
        showVoiceToText = false;
      }
    }

    final dynamicQuote =
        model.chatConfig.isAtWhenReplyDynamic?.call(widget.message);

    final bool showAudioRouteToggle =
        widget.message.elemType == MessageElemType.V2TIM_ELEM_TYPE_SOUND &&
            PlatformUtils().isMobile;

    final List<MessageToolTipItem> defaultTipsList = [
      if (showAudioRouteToggle)
        MessageToolTipItem(
          label: SoundPlayer.speakerOn ? _tipLabel('听筒') : _tipLabel('扬声器'),
          id: 'toggleAudioRoute',
          icon: SoundPlayer.speakerOn
              ? Icons.hearing_rounded
              : Icons.volume_up_rounded,
          onClick: () async {
            HapticFeedback.selectionClick();
            widget.onCloseTooltip();
            await SoundPlayer.toggleSpeaker();
          },
        ),
      if (fileBeenDownloaded)
        MessageToolTipItem(
            label: _tipLabel("打开"),
            id: "open",
            iconImageAsset: "images/open_in_new.png",
            onClick: () => _onTap("open", model)),
      if (fileBeenDownloaded && PlatformUtils().isDesktop)
        MessageToolTipItem(
            label: PlatformUtils().isMacOS ? TIM_t("在访达中打开") : TIM_t("查看文件夹"),
            id: "finder",
            iconImageAsset: "images/folder_open.png",
            onClick: () => _onTap("finder", model)),
      if (messageCanCopy)
        MessageToolTipItem(
            label: _tipLabel("复制"),
            id: "copyMessage",
            iconImageAsset: "images/copy_message.png",
            onClick: () => _onTap("copyMessage", model)),
      if (shouldShowForwardAction &&
          _singleForwardUnsupportedText(widget.message, model) == null)
        MessageToolTipItem(
            label: _tipLabel("转发"),
            id: "forwardMessage",
            iconImageAsset: "images/forward_message.png",
            onClick: () => _onTap("forwardMessage", model)),
      if (shouldShowReplyAction)
        MessageToolTipItem(
            label: (dynamicQuote ?? model.chatConfig.isAtWhenReply)
                ? _tipLabel("回复")
                : _tipLabel("引用"),
            id: "replyMessage",
            iconImageAsset: "images/reply_message.png",
            onClick: () => _onTap("replyMessage", model)),
      MessageToolTipItem(
          label: _tipLabel("多选"),
          id: "multiSelect",
          iconImageAsset: "images/multi_message.png",
          onClick: () => _onTap("multiSelect", model)),
      MessageToolTipItem(
          label: _tipLabel("删除"),
          id: "delete",
          iconImageAsset: "images/delete_message.png",
          onClick: () => _onTap("delete", model)),
      if (showTranslation)
        MessageToolTipItem(
            label: _tipLabel("翻译"),
            id: "translate",
            iconImageAsset: "images/translate.png",
            onClick: () => _onTap("translate", model)),
      if (showVoiceToText)
        MessageToolTipItem(
            label: _tipLabel("转文字"),
            id: "voiceToText",
            icon: Icons.text_fields_rounded,
            onClick: () => _onTap("voiceToText", model)),
      if (shouldShowRevokeAction)
        MessageToolTipItem(
            label: _tipLabel("撤回"),
            id: "revoke",
            iconImageAsset: "images/revoke_message.png",
            onClick: () => _onTap("revoke", model)),
    ];

    List<MessageToolTipItem> defaultFormattedTipsList = defaultTipsList;
    if (tooltipsConfig != null) {
      defaultFormattedTipsList = defaultTipsList.where((element) {
        final type = element.id;
        if (type == "copyMessage") {
          return tooltipsConfig.showCopyMessage;
        }
        if (type == "forwardMessage") {
          return tooltipsConfig.showForwardMessage &&
              !(isDesktopScreen && widget.iSUseDefaultHoverBar);
        }
        if (type == "replyMessage") {
          return tooltipsConfig.showReplyMessage &&
              !(isDesktopScreen && widget.iSUseDefaultHoverBar);
        }
        if (type == "delete") {
          return (!PlatformUtils().isWeb) && tooltipsConfig.showDeleteMessage;
        }
        if (type == "multiSelect") {
          return tooltipsConfig.showMultipleChoiceMessage;
        }

        if (type == "revoke") {
          return shouldShowRevokeAction &&
              (PlatformUtils().isMobile || tooltipsConfig.showRecallMessage);
        }
        if (type == "translate") {
          return tooltipsConfig.showTranslation &&
              widget.message.elemType == MessageElemType.V2TIM_ELEM_TYPE_TEXT;
        }
        if (type == "voiceToText") {
          return widget.message.elemType ==
              MessageElemType.V2TIM_ELEM_TYPE_SOUND;
        }
        return true;
      }).toList();
    }

    final List<MessageToolTipItem>? customList =
        widget.toolTipsConfig?.additionalMessageToolTips != null
            ? (widget.toolTipsConfig?.additionalMessageToolTips!(
                message, widget.onCloseTooltip))
            : [];

    List<MessageToolTipItem> formattedTipsList = [
      ...defaultFormattedTipsList,
      ...?customList,
    ];

    if (formattedTipsList.isEmpty && widget.isUseMessageReaction == false) {
      widget.onCloseTooltip();
    }

    return formattedTipsList;
  }

  _onOpenDesktop(String path) {
    try {
      if (PlatformUtils().isDesktop && !PlatformUtils().isWindows) {
        launchUrl(Uri.file(path));
      } else {
        OpenFile.open(path);
      }
      // ignore: empty_catches
    } catch (e) {}
  }

  V2TimMessage? _findLatestMessageSnapshot(TUIChatSeparateViewModel model) {
    final list = globalModal.messageListMap[model.conversationID];
    if (list == null || list.isEmpty) {
      return null;
    }

    final current = widget.message;
    final currentMsgID = TencentUtils.checkString(current.msgID);
    if (currentMsgID != null) {
      for (final item in list) {
        if (item.msgID == currentMsgID) {
          return item;
        }
      }
    }

    final currentLocalID = TencentUtils.checkString(current.id);
    if (currentLocalID != null) {
      for (final item in list) {
        if (item.id == currentLocalID) {
          return item;
        }
      }
    }

    final currentText = TencentUtils.checkString(current.textElem?.text);
    final currentTimestamp = current.timestamp;
    final currentSender = TencentUtils.checkString(current.sender);
    if (currentText != null && currentTimestamp != null) {
      for (final item in list.reversed) {
        if (item.elemType == current.elemType &&
            item.textElem?.text == currentText &&
            item.timestamp == currentTimestamp &&
            (currentSender == null || item.sender == currentSender) &&
            TencentUtils.checkString(item.msgID) != null) {
          return item;
        }
      }
    }

    return null;
  }

  String? _messageMsgId(TUIChatSeparateViewModel model) {
    final raw = TencentUtils.checkString(widget.message.msgID);
    if (raw != null) {
      return raw;
    }

    final latest = _findLatestMessageSnapshot(model);
    final latestMsgID = TencentUtils.checkString(latest?.msgID);
    if (latestMsgID != null) {
      return latestMsgID;
    }

    return null;
  }

  bool _requireMsgId(String? msgID) {
    if (msgID != null && msgID.isNotEmpty) {
      return true;
    }
    onTIMCallback(TIMCallback(
      type: TIMCallbackType.INFO,
      infoRecommendText: TIM_t("消息状态同步中，请稍后再试"),
      infoCode: 6660410,
    ));
    return false;
  }

  String? _singleForwardUnsupportedText(
    V2TimMessage message,
    TUIChatSeparateViewModel model,
  ) {
    if (message.status == MessageStatus.V2TIM_MSG_STATUS_SEND_FAIL) {
      return TIM_t("发送失败消息不支持转发！");
    }
    if (message.elemType == MessageElemType.V2TIM_ELEM_TYPE_GROUP_TIPS) {
      return TIM_t("系统消息不支持转发！");
    }
    if (model.isVoteMessage(message)) {
      return TIM_t("投票消息不支持转发！");
    }
    if (model.isWalletCardMessage(message)) {
      return TIM_t("钱包消息不可转发");
    }
    if (model.isContactCardMessage(message)) {
      return TIM_t("个人名片不支持转发！");
    }
    return null;
  }

  void _onForwardMessageTap(
    TUIChatSeparateViewModel model, {
    NavigatorState? navigator,
  }) {
    final unsupportedText =
        _singleForwardUnsupportedText(widget.message, model);
    if (unsupportedText != null) {
      onTIMCallback(TIMCallback(
        type: TIMCallbackType.INFO,
        infoRecommendText: unsupportedText,
        infoCode: 6660413,
      ));
      return;
    }
    model.updateMultiSelectStatus(false);
    model.setMessageItemChecked(widget.message, true);
    final resolvedNavigator =
        navigator ?? resolveUIKitRootNavigator(context);
    if (resolvedNavigator == null) {
      onTIMCallback(TIMCallback(
        type: TIMCallbackType.INFO,
        infoRecommendText: TIM_t("当前页面暂不可打开转发"),
        infoCode: 6660414,
      ));
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      resolvedNavigator.push(MaterialPageRoute(
          builder: (context) => ForwardMessageScreen(
                conversationType: model.conversationType ?? ConvType.c2c,
                model: model,
              )));
    });
  }

  Future<bool> _confirmDestructiveAction({
    required NavigatorState navigator,
    required String title,
    required String message,
  }) async {
    if (!navigator.mounted) {
      return false;
    }
    final result = await showCupertinoDialog<bool>(
      context: navigator.context,
      useRootNavigator: false,
      barrierDismissible: true,
      builder: (ctx) => CupertinoAlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(TIM_t('取消')),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(title),
          ),
        ],
      ),
    );
    return result == true;
  }

  Future<void> _executeDelete({
    required TUIChatSeparateViewModel model,
    required String msgID,
    required V2TimMessage messageItem,
  }) async {
    model.deleteMsg(
      msgID,
      id: messageItem.id?.toString(),
      webMessageInstance: messageItem.messageFromWeb,
    );
  }

  Future<void> _executeRevoke({
    required TUIChatSeparateViewModel model,
    required String msgID,
    required V2TimMessage messageItem,
  }) async {
    final timestamp = messageItem.timestamp ?? widget.message.timestamp;
    final isOwnMessage =
        messageItem.isSelf ?? widget.message.isSelf ?? false;
    final needAdminRecall = !isOwnMessage ||
        (timestamp != null &&
            !isRevocable(timestamp, model.chatConfig.upperRecallTime));
    unawaited(model.revokeMsg(
      msgID,
      needAdminRecall,
      messageItem.messageFromWeb,
    ));
  }

  Future<void> _onTap(String operation, TUIChatSeparateViewModel model) async {
    final rootNavigator = resolveUIKitRootNavigator(context);
    final overlay = Overlay.maybeOf(context, rootOverlay: true);

    if (operation == "forwardMessage") {
      _onForwardMessageTap(model, navigator: rootNavigator);
      widget.onCloseTooltip();
      return;
    }

    final messageItem = _findLatestMessageSnapshot(model) ?? widget.message;
    final msgID = _messageMsgId(model);

    if (operation == 'delete' || operation == 'revoke') {
      if (!_requireMsgId(msgID)) {
        return;
      }
      final isDelete = operation == 'delete';
      final title = _tipLabel(isDelete ? '删除' : '撤回');
      final confirmMessage = TIM_t(
        isDelete ? '确定删除这条消息吗？' : '确定撤回这条消息吗？',
      );
      // 先关菜单再出确认框，避免和 Overlay 拆层抢同一手势。
      widget.onCloseTooltip();

      bool confirmed = false;
      if (overlay != null) {
        confirmed = await showUIKitOverlayConfirmDialog(
          overlay: overlay,
          title: title,
          message: confirmMessage,
          cancelLabel: TIM_t('取消'),
          confirmLabel: title,
        );
      } else if (rootNavigator != null) {
        if (!rootNavigator.mounted) {
          return;
        }
        confirmed = await _confirmDestructiveAction(
          navigator: rootNavigator,
          title: title,
          message: confirmMessage,
        );
      } else {
        onTIMCallback(TIMCallback(
          type: TIMCallbackType.INFO,
          infoRecommendText: TIM_t("当前页面暂不可执行该操作"),
          infoCode: 6660414,
        ));
        return;
      }
      if (!confirmed) {
        return;
      }
      try {
        if (isDelete) {
          await _executeDelete(
            model: model,
            msgID: msgID!,
            messageItem: messageItem,
          );
        } else {
          await _executeRevoke(
            model: model,
            msgID: msgID!,
            messageItem: messageItem,
          );
        }
      } catch (e) {
        onTIMCallback(TIMCallback(
          type: TIMCallbackType.INFO,
          infoRecommendText: TIM_t("当前消息暂不支持该操作"),
          infoCode: 6660412,
        ));
      }
      return;
    }

    // Capture locals before close — tooltip may dispose with the overlay.
    final message = widget.message;
    final copyText = message.textElem?.text ?? '';
    final canCopyText =
        message.elemType == MessageElemType.V2TIM_ELEM_TYPE_TEXT;
    final fileLocal = TencentUtils.checkString(
            globalModal.getFileMessageLocation(message.msgID)) ??
        TencentUtils.checkString(message.fileElem?.localUrl) ??
        message.fileElem?.path ??
        '';
    final imageLocal = TencentUtils.checkString(
            message.imageElem?.imageList?[0]?.localUrl) ??
        TencentUtils.checkString(message.imageElem?.path) ??
        '';
    final videoLocal =
        TencentUtils.checkString(message.videoElem?.localVideoUrl) ??
            TencentUtils.checkString(message.videoElem?.videoPath) ??
            '';
    final sender = message.sender;
    final dynamicQuote =
        model.chatConfig.isAtWhenReplyDynamic?.call(message);
    final isSelf = message.isSelf ?? true;
    final isGroup = TencentUtils.checkString(message.groupID) != null;
    final allowAt = widget.allowAtUserWhenReply;
    final onLongPressPortrait = widget.onLongPressForOthersHeadPortrait;
    final onAtUser = widget.onAtUserWhenReply;
    final displayName = model.getGroupMessageDisplayName(message);

    widget.onCloseTooltip();

    try {
      switch (operation) {
        case "open":
          if (message.fileElem != null) {
            _onOpenDesktop(fileLocal);
          } else if (message.imageElem != null) {
            _onOpenDesktop(imageLocal);
          } else if (message.videoElem != null) {
            _onOpenDesktop(videoLocal);
          }
          break;
        case "finder":
          final savePath = message.fileElem != null
              ? fileLocal
              : message.imageElem != null
                  ? imageLocal
                  : message.videoElem != null
                      ? videoLocal
                      : '';
          if (savePath.isNotEmpty) {
            _onOpenDesktop(path.dirname(savePath));
          }
          break;
        case 'translate':
          model.translateText(message);
          break;
        case 'voiceToText':
          model.convertVoiceMessageToText(message);
          break;
        case "multiSelect":
          model.updateMultiSelectStatus(true);
          model.setMessageItemChecked(message, true);
          break;
        case "copyMessage":
          if (canCopyText) {
            await Clipboard.setData(ClipboardData(text: copyText));
            onTIMCallback(TIMCallback(
                type: TIMCallbackType.INFO,
                infoRecommendText: TIM_t("已复制"),
                infoCode: 6660408));
          }
          break;
        case "replyMessage":
          model.repliedMessage = message;
          final isAtWhenReply = !isSelf &&
              isGroup &&
              (dynamicQuote ?? allowAt) &&
              onLongPressPortrait != null;

          final atWhenReply = onAtUser ?? onLongPressPortrait;
          atWhenReply?.call(
            !isAtWhenReply ? null : sender,
            !isAtWhenReply ? null : displayName,
          );
          break;
        default:
          onTIMCallback(TIMCallback(
              type: TIMCallbackType.INFO,
              infoRecommendText: TIM_t("暂未实现"),
              infoCode: 6660409));
      }
    } catch (e) {
      onTIMCallback(TIMCallback(
        type: TIMCallbackType.INFO,
        infoRecommendText: TIM_t("当前消息暂不支持该操作"),
        infoCode: 6660412,
      ));
    }
  }

  @override
  Widget tuiBuild(BuildContext context, TUIKitBuildValue value) {
    final TUITheme theme = value.theme;
    final isDesktopScreen =
        TUIKitScreenUtils.getFormFactor(context) == DeviceType.Desktop;
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: widget.model),
      ],
      builder: (BuildContext context, Widget? w) {
        final TUIChatSeparateViewModel model =
            Provider.of<TUIChatSeparateViewModel>(context);
        final bool haveExtraTipsConfig = widget.toolTipsConfig != null &&
            widget.toolTipsConfig?.additionalItemBuilder != null;
        Widget? extraTipsActionItem = haveExtraTipsConfig
            ? widget.toolTipsConfig!.additionalItemBuilder!(
                widget.message, widget.onCloseTooltip, null, context)
            : null;
        final message = widget.message;
        final tooltipItems = _collectTooltipItems(theme, model, message);
        final isSelf = message.isSelf ?? true;
        final showReactionPanel = widget.isUseMessageReaction;
        final reactionUp =
            widget.selectEmojiPanelPosition == SelectEmojiPanelPosition.up;

        if (!isDesktopScreen) {
          if (widget.mobileLayout ==
              TelegramMobileTooltipLayout.reactionBarOnly) {
            if (!showReactionPanel) {
              return const SizedBox.shrink();
            }
            if (isShowMoreSticker) {
              return _buildReactionPanel(isDesktopScreen: false);
            }
            return _buildReactionPanel(isDesktopScreen: false);
          }
          if (widget.mobileLayout ==
              TelegramMobileTooltipLayout.actionMenuOnly) {
            return _buildTelegramActionMenu(
              context,
              tooltipItems,
              theme,
              extraTipsActionItem,
              maxHeight: widget.mobileMenuMaxHeight,
            );
          }

          if (showReactionPanel && isShowMoreSticker) {
            return _buildReactionPanel(isDesktopScreen: false);
          }

          final tooltipColumn = Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment:
                isSelf ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              if (showReactionPanel && reactionUp) ...[
                _buildReactionPanel(isDesktopScreen: false),
                const SizedBox(height: 8),
              ],
              if (isShowMoreSticker == false)
                _buildTelegramActionMenu(
                  context,
                  tooltipItems,
                  theme,
                  extraTipsActionItem,
                ),
              if (showReactionPanel && !reactionUp) ...[
                const SizedBox(height: 8),
                _buildReactionPanel(isDesktopScreen: false),
              ],
            ],
          );

          return LayoutBuilder(
            builder: (context, constraints) {
              final media = MediaQuery.of(context);
              final fallbackMaxHeight = media.size.height * 0.62;
              final maxHeight =
                  constraints.hasBoundedHeight && constraints.maxHeight.isFinite
                      ? constraints.maxHeight
                      : fallbackMaxHeight;

              return ConstrainedBox(
                constraints: BoxConstraints(maxHeight: maxHeight),
                child: SingleChildScrollView(
                  physics: const ClampingScrollPhysics(),
                  child: tooltipColumn,
                ),
              );
            },
          );
        }

        final desktopTooltipItems =
            _buildDesktopTooltipWidgets(tooltipItems, theme);
        final tooltipBody = Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (showReactionPanel && reactionUp)
                _buildReactionPanel(isDesktopScreen: isDesktopScreen),
              Table(
                columnWidths: const <int, TableColumnWidth>{
                  0: IntrinsicColumnWidth(),
                },
                children: <TableRow>[
                  ...desktopTooltipItems.map(
                    (e) => TableRow(children: <Widget>[e]),
                  )
                ],
              ),
              if (showReactionPanel && !reactionUp)
                _buildReactionPanel(isDesktopScreen: isDesktopScreen),
            ],
          ),
        );

        return IntrinsicWidth(child: tooltipBody);
      },
    );
  }
}
