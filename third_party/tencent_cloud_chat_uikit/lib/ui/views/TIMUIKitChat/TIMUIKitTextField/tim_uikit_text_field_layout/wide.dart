import 'dart:async';
import 'dart:io';
import 'dart:math';
// ignore: unnecessary_import
import 'dart:typed_data';

import 'package:extended_text_field/extended_text_field.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_svg/svg.dart';
import 'package:image_picker/image_picker.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:pasteboard/pasteboard.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:tencent_chat_i18n_tool/tencent_chat_i18n_tool.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_conversation.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_conversation.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_message.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_message.dart';
import 'package:tencent_cloud_chat_uikit/base_widgets/tim_ui_kit_base.dart';
import 'package:tencent_cloud_chat_uikit/base_widgets/tim_ui_kit_state.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/separate_models/tui_chat_separate_view_model.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/view_models/tui_chat_global_model.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/view_models/tui_setting_model.dart';
import 'package:tencent_cloud_chat_uikit/data_services/core/tim_uikit_wide_modal_operation_key.dart';
import 'package:tencent_cloud_chat_uikit/data_services/services_locatar.dart';
import 'package:tencent_cloud_chat_uikit/tencent_cloud_chat_uikit.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/chat_media_send_utils.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/logger.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/message.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/message_bubble_text_color.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/optimize_utils.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/platform.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/screen_shot.dart';
import 'package:tencent_cloud_chat_uikit/ui/views/TIMUIKitChat/TIMUIKitTextField/tim_uikit_forbidden_input_bar.dart';
import 'package:tencent_cloud_chat_uikit/ui/views/TIMUIKitChat/TIMUIKitTextField/special_text/DefaultSpecialTextSpanBuilder.dart';
import 'package:tencent_cloud_chat_uikit/ui/views/TIMUIKitChat/TIMUIKitTextField/special_text/emoji_text.dart';
import 'package:tencent_cloud_chat_uikit/ui/widgets/drag_widget.dart';
import 'package:tencent_cloud_chat_uikit/ui/widgets/tim_uikit_reply_quote_card.dart';
import 'package:tencent_cloud_chat_uikit/ui/widgets/wide_popup.dart';
import 'package:universal_html/html.dart' as html;
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/chat_gallery_pick_utils.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/gallery_send_perf_trace.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/image_edit/editable_asset_picker.dart';
import 'package:wechat_assets_picker/wechat_assets_picker.dart';
import 'package:tencent_cloud_chat_uikit/base_widgets/tim_callback.dart';
import 'package:tencent_cloud_chat_uikit/theme/color.dart';
import 'package:tencent_cloud_chat_uikit/theme/tui_theme.dart';

abstract final class _ChatUiTokens {
  static const Color surfaceLight = Colors.white;
  static const Color surfaceDark = Color(0xFF1B1D22);
  static const Color surfaceAltLight = Color(0xFFF1F3F5);
  static const Color surfaceAltDark = Color(0xFF23262D);
  static const Color textPrimaryLight = Color(0xFF111827);
  static const Color textPrimaryDark = Color(0xFFF4F4F4);
  static const Color textSecondaryLight = Color(0xFF7A828D);
  static const Color textSecondaryDark = Color(0xFF9A9CA3);
  static const Color borderLight = Color(0xFFE6E8EC);
  static const Color borderDark = Color(0xFF2A2D33);
  static const double rMd = 12;
}

class DesktopControlBarItem {
  final String item;
  final IconData? icon;
  final String? imgPath;
  final String? svgPath;
  final Color? color;
  final ValueChanged<Offset?> onClick;
  final String? showName;
  final double? size;

  DesktopControlBarItem(
      {required this.item,
      this.icon,
      this.color,
      this.imgPath,
      this.svgPath,
      required this.onClick,
      this.showName,
      this.size})
      : assert(icon != null ||
            TencentUtils.checkString(imgPath) != null ||
            TencentUtils.checkString(svgPath) != null);
}

class DesktopControlBarConfig {
  final bool showStickerPanel;
  final bool showScreenshotButton;
  final bool showSendFileButton;
  final bool showSendImageButton;
  final bool showSendVideoButton;
  final bool showMessageHistoryButton;

  DesktopControlBarConfig({
    this.showStickerPanel = true,
    this.showScreenshotButton = true,
    this.showSendFileButton = true,
    this.showSendImageButton = true,
    this.showSendVideoButton = true,
    this.showMessageHistoryButton = true,
  });
}

class TIMUIKitTextFieldLayoutWide extends StatefulWidget {
  /// sticker panel customization
  final CustomStickerPanel? customStickerPanel;
  final VoidCallback onEmojiSubmitted;
  final Function(int, String) onCustomEmojiFaceSubmitted;
  final Function(String, bool) handleSendEditStatus;
  final VoidCallback backSpaceText;
  final ValueChanged<String> addStickerToText;
  final TUITheme theme;
  final ValueChanged<String> handleAtText;

  /// Whether to use the default emoji
  final bool isUseDefaultEmoji;

