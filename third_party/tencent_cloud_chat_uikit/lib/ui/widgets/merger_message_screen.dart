import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:provider/provider.dart';
import 'package:tencent_chat_i18n_tool/tencent_chat_i18n_tool.dart';
import 'package:tencent_cloud_chat_sdk/enum/message_elem_type.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_message.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_message.dart';
import 'package:tencent_cloud_chat_uikit/base_widgets/tim_ui_kit_state.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/common_utils.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/message.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/screen_utils.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/chat_message_preview_image_resolver.dart';
import 'package:tencent_cloud_chat_uikit/ui/views/TIMUIKitChat/TIMUIKItMessageList/tim_uikit_chat_history_message_list_item.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/separate_models/tui_chat_separate_view_model.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/view_models/tui_chat_global_model.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/view_models/chat_ui_state_store.dart';
import 'package:tencent_cloud_chat_uikit/data_services/services_locatar.dart';
import 'package:tencent_cloud_chat_uikit/ui/views/TIMUIKitChat/TIMUIKitMessageItem/main.dart';
import 'package:tencent_cloud_chat_uikit/ui/views/TIMUIKitChat/TIMUIKitMessageItem/tim_uikit_chat_face_elem.dart';
import 'package:tencent_cloud_chat_uikit/ui/views/TIMUIKitChat/tim_uikit_cloud_custom_data.dart';
import 'package:tencent_cloud_chat_uikit/ui/widgets/avatar.dart';
import 'package:tencent_cloud_chat_uikit/base_widgets/tim_ui_kit_base.dart';
import 'package:tencent_cloud_chat_uikit/theme/tui_theme.dart';
import 'package:tencent_cloud_chat_uikit/theme/tui_theme_view_model.dart';

/// [MergerMessageScreen] is pushed outside [TIMUIKitChatProviderScope]; message
/// widgets (watermark, read receipt) still need [TUIChatGlobalModel] in the tree.
Widget wrapMergerMessageScreenWithProviders(MergerMessageScreen screen) {
  return ChangeNotifierProvider<TUIChatGlobalModel>.value(
    value: serviceLocator<TUIChatGlobalModel>(),
    child: ChangeNotifierProvider<ChatUiStateStore>.value(
      value: serviceLocator<ChatUiStateStore>(),
      child: screen,
    ),
  );
}

class MergerMessageScreen extends StatefulWidget {
  final TUIChatSeparateViewModel model;
  final String msgID;
  final MessageItemBuilder? messageItemBuilder;

  /// Desktop popup passes the same controller as the outer [Scrollbar].
  final ScrollController? scrollController;

  const MergerMessageScreen({
    Key? key,
    required this.model,
    required this.msgID,
    this.messageItemBuilder,
    this.scrollController,
  }) : super(key: key);

  @override
  State<StatefulWidget> createState() => MergerMessageScreenState();
}

class MergerMessageScreenState extends TIMUIKitState<MergerMessageScreen> {
  List<V2TimMessage> messageList = [];
  bool _loadFailed = false;

  @override
  initState() {
    super.initState();
    initMessageList();
  }