  final bool isCompatibleWithTencentCloudChatPackageOldKeys;

  final TUIChatSeparateViewModel model;

  /// background color
  final Color? backgroundColor;

  /// control input field behavior
  final TIMUIKitInputTextFieldController? controller;

  /// config for more panel
  final MorePanelConfig? morePanelConfig;

  final String languageType;

  final TextEditingController textEditingController;

  /// conversation id
  final String conversationID;

  /// conversation type
  final ConvType conversationType;

  final FocusNode focusNode;

  /// show more panel
  final bool showMorePanel;

  /// hint text for textField widget
  final String? hintText;

  final int? currentCursor;

  final ValueChanged<int?> setCurrentCursor;

  final VoidCallback onCursorChange;

  /// show send audio icon
  final bool showSendAudio;

  final TIMUIKitChatConfig chatConfig;

  /// on text changed
  final void Function(String)? onChanged;

  final V2TimMessage? repliedMessage;

  /// show send emoji icon
  final bool showSendEmoji;

  final VoidCallback onSubmitted;

  final VoidCallback goDownBottom;

  final List<CustomEmojiFaceData> customEmojiStickerList;

  /// Conversation need search
  final V2TimConversation currentConversation;

  final List<CustomStickerPackage> stickerPackageList;

  final String? forbiddenText;

  const TIMUIKitTextFieldLayoutWide(
      {Key? key,
      this.customStickerPanel,
      required this.onEmojiSubmitted,
      required this.onCustomEmojiFaceSubmitted,
      required this.backSpaceText,
      required this.addStickerToText,
      required this.isUseDefaultEmoji,
      this.isCompatibleWithTencentCloudChatPackageOldKeys = false,
      required this.languageType,
      required this.textEditingController,
      this.morePanelConfig,
      required this.conversationID,
      required this.conversationType,
      required this.focusNode,
      this.currentCursor,
      required this.setCurrentCursor,
      required this.onCursorChange,
      required this.model,
      this.backgroundColor,
      this.onChanged,
      required this.handleSendEditStatus,
      required this.handleAtText,
      this.repliedMessage,
      required this.onSubmitted,
      required this.goDownBottom,
      required this.showSendAudio,
      required this.showSendEmoji,
      required this.showMorePanel,
      this.hintText,
      required this.customEmojiStickerList,
      this.controller,
      required this.currentConversation,
      required this.theme,
      required this.chatConfig,
      required this.stickerPackageList,
      this.forbiddenText})
      : super(key: key);

  @override
  State<TIMUIKitTextFieldLayoutWide> createState() =>
      _TIMUIKitTextFieldLayoutWideState();
}

class _TIMUIKitTextFieldLayoutWideState
    extends TIMUIKitState<TIMUIKitTextFieldLayoutWide> {
  final TUISettingModel settingModel = serviceLocator<TUISettingModel>();
  OverlayEntry? entry;
  final ImagePicker _picker = ImagePicker();
  Uint8List? fileContent;
  String? fileName;
  File? tempFile;
  Function? setKeyboardHeight;
  double? bottomPadding;
  late ScrollController _scrollController;
  late FocusNode textFocusNode;
  late List<DesktopControlBarItem> defaultControlBarItems;

  String _capturedConversationId(TUIChatSeparateViewModel model) {
    final modelId = model.conversationID.trim();
    return modelId.isNotEmpty ? modelId : widget.conversationID.trim();
  }

  ConvType _capturedConversationType(TUIChatSeparateViewModel model) {
    return model.conversationType ?? widget.conversationType;
  }

  @override
  void initState() {
    super.initState();
    if (widget.controller != null) {
      widget.controller?.addListener(() {
        final actionType = widget.controller?.actionType;
        if (actionType == ActionType.hideAllPanel) {
          hideAllPanel();
        }
      });
    }
    textFocusNode = FocusNode();
    widget.focusNode.requestFocus();
    _scrollController = ScrollController();
    try {
      if (PlatformUtils().isWeb) {
        html.window.addEventListener('paste', (event) {
          _handlePaste(event as html.ClipboardEvent);
        });
      }
    } catch (e) {
      // ignore: avoid_print
      outputLogger.i(e.toString());
    }
    generateDefaultControlBarItems();
  }

  Future<void> _handlePaste(html.ClipboardEvent event) async {
    try {
      if (event.clipboardData!.files!.isNotEmpty) {
        html.File imageFile = event.clipboardData!.files![0];
        sendFileUseJs(imageFile);
      }
    } catch (e) {
      // ignore: avoid_print
      outputLogger.i("Paste image failed: ${e.toString()}");
    }
  }

  hideAllPanel() {
    widget.focusNode.unfocus();
    widget.setCurrentCursor(null);
  }

  /// 选图期间允许会话切换或离开页面：始终按打开相册时捕获的目标发送。
  bool _isCapturedConversationCurrent(
    String convID,
    ConvType convType, {
    bool notify = true,
  }) =>
      true;

  _debounce(
    Function(String text) fun, [
    Duration delay = const Duration(milliseconds: 30),
  ]) {
    Timer? timer;
    return (String text) {
      if (timer != null) {
        timer?.cancel();
      }

      timer = Timer(delay, () {
        fun(text);
      });
    };
  }

  _buildRepliedMessage(V2TimMessage? repliedMessage, TUITheme theme) {
    if (repliedMessage == null) {
      return const SizedBox.shrink();
    }
    return TIMUIKitInputReplyPreview(
      repliedMessage: repliedMessage,
      chatModel: widget.model,
      theme: theme,
      backgroundColor: widget.backgroundColor,
      onClose: () => widget.model.repliedMessage = null,
    );
  }

  _sendEmoji(Offset? offset, TUITheme theme) {
    widget.onCursorChange();
    if (entry != null) {
      entry?.remove();
      entry = null;
    } else {
      entry = OverlayEntry(builder: (BuildContext context) {
        return TUIKitDragArea(
            closeFun: () {
              if (entry != null) {
                entry?.remove();
                entry = null;
              }
            },
            initOffset: offset != null
                ? Offset(offset.dx, max(offset.dy, 16))
                : Offset(MediaQuery.of(context).size.height * 0.5 + 20,
                    MediaQuery.of(context).size.height * 0.5 - 100),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.all(Radius.circular(8)),
                color: theme.wideBackgroundColor,
                border: Border.all(
                  width: 2,
                  color: theme.weakBackgroundColor ?? const Color(0xFFbebebe),
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0xFFbebebe),
                    offset: Offset(5, 5),
                    blurRadius: 10,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: Container(
                child: widget.customStickerPanel != null
                    ? widget.customStickerPanel!(
                        height: widget.chatConfig.desktopStickerPanelHeight,
                        width: 350,
                        sendTextMessage: () {
                          widget.onEmojiSubmitted();
                        },
                        sendFaceMessage: widget.onCustomEmojiFaceSubmitted,
                        deleteText: () {
                          widget.backSpaceText();
                        },
                        addText: (int unicode) {
                          final newText = String.fromCharCode(unicode);
                          widget.addStickerToText(newText);
                          entry?.remove();
                          entry = null;
                        },
                        addCustomEmojiText: ((String singleEmojiName) {
                          String? emojiName = singleEmojiName.split('.png')[0];
                          String compatibleEmojiName = emojiName;
                          if (widget
                              .isCompatibleWithTencentCloudChatPackageOldKeys) {
                            compatibleEmojiName =
                                EmojiUtil.getCompatibleEmojiName(emojiName);
                          }

                          String newText = '[$compatibleEmojiName]';
                          widget.addStickerToText(newText);
                          entry?.remove();
                          entry = null;
                        }),
                        defaultCustomEmojiStickerList: widget.isUseDefaultEmoji
                            ? TUIKitStickerConstData.emojiList
                            : [])
                    : Material(
                        color: Colors.transparent,
                        child: StickerPanel(
                            isWideScreen: true,
                            height: widget.chatConfig.desktopStickerPanelHeight,
                            width: 350,
                            sendTextMsg: null,
                            sendFaceMsg: (_, __) {
                              widget.onCustomEmojiFaceSubmitted(_, __);
                              entry?.remove();
                              entry = null;
                            },
                            deleteText: () {
                              widget.backSpaceText();
                            },
                            addText: (int unicode) {
                              final newText = String.fromCharCode(unicode);
                              widget.addStickerToText(newText);
                              entry?.remove();
                              entry = null;
                            },
                            addCustomEmojiText: ((String singleEmojiName) {
                              String? emojiName =
                                  singleEmojiName.split('.png')[0];
                              String compatibleEmojiName = emojiName;
                              if (widget
                                  .isCompatibleWithTencentCloudChatPackageOldKeys) {
                                compatibleEmojiName =
                                    EmojiUtil.getCompatibleEmojiName(emojiName);
                              }

                              String newText = '[$compatibleEmojiName]';
                              widget.addStickerToText(newText);
                              entry?.remove();
                              entry = null;
                            }),
                            customStickerPackageList: widget.stickerPackageList,
                            bottomColor: theme.weakBackgroundColor,
                            backgroundColor: theme.wideBackgroundColor,
                            lightPrimaryColor: theme.lightPrimaryColor),
                      ),
              ),
            ));
      });
      Overlay.of(context).insert(entry!);
    }
  }

  _addGreyOverlay() {
    if (entry != null) {
      _removeOverlay();
      return;
    } else {
      entry = OverlayEntry(builder: (BuildContext context) {
        return Container(
          color: const Color(0x7F000000),
        );
      });
      Overlay.of(context).insert(entry!);
    }
  }

  _removeOverlay() {
    entry?.remove();
    entry = null;
  }

  _sendFile(
    TUIChatSeparateViewModel model,
    TUITheme theme,
  ) async {
    if (!PlatformUtils().isWeb) {
      _addGreyOverlay();
    }
    try {
      final convID = _capturedConversationId(model);
      final convType = _capturedConversationType(model);
      if (PlatformUtils().isWeb) {
        final html.FileUploadInputElement uploadInput =
            html.FileUploadInputElement();
        uploadInput.accept = '*/*';
        uploadInput.click();
        _removeOverlay();
        uploadInput.onChange.listen((event) {
          final file = uploadInput.files?.first;
          if (file != null) {
            final fileName = file.name;
            if (!_isCapturedConversationCurrent(convID, convType)) {
              return;
            }
            MessageUtils.handleMessageError(
                model.sendFileMessage(
                    inputElement: uploadInput,
                    fileName: fileName,
                    convID: convID,
                    convType: convType),
                context);
          } else {
            throw TypeError();
          }
        });
      } else {
        FilePickerResult? result = await FilePicker.platform.pickFiles();
        _removeOverlay();
        if (result != null && result.files.isNotEmpty) {
          File file = File(result.files.single.path!);
          final int size = await file.length();
          if (!_isCapturedConversationCurrent(convID, convType)) {
            return;
          }
          final String savePath = file.path;

          MessageUtils.handleMessageError(
              model.sendFileMessage(
                  filePath: savePath,
                  size: size,
                  convID: convID,
                  convType: convType),
              context);
        } else {
          throw TypeError();
        }
      }
    } catch (e) {
      // ignore: avoid_print
      outputLogger.i("_sendFileErr: ${e.toString()}");
    }
  }

  List<Widget> generateBarIcons(
      List<DesktopControlBarItem> items, TUITheme theme) {
    final defaultItems = defaultControlBarItems.map((e) => e.item);
    final isDark = ThemeData.estimateBrightnessForColor(
          theme.wideBackgroundColor ?? _ChatUiTokens.surfaceLight,
        ) ==
        Brightness.dark;
    // 暗色下 SVG/PNG 资产默认近黑，必须上色；用次级文字色保证够亮又不抢输入区。
    final defaultBarIconColor = isDark
        ? (theme.weakTextColor ?? _ChatUiTokens.textSecondaryDark)
        : (theme.weakTextColor ?? hexToColor("646a73"));
    return items.map((e) {
      final GlobalKey key = GlobalKey();
      final barIconColor = e.color ?? defaultBarIconColor;
      return Container(
        margin: const EdgeInsets.only(right: 10),
        child: InkWell(
          onTap: () {
            final alignBox =
                key.currentContext?.findRenderObject() as RenderBox?;
            var offset = alignBox?.localToGlobal(Offset.zero);
            final double? dx = (offset?.dx != null) ? offset!.dx : null;
            final double? dy =
                (offset?.dy != null && alignBox?.size.height != null)
                    ? offset!.dy -
                        (widget.chatConfig.desktopStickerPanelHeight + 20)
                    : null;
            e.onClick((dx != null && dy != null) ? Offset(dx, dy) : null);
          },
          child: Tooltip(
            preferBelow: false,
            textStyle: TextStyle(fontSize: 12, color: theme.white),
            message: e.showName ?? '',
            child: Container(
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(2)),
              padding: const EdgeInsets.all(4),
              child: () {
                if (TencentUtils.checkString(e.svgPath) != null) {
                  return SvgPicture.asset(
                    e.svgPath!,
                    package: defaultItems.contains(e.item)
                        ? 'tencent_cloud_chat_uikit'
                        : null,
                    key: key,
                    width: e.size ?? 16,
                    height: e.size ?? 16,
                    colorFilter:
                        ColorFilter.mode(barIconColor, BlendMode.srcIn),
                  );
                }
                if (TencentUtils.checkString(e.imgPath) != null) {
                  return Image.asset(
                    e.imgPath!,
                    package: defaultItems.contains(e.item)
                        ? 'tencent_cloud_chat_uikit'
                        : null,
                    key: key,
                    width: e.size ?? 16,
                    height: e.size ?? 16,
                    color: barIconColor,
                    colorBlendMode: BlendMode.srcIn,
                  );
                }
                return Icon(
                  e.icon,
                  key: key,
                  color: barIconColor,
                  size: e.size ?? 20,
                );
              }(),
            ),
          ),
        ),
      );
    }).toList();
  }

  _sendImageFileOnWeb(TUIChatSeparateViewModel model) async {
    try {
      final convID = _capturedConversationId(model);
      final convType = _capturedConversationType(model);
      if (!_isCapturedConversationCurrent(convID, convType)) {
        return;
      }
      final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
      if (pickedFile == null ||
          !_isCapturedConversationCurrent(convID, convType)) {
        return;
      }
      final imageContent = await pickedFile!.readAsBytes();
      fileName = pickedFile.name;
      tempFile = File(pickedFile.path);
      fileContent = imageContent;

      html.Node? inputElem;
      inputElem = html.document
          .getElementById("__image_picker_web-file-input")
          ?.querySelector("input");
      if (!_isCapturedConversationCurrent(convID, convType)) {
        return;
      }
      MessageUtils.handleMessageError(
          model.sendImageMessage(
              inputElement: inputElem,
              imagePath: tempFile?.path,
              convID: convID,
              convType: convType),
          context);
    } catch (e) {
      // ignore: avoid_print
      outputLogger.i("_sendFileErr: ${e.toString()}");
    }
  }

  _sendVideoFileOnWeb(TUIChatSeparateViewModel model) async {
    try {
      final convID = _capturedConversationId(model);
      final convType = _capturedConversationType(model);
      if (!_isCapturedConversationCurrent(convID, convType)) {
        return;
      }
      final pickedFile = await _picker.pickVideo(source: ImageSource.gallery);
      if (pickedFile == null ||
          !_isCapturedConversationCurrent(convID, convType)) {
        return;
      }
      final videoContent = await pickedFile!.readAsBytes();
      fileName = pickedFile.name;
      tempFile = File(pickedFile.path);
      fileContent = videoContent;

      if (fileName!.split(".")[fileName!.split(".").length - 1] != "mp4") {
        onTIMCallback(TIMCallback(
            type: TIMCallbackType.INFO,
            infoRecommendText: TIM_t("视频消息仅限 mp4 格式"),
            infoCode: 6660412));
        return;
      }

      html.Node? inputElem;
      inputElem = html.document
          .getElementById("__image_picker_web-file-input")
          ?.querySelector("input");
      if (!_isCapturedConversationCurrent(convID, convType)) {
        return;
      }
      MessageUtils.handleMessageError(
          model.sendVideoMessage(
              inputElement: inputElem,
              videoPath: tempFile?.path,
              convID: convID,
              convType: convType),
          context);
    } catch (e) {
      // ignore: avoid_print
      outputLogger.i("_sendFileErr: ${e.toString()}");
    }
  }

  _sendVideoMessage(
    AssetEntity asset,
    TUIChatSeparateViewModel model, {
    required String convID,
    required ConvType convType,
  }) async {
    try {
      final originFile = await asset.originFile;
      final size = await originFile!.length();
      if (size >= 104857600) {
        onTIMCallback(TIMCallback(
            type: TIMCallbackType.INFO,
            infoRecommendText: TIM_t("发送失败，视频不能大于100MB"),
            infoCode: 6660405));
        return;
      }
      final filePath = originFile.path;
      final snapshotPath = await buildVideoSnapshotForSend(
        videoPath: filePath,
        devicePixelRatio: MediaQuery.devicePixelRatioOf(context),
      );
      if (!_isCapturedConversationCurrent(convID, convType)) {
        return;
      }
      MessageUtils.handleMessageError(
        model.sendVideoMessage(
          videoPath: filePath,
          duration: asset.videoDuration.inSeconds,
          snapshotPath: snapshotPath,
          convID: convID,
          convType: convType,
        ),
        context,
      );
    } catch (_) {
      onTIMCallback(TIMCallback(
          type: TIMCallbackType.INFO,
          infoRecommendText: TIM_t("视频文件异常"),
          infoCode: 6660415));
    }
  }

  _sendMediaMessage(
      TUIChatSeparateViewModel model, TUITheme theme, FileType fileType) async {
    final perf = GallerySendPerfTrace(
      mode: PlatformUtils().isMobile ? 'wide_mobile_album' : 'wide_desktop',
    )..log('tap_send_media', detail: fileType.name);
    try {
      final convID = model.conversationID.trim().isNotEmpty
          ? model.conversationID
          : widget.conversationID;
      final convType = model.conversationType ?? widget.conversationType;

      if (PlatformUtils().isMobile) {
        perf.log('custom_picker_open');
        final pickedAssets = await EditableAssetPicker.pickAssets(
          context,
          perf: perf,
        );
        perf.log(
          'custom_picker_returned',
          count: pickedAssets?.length ?? 0,
          detail: pickedAssets == null ? 'cancelled' : 'selected',
        );
        if (pickedAssets == null || pickedAssets.isEmpty) {
          return;
        }
        if (!_isCapturedConversationCurrent(convID, convType)) {
          perf.log('dispatch_cancelled_conversation_changed');
          return;
        }
        perf.log('dismiss_settle_begin', count: pickedAssets.length);
        await ChatGalleryPickUtils.waitForPickerDismissSettle();
        perf.log('dismiss_settle_end');
        for (var i = 0; i < pickedAssets.length; i++) {
          final asset = pickedAssets[i];
          final originFile = asset.type == AssetType.image
              ? await EditableAssetPicker.resolveFileForChatSend(
                  asset,
                  perf: perf,
                  index: i,
                )
              : await asset.originFile;
          final filePath = originFile?.path;
          if (filePath == null || filePath.isEmpty) {
            perf.log('asset_resolve_missing', index: i);
            continue;
          }
          if (!_isCapturedConversationCurrent(convID, convType)) {
            perf.log('dispatch_cancelled_conversation_changed', index: i);
            return;
          }
          perf.log(
            'asset_dispatch_begin',
            index: i,
            count: pickedAssets.length,
            detail: asset.type.name,
          );
          if (asset.type == AssetType.image) {
            perf.log('image_send_begin', index: i);
            MessageUtils.handleMessageError(
              model.sendImageMessage(
                imagePath: filePath,
                convID: convID,
                convType: convType,
              ),
              context,
            );
            perf.log('image_send_queued', index: i);
          } else if (asset.type == AssetType.video) {
            perf.log('video_send_begin', index: i);
            await _sendVideoMessage(
              asset,
              model,
              convID: convID,
              convType: convType,
            );
            perf.log('video_send_queued', index: i);
          }
        }
        perf.log('wide_mobile_dispatch_complete', count: pickedAssets.length);
      } else {
        perf.log('desktop_file_picker_open');
        _addGreyOverlay();
        FilePickerResult? result =
            await FilePicker.platform.pickFiles(type: fileType);
        _removeOverlay();
        perf.log(
          'desktop_file_picker_returned',
          detail:
              result == null || result.files.isEmpty ? 'cancelled' : 'selected',
        );
        if (result != null && result.files.isNotEmpty) {
          if (!_isCapturedConversationCurrent(convID, convType)) {
            return;
          }
          File file = File(result.files.single.path!);
          final String savePath = file.path;
          final String type = TencentUtils.getFileType(
                  (savePath.split(".")[savePath.split(".").length - 1])
                      .toLowerCase())
              .split("/")[0];

          if (type == "image") {
            perf.log('desktop_image_send_begin');
            MessageUtils.handleMessageError(
                model.sendImageMessage(
                    imagePath: savePath, convID: convID, convType: convType),
                context);
            perf.log('desktop_image_send_queued');
          } else if (type == "video") {
            perf.log('desktop_video_snapshot_begin');
            final snapshotPath = await buildVideoSnapshotForSend(
              videoPath: savePath,
              devicePixelRatio: MediaQuery.devicePixelRatioOf(context),
            );
            perf.log('desktop_video_send_begin');
            MessageUtils.handleMessageError(
                model.sendVideoMessage(
                    videoPath: savePath,
                    convID: convID,
                    convType: convType,
                    snapshotPath: snapshotPath),
                context);
            perf.log('desktop_video_send_queued');
          }
        } else {
          throw TypeError();
        }
      }
    } catch (err) {
      // ignore: avoid_print
      outputLogger.i("send media err: $err");
      perf.log('media_task_failed', detail: 'type=${err.runtimeType}');
      onTIMCallback(TIMCallback(
          type: TIMCallbackType.INFO,
          infoRecommendText: TIM_t("视频文件异常"),
          infoCode: 6660415));
    }
    perf.markTaskReturned();
  }

  _sendImageWithConfirmation(
      {String? fileName, Size? fileSize, required String filePath}) async {
    final option1 = widget.currentConversation.showName ??
        (widget.conversationType == ConvType.group ? TIM_t("群聊") : TIM_t("对方"));
    final size = fileSize ?? await ScreenshotHelper.getImageSize(filePath);

    TUIKitWidePopup.showPopupWindow(
      operationKey: TUIKitWideModalOperationKey.beforeSendScreenShot,
      context: context,
      isDarkBackground: false,
      width: 500,
      height: min(500, size.height / 2 + 140),
      title: TIM_t_para("发送给{{option1}}", "发送给$option1")(option1: option1),
      child: (closeFunc) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            SizedBox(
              height: min(360, size.height / 2),
              child: InkWell(
                onTap: () {
                  launchUrl(PlatformUtils().isWeb
                      ? Uri.parse(filePath)
                      : Uri.file(filePath));
                },
                child: PlatformUtils().isWeb
                    ? Image.network(
                        filePath,
                        height: min(360, size.height / 2),
                      )
                    : Image.file(
                        File(filePath),
                        height: min(360, size.height / 2),
                      ),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              mainAxisSize: MainAxisSize.max,
              children: [
                OutlinedButton(
                    onPressed: () {
                      closeFunc();
                    },
                    child: Text(TIM_t("取消"))),
                const SizedBox(
                  width: 20,
                ),
                ElevatedButton(
                    onPressed: () {
                      MessageUtils.handleMessageError(
                          widget.model.sendImageMessage(
                              imagePath: filePath,
                              imageName: fileName,
                              convID: widget.conversationID,
                              convType: widget.conversationType),
                          context);
                      closeFunc();
                    },
                    child: Text(TIM_t("\u53d1\u9001")))
              ],
            )
          ],
        ),
      ),
    );
  }

  _sendScreenShot() async {
    final file = await ScreenshotHelper.captureScreen();
    if (file != null) {
      _sendImageWithConfirmation(filePath: file);
    } else {}
  }

  generateDefaultControlBarItems() {
    final DesktopControlBarConfig config =
        widget.chatConfig.desktopControlBarConfig ?? DesktopControlBarConfig();
    final List<DesktopControlBarItem> itemsList = [
      if (config.showStickerPanel)
        DesktopControlBarItem(
            item: "face",
            showName: TIM_t("表情"),
            onClick: (offset) {
              _sendEmoji(offset, widget.theme);
            },
            svgPath: "images/svg/send_face.svg"),
      if (config.showScreenshotButton && PlatformUtils().isDesktop)
        DesktopControlBarItem(
            item: "screenShot",
            showName: TIM_t("截图"),
            onClick: (offset) {
              _sendScreenShot();
            },
            svgPath: "images/svg/send_screenshot.svg"),
      if (config.showSendFileButton)
        DesktopControlBarItem(
            item: "file",
            showName: TIM_t("文件"),
            onClick: (offset) {
              _sendFile(widget.model, widget.theme);
            },
            svgPath: "images/svg/send_file.svg"),
      if (config.showSendImageButton)
        DesktopControlBarItem(
            item: "photo",
            showName: TIM_t("图片"),
            onClick: (offset) {
              if (PlatformUtils().isWeb) {
                _sendImageFileOnWeb(widget.model);
              } else {
                _sendMediaMessage(widget.model, widget.theme, FileType.image);
              }
            },
            svgPath: "images/svg/send_image.svg"),
      if (config.showSendVideoButton)
        DesktopControlBarItem(
            item: "video",
            showName: TIM_t("视频"),
            onClick: (offset) {
              if (PlatformUtils().isWeb) {
                _sendVideoFileOnWeb(widget.model);
              } else {
                _sendMediaMessage(widget.model, widget.theme, FileType.video);
              }
            },
            svgPath: "images/svg/send_video.svg"),
      if (config.showMessageHistoryButton)
        DesktopControlBarItem(
            item: "history",
            showName: TIM_t("消息历史"),
            onClick: (offset) {
              TUIKitWidePopup.showPopupWindow(
                  operationKey: TUIKitWideModalOperationKey.chatHistory,
                  context: context,
                  width: MediaQuery.of(context).size.width * 0.5,
                  height: MediaQuery.of(context).size.width * 0.5,
                  child: (onClose) => TIMUIKitSearchMsgDetail(
                        currentConversation: widget.currentConversation,
                        keyword: '',
                        initMessageList: widget.model
                            .getOriginMessageList()
                            .getRange(
                                0,
                                min(widget.model.getOriginMessageList().length,
                                    100))
                            .toList(),
                        onTapConversation: (V2TimConversation conversation,
                            V2TimMessage? message) {},
                      ),
                  theme: widget.theme);
            },
            svgPath: "images/svg/message_history.svg"),
    ];
    defaultControlBarItems = itemsList;
  }

  List<Widget> generateControlBar(
      TUIChatSeparateViewModel model, TUITheme theme) {
    final List<DesktopControlBarItem> itemsList = [
      ...defaultControlBarItems,
      ...(widget.chatConfig.additionalDesktopControlBarItems ?? [])
    ];

    return generateBarIcons(itemsList, theme);
  }

  sendFileUseJs(html.File file) {
    final mimeType = file.type.split('/');
    final type = mimeType[0];
    final blobUrl = html.Url.createObjectUrl(file);
    if (type == 'image') {
      _sendImageWithConfirmation(
          filePath: blobUrl,
          fileName: file.name,
          fileSize: const Size(500, 500));
    }
  }

  Future<void> _handleKeyEvent(RawKeyEvent event) async {
    if (PlatformUtils().isDesktop &&
        ((event.isKeyPressed(LogicalKeyboardKey.controlLeft) &&
                event.logicalKey == LogicalKeyboardKey.keyV) ||
            (event.isMetaPressed &&
                event.logicalKey == LogicalKeyboardKey.keyV))) {
      final bytes = await Pasteboard.image;
      if (bytes != null) {
        String directory;
        if (PlatformUtils().isWindows) {
          final String documentsDirectoryPath =
              "${Platform.environment['USERPROFILE']}";
          PackageInfo packageInfo = await PackageInfo.fromPlatform();
          String pkgName = packageInfo.packageName;
          directory = p.join(documentsDirectoryPath, "Documents",
              ".TencentCloudChat", pkgName, "screenshots");
        } else {
          final dic = await getApplicationSupportDirectory();
          directory = dic.path;
        }
        const uuid = Uuid();
        final fileName = 'paste_image_${uuid.v4()}.png';
        final scDirectory = Directory(directory);
        final filePath =
            '${scDirectory.path}${PlatformUtils().isWindows ? "\\" : "/"}$fileName';
        final file = File(filePath);
        if (!await scDirectory.exists()) {
          await scDirectory.create(recursive: true);
        }
        await file.writeAsBytes(bytes.toList());
        _sendImageWithConfirmation(filePath: filePath);
      }
    }
  }

  @override
  Widget tuiBuild(BuildContext context, TUIKitBuildValue value) {
    final theme = value.theme;

    setKeyboardHeight ??= OptimizeUtils.debounce((height) {
      settingModel.keyboardHeight = height;
    }, const Duration(seconds: 1));

    final debounceFunc = _debounce((value) {
      if (widget.onChanged != null) {
        widget.onChanged!(value);
      }
      widget.handleAtText(value);
      widget.handleSendEditStatus(value, true);
    }, const Duration(milliseconds: 80));

    final MediaQueryData data = MediaQuery.of(context);
    EdgeInsets padding = data.padding;
    if (bottomPadding == null || padding.bottom > bottomPadding!) {
      bottomPadding = padding.bottom;
    }

    final forbidden = widget.forbiddenText;
    final isInputForbidden = forbidden != null && forbidden.isNotEmpty;
    final isDark = ThemeData.estimateBrightnessForColor(
          theme.wideBackgroundColor ?? _ChatUiTokens.surfaceLight,
        ) ==
        Brightness.dark;
    final inputBg = widget.backgroundColor ??
        theme.desktopChatMessageInputBgColor ??
        (isDark ? _ChatUiTokens.surfaceDark : _ChatUiTokens.surfaceLight);
    final dividerColor = theme.weakDividerColor ??
        (isDark ? _ChatUiTokens.borderDark : _ChatUiTokens.borderLight);
    final fieldFill = widget.backgroundColor ??
        theme.inputFillColor ??
        (isDark ? _ChatUiTokens.surfaceAltDark : _ChatUiTokens.surfaceAltLight);
    final inputTextColor = theme.darkTextColor ??
        (isDark
            ? _ChatUiTokens.textPrimaryDark
            : _ChatUiTokens.textPrimaryLight);
    final inputHintColor = theme.weakTextColor ??
        (isDark
            ? _ChatUiTokens.textSecondaryDark
            : _ChatUiTokens.textSecondaryLight);

    return RawKeyboardListener(
        focusNode: textFocusNode,
        onKey: _handleKeyEvent,
        child: Container(
          color: inputBg,
          child: Column(
            children: [
              _buildRepliedMessage(widget.repliedMessage, theme),
              if (isInputForbidden)
                TIMUIKitForbiddenInputBar(
                  text: forbidden,
                  theme: theme,
                  backgroundColor: inputBg,
                )
              else ...[
                SizedBox(
                  height: 0.5,
                  child: Container(color: dividerColor),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: generateControlBar(widget.model, theme),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(vertical: 6, horizontal: 6),
                  constraints: const BoxConstraints(minHeight: 50),
                  child: Row(
                    children: [
                      Expanded(
                        child: DefaultTextStyle(
                          style: MessageBubbleTextColor.messageInputTextStyle(
                            fontSize: 14,
                            color: inputTextColor,
                            lineHeight: widget.model.chatConfig.textHeight,
                          ),
                          child: ExtendedTextField(
                              scrollController: _scrollController,
                              autofocus: true,
                              maxLines: widget
                                  .chatConfig.desktopMessageInputFieldLines,
                              minLines: widget
                                  .chatConfig.desktopMessageInputFieldLines,
                              focusNode: widget.focusNode,
                              onChanged: debounceFunc,
                              keyboardType: TextInputType.multiline,
                              onEditingComplete: () {
                                //   // widget.onSubmitted();
                              },
                              textAlignVertical: TextAlignVertical.top,
                              style:
                                  MessageBubbleTextColor.messageInputTextStyle(
                                fontSize: 14,
                                color: inputTextColor,
                                lineHeight: widget.model.chatConfig.textHeight,
                              ),
                              decoration: InputDecoration(
                                hoverColor: Colors.transparent,
                                border: InputBorder.none,
                                hintStyle: MessageBubbleTextColor
                                    .messageInputHintStyle(
                                  fontSize: 14,
                                  color: inputHintColor,
                                  lineHeight:
                                      widget.model.chatConfig.textHeight,
                                ),
                                fillColor: fieldFill,
                                filled: true,
                                isDense: true,
                                hintText: widget.hintText ?? '',
                              ),
                              controller: widget.textEditingController,
                              specialTextSpanBuilder: PlatformUtils().isWeb
                                  ? null
                                  : DefaultSpecialTextSpanBuilder(
                                      isUseTencentCloudChatPackage: widget
                                              .model
                                              .chatConfig
                                              .stickerPanelConfig
                                              ?.useTencentCloudChatStickerPackage ??
                                          true,
                                      customEmojiStickerList:
                                          widget.customEmojiStickerList,
                                      showAtBackground: true,
                                    )),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ValueListenableBuilder<TextEditingValue>(
                        valueListenable: widget.textEditingController,
                        builder: (context, value, child) {
                          final canSend = value.text.trim().isNotEmpty;
                          final primaryColor =
                              theme.primaryColor ?? CommonColor.primaryColor;
                          return TextButton(
                            onPressed: canSend ? widget.onSubmitted : null,
                            style: TextButton.styleFrom(
                              minimumSize: const Size(64, 36),
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 14),
                              backgroundColor:
                                  canSend ? primaryColor : dividerColor,
                              foregroundColor:
                                  canSend ? Colors.white : inputHintColor,
                              disabledBackgroundColor: dividerColor,
                              disabledForegroundColor: inputHintColor,
                              shape: RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.circular(_ChatUiTokens.rMd),
                              ),
                            ),
                            child: Text(TIM_t("\u53d1\u9001")),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ));
  }
}