  void initMessageList() async {
    if (widget.msgID.isEmpty) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loadFailed = true;
        messageList = [];
      });
      return;
    }
    final mergerMessageList =
        await widget.model.downloadMergerMessage(widget.msgID);
    if (!mounted) {
      return;
    }
    final resolvedMessages = mergerMessageList ?? <V2TimMessage>[];
    // 合并消息里的图片通常只有 msgID，没有可直接渲染的 URL/localUrl；
    // 与普通聊天气泡一致，先补齐原图/缩略图资源再展示，避免灰色封面。
    for (final message in resolvedMessages) {
      if (message.imageElem != null) {
        await ChatMessagePreviewImageResolver.refreshOriginal(message);
      }
    }
    if (!mounted) return;
    setState(() {
      messageList = resolvedMessages;
      _loadFailed = mergerMessageList == null;
    });
  }

  Widget? _tryItemBuilder(
    Widget? Function(V2TimMessage, bool, void Function())? builder,
    V2TimMessage message,
  ) {
    if (builder == null) {
      return null;
    }
    return builder(message, false, () {});
  }

  bool isReplyMessage(V2TimMessage message) {
    final hasCustomData = message.cloudCustomData != null && message.cloudCustomData != "";
    if (hasCustomData) {
      try {
        final CloudCustomData messageCloudCustomData = CloudCustomData.fromJson(
            json.decode(TencentUtils.checkString(message.cloudCustomData) != null ? message.cloudCustomData! : "{}"));
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

  Widget _getMsgItem(V2TimMessage message) {
    final type = message.elemType;
    final isFromSelf = message.isSelf ?? true;
    final builders = widget.messageItemBuilder;

    switch (type) {
      case MessageElemType.V2TIM_ELEM_TYPE_CUSTOM:
        final custom =
            _tryItemBuilder(builders?.customMessageItemBuilder, message);
        if (custom != null) {
          return custom;
        }
        final summary = MessageUtils.getAbstractMessageAsync(message, []);
        return Text(summary.isNotEmpty ? summary : TIM_t("[自定义]"));
      case MessageElemType.V2TIM_ELEM_TYPE_SOUND:
        final custom =
            _tryItemBuilder(builders?.soundMessageItemBuilder, message);
        if (custom != null) {
          return custom;
        }
        if (message.soundElem == null) {
          return Text(TIM_t("[语音]"));
        }
        return TIMUIKitSoundElem(
            chatModel: widget.model,
            isShowMessageReaction: false,
            message: message,
            soundElem: message.soundElem!,
            msgID: message.msgID ?? "",
            isFromSelf: isFromSelf,
            localCustomInt: message.localCustomInt);
      case MessageElemType.V2TIM_ELEM_TYPE_TEXT:
        if (isReplyMessage(message)) {
          return _tryItemBuilder(
                builders?.textReplyMessageItemBuilder, message) ??
              TIMUIKitReplyElem(
                  isShowMessageReaction: false,
                  chatModel: widget.model,
                  message: message,
                  scrollToIndex: () {},
                  clearJump: () {});
        }
        return _tryItemBuilder(builders?.textMessageItemBuilder, message) ??
            TIMUIKitTextElem(
              chatModel: widget.model,
              message: message,
              isFromSelf: message.isSelf ?? true,
              clearJump: () {},
              isShowJump: false,
              isShowMessageReaction: false,
            );
      case MessageElemType.V2TIM_ELEM_TYPE_FACE:
        return _tryItemBuilder(builders?.faceMessageItemBuilder, message) ??
            TIMUIKitFaceElem(
                model: widget.model,
                isShowJump: false,
                isShowMessageReaction: false,
                path: message.faceElem?.data ?? "",
                message: message);
      case MessageElemType.V2TIM_ELEM_TYPE_FILE:
        return _tryItemBuilder(builders?.fileMessageItemBuilder, message) ??
            TIMUIKitFileElem(
                chatModel: widget.model,
                isShowMessageReaction: false,
                message: message,
                messageID: message.msgID,
                fileElem: message.fileElem,
                isSelf: isFromSelf,
                isShowJump: false);
      case MessageElemType.V2TIM_ELEM_TYPE_IMAGE:
        final custom =
            _tryItemBuilder(builders?.imageMessageItemBuilder, message);
        if (custom != null) {
          return custom;
        }
        if (message.imageElem == null) {
          return Text(TIM_t("[图片]"));
        }
        return TIMUIKitImageElem(
          chatModel: widget.model,
          isShowMessageReaction: false,
          message: message,
          isFrom: "merger",
          key: Key("${message.seq}_${message.timestamp}"),
        );
      case MessageElemType.V2TIM_ELEM_TYPE_VIDEO:
        final custom =
            _tryItemBuilder(builders?.videoMessageItemBuilder, message);
        if (custom != null) {
          return custom;
        }
        if (message.videoElem == null) {
          return Text(TIM_t("[视频]"));
        }
        return TIMUIKitVideoElem(
            message,
            chatModel: widget.model,
            isFrom: "merger",
            isShowMessageReaction: false);
      case MessageElemType.V2TIM_ELEM_TYPE_LOCATION:
        return _tryItemBuilder(builders?.locationMessageItemBuilder, message) ??
            Text(TIM_t("[位置]"));
      case MessageElemType.V2TIM_ELEM_TYPE_MERGER:
        final custom =
            _tryItemBuilder(builders?.mergerMessageItemBuilder, message);
        if (custom != null) {
          return custom;
        }
        if (message.mergerElem == null) {
          return Text(TIM_t("[聊天记录]"));
        }
        return TIMUIKitMergerElem(
            model: widget.model,
            isShowJump: false,
            isShowMessageReaction: false,
            message: message,
            mergerElem: message.mergerElem!,
            isSelf: isFromSelf,
            messageID: message.msgID ?? "");
      default:
        return Text(TIM_t("未知消息"));
    }
  }

  double getMaxWidth(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final width = size.width;
    return width - 150;
  }

  Widget _itemBuilder(V2TimMessage message, BuildContext context) {
    final faceUrl = message.faceUrl ?? "";
    final showName = message.nickName ?? message.userID ?? "";
    final theme = Provider.of<TUIThemeViewModel>(context).theme;
    final isSelf = message.isSelf ?? false;
    return Container(
      margin: const EdgeInsets.only(top: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: isSelf ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isSelf)
            SizedBox(
              width: 40,
              height: 40,
              child: Avatar(faceUrl: faceUrl, showName: showName),
            ),
          if (!isSelf)
            const SizedBox(
              width: 12,
            ),
          Column(
            crossAxisAlignment: isSelf ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              Text(showName, style: TextStyle(fontSize: 12, color: theme.weakTextColor)),
              const SizedBox(
                height: 4,
              ),
              ConstrainedBox(
                constraints: BoxConstraints(maxWidth: getMaxWidth(context)),
                child: _getMsgItem(message),
              )
            ],
          ),
          if (isSelf)
            const SizedBox(
              width: 12,
            ),
          if (isSelf)
            SizedBox(
              width: 40,
              height: 40,
              child: Avatar(faceUrl: faceUrl, showName: showName),
            ),
        ],
      ),
    );
  }

  @override
  Widget tuiBuild(BuildContext context, TUIKitBuildValue value) {
    final TUITheme theme = value.theme;

    final isDesktopScreen = TUIKitScreenUtils.getFormFactor(context) == DeviceType.Desktop;

    Widget messageListPage() {
      if (_loadFailed) {
        return Center(
          child: Text(
            TIM_t("聊天记录加载失败"),
            style: TextStyle(color: theme.weakTextColor),
          ),
        );
      }
      if (messageList.isEmpty) {
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              LoadingAnimationWidget.staggeredDotsWave(
                color: theme.weakTextColor ?? Colors.grey,
                size: 48,
              ),
              const SizedBox(height: 20),
              Text(TIM_t("消息列表加载中")),
            ],
          ),
        );
      }
      return ListView.builder(
        controller: widget.scrollController,
        padding: const EdgeInsets.all(16),
        clipBehavior: Clip.hardEdge,
        itemCount: messageList.length,
        itemBuilder: (context, index) {
          final message = messageList[index];
          return _itemBuilder(message, context);
        },
      );
    }

    final pageBg = theme.chatBgColor ??
        theme.weakBackgroundColor ??
        theme.wideBackgroundColor ??
        Colors.white;

    return TUIKitScreenUtils.getDeviceWidget(
        context: context,
        desktopWidget: ColoredBox(
          color: pageBg,
          child: messageListPage(),
        ),
        defaultWidget: Scaffold(
          backgroundColor: pageBg,
          appBar: AppBar(
              title: Text(
                TIM_t("聊天记录"),
                style: TextStyle(color: theme.appbarTextColor, fontSize: 17),
              ),
              shadowColor: theme.weakDividerColor,
              backgroundColor:
                  theme.chatHeaderBgColor ?? theme.appbarBgColor ?? pageBg,
              iconTheme: IconThemeData(
                color: const Color(0xFF006EFF),
              )),
          body: messageListPage(),
        ));
  }
}
