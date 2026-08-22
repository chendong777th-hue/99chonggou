// ignore_for_file: prefer_typing_uninitialized_variables,  unused_import

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:collection/collection.dart';
import 'package:crypto/crypto.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:open_file/open_file.dart';
import 'package:provider/provider.dart';
import 'package:tencent_chat_i18n_tool/tencent_chat_i18n_tool.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_image.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_image.dart';
import 'package:tencent_cloud_chat_sdk/enum/message_elem_type.dart';
import 'package:tencent_cloud_chat_sdk/enum/message_status.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_message.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_message.dart';
import 'package:tencent_cloud_chat_uikit/base_widgets/tim_callback.dart';
import 'package:tencent_cloud_chat_uikit/base_widgets/tim_ui_kit_base.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/gallery_save_to_photos.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/media_preview_debug.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/media_preview_presenter.dart';
import 'package:tencent_cloud_chat_uikit/base_widgets/tim_ui_kit_state.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/separate_models/tui_chat_separate_view_model.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/view_models/chat_ui_state_store.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/view_models/tui_chat_global_model.dart';
import 'package:tencent_cloud_chat_uikit/data_services/message/message_services.dart';
import 'package:tencent_cloud_chat_uikit/data_services/services_locatar.dart';
import 'package:tencent_cloud_chat_uikit/tencent_cloud_chat_uikit.dart';
import 'package:tencent_cloud_chat_uikit/theme/tui_theme.dart';
import 'package:tencent_cloud_chat_uikit/ui/constants/history_message_constant.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/logger.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/message.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/permission.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/platform.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/ticker_settled_task.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/screen_utils.dart';
import 'package:tencent_cloud_chat_uikit/ui/widgets/message_bubble_watermark.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/time_ago.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_message_receipt.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_message_receipt.dart';
import 'package:tencent_cloud_chat_uikit/ui/views/TIMUIKitChat/TIMUIKitMessageItem/tim_uikit_media_upload_overlay.dart';
import 'package:tencent_cloud_chat_uikit/ui/views/TIMUIKitChat/TIMUIKitMessageItem/TIMUIKitMessageReaction/tim_uikit_message_reaction_wrapper.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/chat_bubble_local_image.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/chat_media_send_utils.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/history_pagination_anchor.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/image_edit/image_preview_editor.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/chat_media_gallery_utils.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/chat_media_gallery_session.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/chat_media_preview_builder.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/chat_image_original_prefetch.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/chat_jitter_diag.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/chat_img_trace.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/chat_message_preview_image_resolver.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/media_preview_header_utils.dart';
import 'package:tencent_cloud_chat_uikit/ui/views/TIMUIKitSearch/conversation_media_navigation.dart';
import 'package:tencent_cloud_chat_uikit/ui/widgets/forward_message_screen.dart';
import 'package:tencent_cloud_chat_uikit/ui/widgets/chat_media_preview_item.dart';
import 'package:tencent_cloud_chat_uikit/ui/widgets/chat_media_gallery_screen.dart';
import 'package:tencent_cloud_chat_uikit/ui/widgets/image_gallery_item.dart';
import 'package:tencent_cloud_chat_uikit/ui/widgets/image_screen.dart';
import 'package:tencent_cloud_chat_uikit/ui/widgets/chat_image_load_placeholder.dart';
import 'package:tencent_cloud_chat_uikit/ui/widgets/chat_web_image_lightbox.dart';
import 'package:tencent_cloud_chat_uikit/ui/widgets/wide_popup.dart';
import 'package:universal_html/html.dart' as html;
import 'package:url_launcher/url_launcher.dart';
import 'package:visibility_detector/visibility_detector.dart';

class TIMUIKitImageElem extends StatefulWidget {
  final V2TimMessage message;
  final bool isShowJump;
  final VoidCallback? clearJump;
  final String? isFrom;
  final bool? isShowMessageReaction;
  final TUIChatSeparateViewModel chatModel;

  const TIMUIKitImageElem(
      {required this.message,
      this.isShowJump = false,
      required this.chatModel,
      this.clearJump,
      this.isFrom,
      Key? key,
      this.isShowMessageReaction})
      : super(key: key);

  @override
  State<StatefulWidget> createState() => _TIMUIKitImageElem();
}

class _TIMUIKitImageElem extends TIMUIKitState<TIMUIKitImageElem>
    with TickerSettledTaskMixin<TIMUIKitImageElem> {
  static const BorderRadius _imageBorderRadius =
      BorderRadius.all(Radius.circular(10));
  static const double _placeholderBubbleWidth = 148;
  static const double _placeholderBubbleHeight = 110;

  final TUIChatGlobalModel globalModel = serviceLocator<TUIChatGlobalModel>();
  final TUIChatGlobalModel model = serviceLocator<TUIChatGlobalModel>();
  final MessageService _messageService = serviceLocator<MessageService>();
  Widget? imageItem;
  Size? _localLayoutSize;
  String? _localLayoutPath;
  int _localLayoutProbeToken = 0;
  String? _trackedFileLocation;
  int _trackedDownloadProgress = -1;
  String? _archiveCachePath;
  final Set<String> _readyImageFrameKeys = <String>{};

  String _decodeProbePathKey(String pathOrUrl) {
    final value = pathOrUrl.trim();
    if (value.isEmpty) {
      return 'empty';
    }
    final slash = value.replaceAll('\\', '/');
    final parts = slash.split('/');
    if (parts.length >= 2) {
      return '${parts[parts.length - 2]}/${parts.last}';
    }
    return parts.last.length > 48
        ? parts.last.substring(parts.last.length - 48)
        : parts.last;
  }

  String _sdkTypeLabelForLocalPath(
    String path, {
    V2TimImage? originalImg,
    V2TimImage? smallImg,
  }) {
    final normalized = path.trim();
    if (normalized.isEmpty) {
      return 'unknown';
    }
    final selfPath = _resolveSelfSendLocalImagePath()?.trim() ?? '';
    if (selfPath.isNotEmpty && selfPath == normalized) {
      return 'self_path';
    }
    final smallLocal = smallImg?.localUrl?.trim() ?? '';
    if (smallLocal.isNotEmpty && smallLocal == normalized) {
      return 'type_${smallImg?.type ?? 1}';
    }
    final originLocal = originalImg?.localUrl?.trim() ?? '';
    if (originLocal.isNotEmpty && originLocal == normalized) {
      return 'type_${originalImg?.type ?? 0}';
    }
    return 'local';
  }

  String _sdkTypeLabelForNetworkUrl(
    String url, {
    V2TimImage? originalImg,
    V2TimImage? smallImg,
  }) {
    final normalized = url.trim();
    if (normalized.isEmpty) {
      return 'unknown';
    }
    final big = getImageFromList(V2TimImageTypesEnum.big);
    if ((big?.url?.trim() ?? '') == normalized) {
      return 'type_${big?.type ?? 2}';
    }
    if ((smallImg?.url?.trim() ?? '') == normalized) {
      return 'type_${smallImg?.type ?? 1}';
    }
    if ((originalImg?.url?.trim() ?? '') == normalized) {
      return 'type_${originalImg?.type ?? 0}';
    }
    return 'network';
  }

  int? _metaPixelSide(V2TimImage? img, {required bool width}) {
    final value = width ? img?.width : img?.height;
    if (value == null || value <= 0) {
      return null;
    }
    return value;
  }

  void _probeBubbleDecodeProvider({
    required ImageProvider provider,
    required String source,
    required String pathOrUrl,
    required String sdkType,
    required Size displaySize,
    required int cacheW,
    required int cacheH,
    required bool deferHeavyDecode,
    required double dpr,
    V2TimImage? metaImg,
  }) {
    if (!ChatJitterDiag.enabled || !ChatJitterDiag.decodeProbeEnabled) {
      return;
    }
    final msgId =
        widget.message.msgID?.trim() ?? widget.message.id?.trim() ?? '';
    final pathKey = _decodeProbePathKey(pathOrUrl);
    try {
      final stream = provider.resolve(const ImageConfiguration());
      late ImageStreamListener listener;
      listener = ImageStreamListener(
        (ImageInfo info, bool synchronousCall) {
          stream.removeListener(listener);
          ChatJitterDiag.logBubbleDecode(
            msgId: msgId,
            source: source,
            pathOrUrlKey: pathKey,
            displayW: displaySize.width,
            displayH: displaySize.height,
            cacheW: cacheW,
            cacheH: cacheH,
            decodedW: info.image.width,
            decodedH: info.image.height,
            sync: synchronousCall,
            deferHeavy: deferHeavyDecode,
            dpr: dpr,
            sdkType: sdkType,
            // SDK 元数据像素（非磁盘全量 decode，避免探针污染 ImageCache）。
            fileW: _metaPixelSide(metaImg, width: true),
            fileH: _metaPixelSide(metaImg, width: false),
          );
        },
        onError: (Object _, StackTrace? __) {
          stream.removeListener(listener);
        },
      );
      stream.addListener(listener);
    } catch (_) {}
  }

  bool _isNetworkFrameReady({
    V2TimImage? originalImg,
    V2TimImage? smallImg,
  }) {
    if (_hasBubbleFrameReady()) {
      return true;
    }
    final networkUrl = _resolveBubbleNetworkImageUrl(
      originalImg: originalImg,
      smallImg: smallImg,
    );
    if (networkUrl == null || networkUrl.isEmpty) {
      return false;
    }
    return _readyImageFrameKeys.contains('net:$networkUrl');
  }

  String get _bubbleReadyToken => chatBubbleImageReadyToken(
        msgID: widget.message.msgID,
        idFallback: widget.message.id?.toString(),
      );

  bool _hasBubbleFrameReady() =>
      _readyImageFrameKeys.contains(_bubbleReadyToken);

  void _markBubbleFrameReady(String frameKey) {
    _readyImageFrameKeys.add(frameKey);
    _readyImageFrameKeys.add(_bubbleReadyToken);
  }

  String _bubbleImageWidgetKey(String kind, {String? urlOrPathFallback}) {
    return chatBubbleImageWidgetKey(
      kind: kind,
      msgID: widget.message.msgID,
      idFallback: widget.message.id?.toString(),
      urlOrPathFallback: urlOrPathFallback,
    );
  }

  bool _shouldSkipReceiveFileLocationRebuild() {
    if (widget.message.isSelf == true) {
      return false;
    }
    final originalImg = getImageFromList(V2TimImageTypesEnum.original);
    final smallImg = getImageFromList(V2TimImageTypesEnum.small);
    return _isNetworkFrameReady(
      originalImg: originalImg,
      smallImg: smallImg,
    );
  }

  int _lastHandledRowRevision = -1;

  void _onRowRevisionUpdate(int rowRevision) {
    if (rowRevision == _lastHandledRowRevision) {
      return;
    }
    _lastHandledRowRevision = rowRevision;
    if (!mounted) {
      return;
    }
    var shouldRebuild = false;

    final msgID = TencentUtils.checkString(widget.message.msgID);
    if (msgID != null) {
      final location = globalModel.getFileMessageLocation(msgID);
      if (location.isNotEmpty && location != _trackedFileLocation) {
        _trackedFileLocation = location;
        if (!_shouldSkipReceiveFileLocationRebuild()) {
          shouldRebuild = true;
        }
      }
      final downloadProgress = globalModel.getMessageProgress(msgID);
      if (downloadProgress != _trackedDownloadProgress) {
        _trackedDownloadProgress = downloadProgress;
        // 网图已出帧：缩略图落盘只服务下次冷启动，勿为切 local 再 setState 闪一下。
        if (downloadProgress >= 100 &&
            !_shouldSkipReceiveFileLocationRebuild()) {
          shouldRebuild = true;
        }
      }
    }

    if (shouldRebuild) {
      if (!TickerMode.of(context)) {
        return;
      }
      ChatJitterDiag.logSetState(
        widget: 'TIMUIKitImageElem',
        reason: 'row_revision_file_update',
        msgId: widget.message.msgID,
        extras: <String, Object?>{
          'fileLocation': _trackedFileLocation,
        },
      );
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {});
        }
      });
    }
  }

  @override
  void didUpdateWidget(covariant TIMUIKitImageElem oldWidget) {
    super.didUpdateWidget(oldWidget);
    final pathChanged =
        oldWidget.message.imageElem?.path != widget.message.imageElem?.path;
    final statusChanged = oldWidget.message.status != widget.message.status;
    final msgIdChanged = oldWidget.message.msgID != widget.message.msgID;

    if (pathChanged) {
      final path = _resolveSelfSendLocalImagePath();
      if (path != null && path != _localLayoutPath) {
        _localLayoutSize = null;
        _localLayoutPath = null;
      }
    }

    if (statusChanged || pathChanged) {
      setState(() {});
      return;
    }

    if (msgIdChanged) {
      final msgID = TencentUtils.checkString(widget.message.msgID);
      if (msgID != null) {
        _trackedFileLocation = globalModel.getFileMessageLocation(msgID);
      }
    }
  }

  String getOriginImgURL() {
    // 实际拿的是原图
    V2TimImage? img = MessageUtils.getImageFromImgList(
        widget.message.imageElem!.imageList,
        HistoryMessageDartConstant.oriImgPrior);
    return img == null ? widget.message.imageElem!.path! : img.url!;
  }

  Widget _buildImageBottomGradient() {
    return const Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      height: 42,
      child: IgnorePointer(
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0x00000000),
                Color(0x8C000000),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildImageWatermarkMeta(TUITheme theme) {
    return Positioned(
      right: 8,
      bottom: 6,
      child: MessageBubbleWatermark(
        message: widget.message,
        chatModel: widget.chatModel,
        theme: theme,
        style: MessageBubbleWatermarkStyle.onDarkMedia,
        showGradientScrim: false,
      ),
    );
  }

  /// SDK type：0 原图、1 缩略图、2 大图（与 V2TIM_IMAGE_TYPE 对齐）。
  V2TimImage? _getImageBySdkType(int type) {
    final list = widget.message.imageElem?.imageList;
    if (list == null) {
      return null;
    }
    for (final item in list) {
      if (item?.type == type) {
        return item;
      }
    }
    return null;
  }

  bool _isBubbleSourceThumb({
    String? networkUrl,
    String? localPath,
  }) {
    final list = widget.message.imageElem?.imageList;
    if (list == null || list.isEmpty) {
      return false;
    }
    final url = networkUrl?.trim() ?? '';
    final path = localPath?.trim() ?? '';
    for (final image in list) {
      if (!isChatBubbleSdkThumbType(image?.type)) {
        continue;
      }
      if (url.isNotEmpty && (image?.url?.trim() ?? '') == url) {
        return true;
      }
      if (path.isNotEmpty && (image?.localUrl?.trim() ?? '') == path) {
        return true;
      }
    }
    return false;
  }

  /// 用于布局宽高比：原图 > 大图 > 缩略图，避免缩略图近方形元数据把气泡拉歪。
  V2TimImage? _imageMetaForAspectRatio(
    V2TimImage? originalImg,
    V2TimImage? smallImg,
  ) {
    final fromList = preferChatBubbleImageLayoutMeta(
      widget.message.imageElem?.imageList ?? const [],
    );
    if (fromList != null) {
      return fromList;
    }
    bool hasSize(V2TimImage? img) =>
        img?.width != null &&
        img?.height != null &&
        img!.width! > 0 &&
        img.height! > 0;
    if (hasSize(originalImg) && originalImg?.type != 1) {
      return originalImg;
    }
    if (hasSize(smallImg) && smallImg?.type != 1) {
      return smallImg;
    }
    if (hasSize(originalImg)) {
      return originalImg;
    }
    if (hasSize(smallImg)) {
      return smallImg;
    }
    return null;
  }

  double _layoutAspectRatio(
    V2TimImage? metaImg,
    double? metaFallback, {
    Size? localFileSize,
  }) {
    if (localFileSize != null &&
        localFileSize.width > 0 &&
        localFileSize.height > 0) {
      return (localFileSize.width / localFileSize.height).clamp(0.05, 5.0);
    }
    final metaWidth = metaImg?.width;
    final metaHeight = metaImg?.height;
    if (metaWidth != null &&
        metaHeight != null &&
        metaWidth > 0 &&
        metaHeight > 0) {
      return (metaWidth / metaHeight).clamp(0.05, 5.0);
    }
    return (metaFallback ?? 0.75).clamp(0.05, 5.0);
  }

  Size? _cachedLocalLayoutSizeForPath(String? path) {
    final value = TencentUtils.checkString(path);
    if (value == null) {
      return null;
    }
    if (_localLayoutPath == value && _localLayoutSize != null) {
      return _localLayoutSize;
    }
    return null;
  }

  void _scheduleLocalImageLayoutProbe(String path) {
    final trimmed = path.trim();
    if (trimmed.isEmpty || _localLayoutPath == trimmed) {
      return;
    }
    final token = ++_localLayoutProbeToken;
    unawaited(_probeLocalImageLayout(trimmed, token));
  }

  Future<void> _probeLocalImageLayout(String path, int token) async {
    try {
      // 布局只需宽高：JPEG/PNG 头同步读，禁止全量 readAsBytes + Image.memory。
      final size = readLocalImageSizeSync(path);
      if (!mounted || token != _localLayoutProbeToken) {
        return;
      }
      if (size == null || size.width <= 0 || size.height <= 0) {
        return;
      }
      if (_localLayoutSize != null &&
          _localLayoutPath == path &&
          (size.width - _localLayoutSize!.width).abs() < 1.5 &&
          (size.height - _localLayoutSize!.height).abs() < 1.5) {
        return;
      }
      // 已有 SDK/元数据宽高且图已出帧：只记尺寸，避免 layout setState 闪跳。
      final metaImg = _imageMetaForAspectRatio(
        getImageFromList(V2TimImageTypesEnum.original),
        getImageFromList(V2TimImageTypesEnum.small),
      );
      final hasMetaSize = metaImg != null &&
          (metaImg.width ?? 0) > 0 &&
          (metaImg.height ?? 0) > 0;
      if (_hasBubbleFrameReady() && hasMetaSize) {
        _localLayoutPath = path;
        _localLayoutSize = size;
        _rememberLayoutSize(size);
        ChatJitterDiag.logMediaLayout(
          kind: 'image',
          msgId: widget.message.msgID,
          width: size.width,
          height: size.height,
          prevW: metaImg.width?.toDouble(),
          prevH: metaImg.height?.toDouble(),
          reason: 'probe_local_file_silent',
        );
        return;
      }
      ChatJitterDiag.logMediaLayout(
        kind: 'image',
        msgId: widget.message.msgID,
        width: size.width,
        height: size.height,
        prevW: _localLayoutSize?.width,
        prevH: _localLayoutSize?.height,
        reason: 'probe_local_file',
      );
      setState(() {
        _localLayoutPath = path;
        _localLayoutSize = size;
      });
      _rememberLayoutSize(size);
    } catch (_) {}
  }

  void _rememberLayoutSize(Size size) {
    if (size.width <= 0 || size.height <= 0) {
      return;
    }
    applyImageLayoutToMessage(widget.message, size);
    final msgID = TencentUtils.checkString(widget.message.msgID);
    if (msgID == null) {
      return;
    }
    unawaited(
      _messageService.setLocalCustomData(
        msgID: msgID,
        localCustomData: widget.message.localCustomData ?? '',
      ),
    );
  }

  String? _resolveLayoutLocalPath({
    V2TimImage? originalImg,
    V2TimImage? smallImg,
  }) {
    final selfPath = _resolveSelfSendLocalImagePath();
    if (_hasLocalImageFile(selfPath)) {
      return selfPath;
    }
    return _preferExistingLocalPath(
      smallImg?.localUrl,
      originalImg?.localUrl,
    );
  }

  Size? _localLayoutSizeForRender(
    V2TimImage? metaImg, {
    V2TimImage? originalImg,
    V2TimImage? smallImg,
  }) {
    for (final key in [widget.message.id, widget.message.msgID]) {
      final id = TencentUtils.checkString(key);
      if (id == null) {
        continue;
      }
      final cachedSize = globalModel.getFileMessageSize(id);
      if (cachedSize != null && cachedSize.width > 0 && cachedSize.height > 0) {
        return cachedSize;
      }
    }

    final persisted = readPersistedImageLayoutSize(widget.message);
    if (persisted != null) {
      return persisted;
    }

    final layoutMeta = preferChatBubbleImageLayoutMeta(
      widget.message.imageElem?.imageList ?? const [],
    );
    if (layoutMeta != null) {
      return Size(
        layoutMeta.width!.toDouble(),
        layoutMeta.height!.toDouble(),
      );
    }

    final localPath = _resolveLayoutLocalPath(
      originalImg: originalImg,
      smallImg: smallImg,
    );
    if (localPath != null) {
      final syncSize = readLocalImageSizeSync(localPath);
      if (syncSize != null) {
        return syncSize;
      }
      final cached = _cachedLocalLayoutSizeForPath(localPath);
      if (cached != null) {
        return cached;
      }
      _scheduleLocalImageLayoutProbe(localPath);
    }

    return null;
  }

  Size _resolveImageDisplaySize(
    BoxConstraints constraints,
    V2TimImage? metaImg,
    double fallbackAspectRatio, {
    Size? localFileSize,
  }) {
    final maxW = constraints.maxWidth.isFinite ? constraints.maxWidth : 200.0;
    final maxH = constraints.maxHeight.isFinite
        ? constraints.maxHeight
        : kChatBubbleImageMaxHeight;

    int? width;
    int? height;
    if (localFileSize != null &&
        localFileSize.width > 0 &&
        localFileSize.height > 0) {
      width = localFileSize.width.round();
      height = localFileSize.height.round();
    }
    if (width != null && height != null && width > 0 && height > 0) {
      return resolveChatBubbleImageDisplaySize(
        maxWidth: maxW,
        maxHeight: maxH,
        sourceWidth: width.toDouble(),
        sourceHeight: height.toDouble(),
      );
    }

    final ratio = fallbackAspectRatio > 0 ? fallbackAspectRatio : 0.75;
    return resolveChatBubbleImageDisplaySize(
      maxWidth: min(maxW, _placeholderBubbleWidth),
      maxHeight: min(maxH, _placeholderBubbleHeight),
      sourceWidth: 1000,
      sourceHeight: 1000 / ratio,
    );
  }

  bool _shouldDeferHeavyBubbleDecode() {
    try {
      return serviceLocator<TUIChatGlobalModel>()
          .shouldSkipHeavyChatListPresentation;
    } catch (_) {
      return false;
    }
  }

  bool _shouldCropTallImagePreview(
    Size displaySize,
    BoxConstraints constraints,
  ) {
    final maxW = constraints.maxWidth.isFinite ? constraints.maxWidth : 200.0;
    final maxH = constraints.maxHeight.isFinite
        ? constraints.maxHeight
        : kChatBubbleImageMaxHeight;
    return isChatBubbleLongImageCropDisplay(
      displaySize,
      maxWidth: maxW,
      maxHeight: maxH,
    );
  }

  Widget errorDisplay(BuildContext context, TUITheme? theme) {
    return ChatImageLoadPlaceholder.bubble(
      theme: theme,
      borderRadius: _imageBorderRadius,
    );
  }

  Widget getImage(image, {imageElem}) {
    return ClipRRect(
      borderRadius: _imageBorderRadius,
      child: image,
    );
  }

  //保存图片到本地相册
  Future<void> _saveImageToLocal(
    context,
    String imageUrl, {
    bool isLocalResource = true,
    TUITheme? theme,
    V2TimMessage? sourceMessage,
  }) async {
    if (PlatformUtils().isWeb) {
      download(imageUrl) async {
        final http.Response r = await http.get(Uri.parse(imageUrl));
        final data = r.bodyBytes;
        final base64data = base64Encode(data);
        final a =
            html.AnchorElement(href: 'data:image/jpeg;base64,$base64data');
        a.download = md5.convert(utf8.encode(imageUrl)).toString();
        a.click();
        a.remove();
      }

      download(imageUrl);
      return;
    }

    if (!await _ensureSaveImagePermission(context, theme)) {
      return;
    }

    final message = sourceMessage ?? widget.message;
    final path = _resolveLocalImagePath(message);
    if (isLocalResource && path.isNotEmpty) {
      final result = await _saveImageFileToGallery(path, imageUrl);
      _notifyImageSaveResult(result);
      return;
    }

    if (!isLocalResource) {
      final localPath = _resolveDownloadedImagePath(message);
      if (localPath.isNotEmpty) {
        final result = await _saveImageFileToGallery(localPath, imageUrl);
        _notifyImageSaveResult(result);
        return;
      }
      if (imageUrl.startsWith('http://') || imageUrl.startsWith('https://')) {
        final result = await _downloadImageAndSave(imageUrl);
        _notifyImageSaveResult(result);
        return;
      }
    }

    final result = await _saveImageFileToGallery(imageUrl, imageUrl);
    _notifyImageSaveResult(result);
  }

  Future<bool> _ensureSaveImagePermission(
      BuildContext context, TUITheme? theme) async {
    if (PlatformUtils().isIOS) {
      return Permissions.checkPermission(
        context,
        Permission.photosAddOnly.value,
        theme!,
        false,
      );
    }
    if (PlatformUtils().isMobile) {
      final DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
      final AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
      if ((androidInfo.version.sdkInt) < 29) {
        return Permissions.checkPermission(
          context,
          Permission.storage.value,
        );
      }
    }
    return true;
  }

  String _resolveLocalImagePath(V2TimMessage message) {
    final path = message.imageElem?.path;
    if (path != null && path.isNotEmpty && File(path).existsSync()) {
      return path;
    }
    final localUrl = message.imageElem?.imageList?.firstOrNull?.localUrl;
    if (localUrl != null &&
        localUrl.isNotEmpty &&
        File(localUrl).existsSync()) {
      return localUrl;
    }
    return '';
  }

  String _resolveDownloadedImagePath(V2TimMessage message) {
    final localPath = _resolveLocalImagePath(message);
    if (localPath.isNotEmpty) {
      return localPath;
    }
    final msgID = message.msgID;
    if (msgID == null || msgID.isEmpty) {
      return '';
    }
    final savedPath = model.getFileMessageLocation(msgID);
    if (savedPath.isNotEmpty && File(savedPath).existsSync()) {
      return savedPath;
    }
    return '';
  }

  Future<dynamic> _saveImageFileToGallery(String path, String nameSeed) async {
    final file = File(path);
    if (!file.existsSync()) {
      return false;
    }
    return GallerySaveToPhotos.saveFile(
      file,
      name: _galleryFileName(nameSeed),
    );
  }

  Future<dynamic> _downloadImageAndSave(String url) async {
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return false;
      }
      final bytes = response.bodyBytes;
      if (bytes.isEmpty) {
        return false;
      }
      return _saveImageBytesToGallery(bytes, url);
    } catch (_) {
      return false;
    }
  }

  Future<dynamic> _saveImageBytesToGallery(
      List<int> bytes, String nameSeed) async {
    return GallerySaveToPhotos.saveBytes(
      Uint8List.fromList(bytes),
      name: _galleryFileName(nameSeed),
    );
  }

  String _galleryFileName(String seed) {
    final digest = md5.convert(utf8.encode(seed)).toString();
    return 'chat_img_${digest.substring(0, 12)}_${DateTime.now().millisecondsSinceEpoch}';
  }

  bool _isImageSaveSuccess(dynamic result) {
    if (result == null) return false;
    if (result is bool) return result;
    if (result is num) {
      return result == 100 || result == 1 || result == 0;
    }
    if (result is String) {
      final value = result.trim().toLowerCase();
      if (value.isEmpty) return false;
      if (value == 'true' || value == 'success' || value == 'ok') return true;
      if (value.contains('fail') || value.contains('error')) return false;
      return true;
    }
    if (result is Map) {
      final code = result['returnCode'] ??
          result['resultCode'] ??
          result['code'] ??
          result['status'] ??
          result['errorCode'];
      if (code is num && (code == 100 || code == 1 || code == 0)) {
        return true;
      }
      if (code is String) {
        final value = code.trim().toLowerCase();
        if (value == '100' ||
            value == '1' ||
            value == '0' ||
            value == 'success') {
          return true;
        }
      }

      final filePath = result['filePath'] ??
          result['path'] ??
          result['file'] ??
          result['uri'] ??
          result['url'];
      if (filePath != null && filePath.toString().trim().isNotEmpty) {
        return true;
      }

      final success = result['isSuccess'] ??
          result['success'] ??
          result['saved'] ??
          result['ok'];
      if (success is bool) return success;
      if (success is num) return success == 1 || success == 100 || success == 0;
      if (success is String) {
        final value = success.trim().toLowerCase();
        if (value == 'true' ||
            value == '1' ||
            value == '100' ||
            value == 'success' ||
            value == 'ok') {
          return true;
        }
        if (value == 'false' || value == '0' || value.contains('fail')) {
          return false;
        }
      }

      final error =
          result['error'] ?? result['errorMessage'] ?? result['message'];
      if (error != null && error.toString().trim().isNotEmpty) {
        return false;
      }
      return true;
    }
    return true;
  }

  void _notifyImageSaveResult(dynamic result) {
    onTIMCallback(TIMCallback(
      type: TIMCallbackType.INFO,
      infoRecommendText:
          TIM_t(_isImageSaveSuccess(result) ? '图片保存成功' : '图片保存失败'),
      infoCode: _isImageSaveSuccess(result) ? 6660406 : 6660407,
    ));
  }

  Future<void> _saveImg(TUITheme theme) async {
    try {
      String? imageUrl;
      bool isAssetBool = false;
      final imageElem = widget.message.imageElem;

      if (imageElem != null) {
        final originUrl = getOriginImgURL();
        final localUrl = imageElem.imageList?.firstOrNull?.localUrl;
        final filePath = imageElem.path;
        final isWeb = PlatformUtils().isWeb;

        if (!isWeb && filePath != null && File(filePath).existsSync()) {
          imageUrl = filePath;
          isAssetBool = true;
        } else if (localUrl != null &&
            (!isWeb && File(localUrl).existsSync())) {
          imageUrl = localUrl;
          isAssetBool = true;
        } else {
          imageUrl = originUrl;
          isAssetBool = false;
        }
      }

      if (imageUrl != null) {
        return await _saveImageToLocal(
          context,
          imageUrl,
          isLocalResource: isAssetBool,
          theme: theme,
          sourceMessage: widget.message,
        );
      }
    } catch (_) {
      _notifyImageSaveResult(null);
      return;
    }
  }

  V2TimImage? getImageFromList(V2TimImageTypesEnum imgType) {
    final imageList = widget.message.imageElem?.imageList;
    if (imageList == null || imageList.isEmpty) {
      return null;
    }
    return MessageUtils.getImageFromImgList(
      imageList,
      HistoryMessageDartConstant.imgPriorMap[imgType] ??
          HistoryMessageDartConstant.oriImgPrior,
    );
  }

  V2TimImage? _getImageFromListForMessage(
    V2TimMessage message,
    V2TimImageTypesEnum imgType,
  ) {
    final imageList = message.imageElem?.imageList;
    if (imageList == null) {
      return null;
    }
    return MessageUtils.getImageFromImgList(
      imageList,
      HistoryMessageDartConstant.imgPriorMap[imgType] ??
          HistoryMessageDartConstant.oriImgPrior,
    );
  }

  String _heroTagForMessage(V2TimMessage message) {
    return "${message.msgID ?? message.id ?? message.timestamp ?? DateTime.now().millisecondsSinceEpoch}${widget.isFrom}";
  }

  ImageProvider? _resolvePreviewImageProvider(V2TimMessage message) {
    return ChatMessagePreviewImageResolver.resolve(message);
  }

  Future<void> _saveImgForMessage(V2TimMessage message, TUITheme theme) async {
    try {
      String? imageUrl;
      bool isAssetBool = false;
      final imageElem = message.imageElem;

      if (imageElem != null) {
        final originalImg =
            _getImageFromListForMessage(message, V2TimImageTypesEnum.original);
        final originUrl = originalImg?.url ?? imageElem.path ?? "";
        final localUrl = imageElem.imageList?.firstOrNull?.localUrl;
        final filePath = imageElem.path;
        final isWeb = PlatformUtils().isWeb;

        if (!isWeb && filePath != null && File(filePath).existsSync()) {
          imageUrl = filePath;
          isAssetBool = true;
        } else if (localUrl != null &&
            (!isWeb && File(localUrl).existsSync())) {
          imageUrl = localUrl;
          isAssetBool = true;
        } else {
          imageUrl = originUrl;
          isAssetBool = false;
        }
      }

      if (imageUrl != null) {
        return await _saveImageToLocal(
          context,
          imageUrl,
          isLocalResource: isAssetBool,
          theme: theme,
          sourceMessage: message,
        );
      }
    } catch (_) {
      _notifyImageSaveResult(null);
    }
  }

  Future<void> _forwardPreviewMessage(V2TimMessage message) async {
    if (message.status == MessageStatus.V2TIM_MSG_STATUS_SEND_FAIL) {
      onTIMCallback(TIMCallback(
        type: TIMCallbackType.INFO,
        infoRecommendText: TIM_t("发送失败消息不支持转发！"),
      ));
      return;
    }
    widget.chatModel.updateMultiSelectStatus(false);
    widget.chatModel.setMessageItemChecked(message, true);
    if (!mounted) {
      return;
    }
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ForwardMessageScreen(
          conversationType: widget.chatModel.conversationType ?? ConvType.c2c,
          model: widget.chatModel,
        ),
      ),
    );
  }

  Future<void> _deletePreviewMessage(V2TimMessage message) async {
    final msgID = message.msgID;
    if (msgID == null || msgID.isEmpty) {
      return;
    }
    if (message.isSelf == true) {
      await widget.chatModel.revokeMsg(msgID, false);
    } else {
      await widget.chatModel.deleteMsg(msgID);
    }
  }

  void _openConversationMediaPageFromPreview() {
    openChatConversationMediaPage(
      context: context,
      chatModel: widget.chatModel,
    );
  }

  ChatMediaPreviewBuildResult _buildImagePreviewItems(
    List<V2TimMessage> originList,
    TUITheme theme,
  ) {
    return buildChatMediaPreviewItems(
      originList: originList,
      tappedMessage: widget.message,
      types: kChatMediaPreviewImageTypes,
      heroTagBuilder: _heroTagForMessage,
      onDownload: (message) => _saveImgForMessage(message, theme),
      onEdit: ImagePreviewEditor.isSupported
          ? (message, previewContext) =>
              ImagePreviewEditor.editMessageImageAndSave(
                previewContext: previewContext,
                message: message,
              )
          : null,
      onForward: _forwardPreviewMessage,
      onDelete: _deletePreviewMessage,
    );
  }

  void _openMobileImagePreview({
    required TUITheme theme,
    required dynamic heroTag,
    required ImageProvider imageProvider,
    ImageProvider? placeholderImageProvider,
  }) {
    final session = ChatMediaGalleryLiveSession(
      chatModel: widget.chatModel,
      tappedMessage: widget.message,
      types: kChatMediaPreviewImageTypes,
      initialPreview: _buildImagePreviewItems(
        widget.chatModel.getGalleryOriginMessageList(),
        theme,
      ),
      rebuildPreview: (originList) =>
          _buildImagePreviewItems(originList, theme),
      isMounted: () => mounted,
    );

    final convId = widget.chatModel.conversationID;
    MediaPreviewDebug.log('open_from_image_elem', {
      'mixed': session.preview.isMixed,
      'count': session.preview.items.length,
      'initial': session.preview.initialIndex,
      'tapped': widget.message.msgID ?? widget.message.id?.toString() ?? '-',
      'items': MediaPreviewDebug.itemsSummary(session.preview.items),
    });
    globalModel.saveScrollBeforeMediaPreview(
      convId,
      anchorMessageID: widget.message.msgID ?? widget.message.id?.toString(),
    );

    var closingHeroTag = heroTag.toString();
    void onPreviewClosing(String? messageID, String currentHeroTag) {
      closingHeroTag = currentHeroTag;
      MediaPreviewHeroRegistry.instance.revealAll({currentHeroTag});
      // 图集关闭不更新滚动锚点：保持打开时的偏移即可，避免滚到别的消息导致头像闪一下。
      if (session.preview.items.length <= 1) {
        final anchor = messageID?.trim();
        if (anchor != null && anchor.isNotEmpty) {
          globalModel.updateMediaPreviewCloseAnchor(convId, anchor);
        }
      }
    }

    void restoreAfterPreview() {
      session.dispose();
      // 滚动解锁由 pushMediaPreview(restoreChatScrollConversationID) 保证；
      // 此处只做 hero / session，避免气泡 dispose 后永久 NeverScrollable。
      MediaPreviewHeroRegistry.instance.revealAll({closingHeroTag});
    }

    if (session.preview.isMixed) {
      MediaPreviewDebug.log('push_gallery', {
        'from': 'image_elem',
        'initial': session.preview.initialIndex,
        'count': session.preview.items.length,
      });
      pushMediaPreview(
        context: context,
        enableGestureBack: false,
        requiresOpaquePlatformView: true,
        restoreChatScrollConversationID: convId,
        child: StatefulBuilder(
          builder: (context, setPreviewState) {
            session.ensureStarted(() => setPreviewState(() {}));
            return ChatMediaGalleryScreen(
              items: session.preview.items,
              initialIndex: session.preview.initialIndex,
              sourceMessage: widget.message,
              onOpenMedia: _openConversationMediaPageFromPreview,
              onClosing: onPreviewClosing,
            );
          },
        ),
      ).whenComplete(restoreAfterPreview);
      return;
    }

    pushMediaPreview(
      context: context,
      enableGestureBack: false,
      restoreChatScrollConversationID: convId,
      child: StatefulBuilder(
        builder: (context, setPreviewState) {
          session.ensureStarted(() => setPreviewState(() {}));
          final galleryItems = session.preview.items
              .where((item) => item.type == ChatMediaPreviewType.image)
              .map((item) => item.toImageGalleryItem())
              .toList();
          final tappedGalleryIndex = findChatMediaGalleryMessageIndex(
            messagesOldestFirst: [
              for (final item in galleryItems)
                if (item.sourceMessage != null) item.sourceMessage!,
            ],
            target: widget.message,
          );
          final galleryInitialIndex = tappedGalleryIndex >= 0
              ? tappedGalleryIndex
              : session.preview.initialIndex.clamp(
                  0,
                  galleryItems.isEmpty ? 0 : galleryItems.length - 1,
                );
          return ImageScreen(
            imageProvider: imageProvider,
            placeholderImageProvider: placeholderImageProvider,
            heroTag: heroTag,
            messageID: widget.message.msgID,
            sourceMessage: widget.message,
            headerTitle:
                MediaPreviewHeaderUtils.titleForMessage(widget.message),
            headerSubtitle: MediaPreviewHeaderUtils.subtitleForMessage(
              widget.message.timestamp,
            ),
            forwardFn: () => _forwardPreviewMessage(widget.message),
            deleteFn: () => _deletePreviewMessage(widget.message),
            onOpenMedia: _openConversationMediaPageFromPreview,
            onClosing: onPreviewClosing,
            galleryItems: galleryItems,
            initialIndex: galleryInitialIndex,
            forceGalleryMode: true,
            downloadFn: () => _saveImg(theme),
            editFn: ImagePreviewEditor.isSupported
                ? (previewContext) =>
                    ImagePreviewEditor.editMessageImageAndSave(
                      previewContext: previewContext,
                      message: widget.message,
                    )
                : null,
          );
        },
      ),
    ).whenComplete(restoreAfterPreview);
  }

  void launchDesktopFile(String path) {
    if (PlatformUtils().isWindows) {
      OpenFile.open(path);
    } else {
      launchUrl(Uri.file(path));
    }
  }

  /// 全屏预览失败页（勿用于气泡：会撑满屏幕高度，在会话长按预览里变成整块灰黑）。
  Widget errorPage(theme) => Container(
      height: MediaQuery.of(context).size.height,
      color: theme.black,
      child: GestureDetector(
        onTap: () {
          Navigator.of(context).pop();
        },
        child: Center(
          child: ChatImageLoadPlaceholder.preview(),
        ),
      ));

  /// 聊天气泡内加载失败/缺 URL：固定气泡尺寸，不撑满父级。
  Widget _bubbleLoadFailure(TUITheme? theme) => errorDisplay(context, theme);

  bool checkIfDownloadSuccess() {
    final localUrl = TencentUtils.checkString(
            model.getFileMessageLocation(widget.message.msgID)) ??
        widget.message.imageElem!.imageList![0]!.localUrl;
    return TencentUtils.checkString(localUrl) != null &&
        File(localUrl!).existsSync();
  }

  _onClickOpenImageInNewWindow() {
    final localUrl = TencentUtils.checkString(
            model.getFileMessageLocation(widget.message.msgID)) ??
        widget.message.imageElem!.imageList![0]!.localUrl;
    Future.delayed(const Duration(milliseconds: 0), () async {
      final isDownloaded = checkIfDownloadSuccess();
      if (isDownloaded) {
        launchDesktopFile(localUrl ?? "");
      } else {
        onTIMCallback(TIMCallback(
            infoCode: 6660414,
            infoRecommendText: TIM_t("正在下载原始资源，请稍候..."),
            type: TIMCallbackType.INFO));
      }
    });
  }

  _handleOnTapPreviewImageOnDesktop({
    double? positionRadio,
    String? originImgUrl,
  }) {
    final localUrl = TencentUtils.checkString(
            model.getFileMessageLocation(widget.message.msgID)) ??
        widget.message.imageElem!.imageList![0]!.localUrl;
    if (checkIfDownloadSuccess()) {
      TUIKitWidePopup.showMedia(
          aspectRatio: positionRadio,
          context: context,
          mediaLocalPath: localUrl ?? "",
          onClickOrigin: () => _onClickOpenImageInNewWindow());
    } else {
      if (TencentUtils.checkString(originImgUrl) != null) {
        TUIKitWidePopup.showMedia(
            aspectRatio: positionRadio,
            context: context,
            mediaURL: originImgUrl,
            onClickOrigin: () => _onClickOpenImageInNewWindow());
      } else {
        onTIMCallback(TIMCallback(
            infoCode: 6660414,
            infoRecommendText: TIM_t("正在下载中"),
            type: TIMCallbackType.INFO));
      }
    }
  }

  Future<void> onClickImage({
    required bool isNetworkImage,
    dynamic heroTag,
    required TUITheme theme,
    String? imgUrl,
    String? imgPath,
  }) async {
    if (!PlatformUtils().isDesktop &&
        globalModel.isMessageContextMenuOverlayOpen) {
      return;
    }

    if (PlatformUtils().isDesktop && !PlatformUtils().isWeb) {
      if (isNetworkImage) {
        _handleOnTapPreviewImageOnDesktop(
          originImgUrl: imgUrl,
        );
      } else {
        TUIKitWidePopup.showMedia(
            mediaLocalPath: imgPath,
            context: context,
            onClickOrigin: () => launchDesktopFile(imgPath ?? ""));
      }
      return;
    }

    if (PlatformUtils().isWeb) {
      try {
        await _ensurePreviewOriginalUrlIfNeeded().timeout(
          const Duration(milliseconds: 400),
          onTimeout: () {},
        );
      } catch (_) {}
      if (!mounted) {
        return;
      }
      unawaited(_ensurePreviewOriginalUrlIfNeeded());

      final previewUrl = _resolveWebLightboxPreviewUrl(
        imgUrl: imgUrl,
        isNetworkImage: isNetworkImage,
      );
      if (previewUrl == null || previewUrl.isEmpty) {
        return;
      }
      ChatImageOriginalPrefetch.schedule(widget.message);
      await ChatWebImageLightbox.show(
        context: context,
        imageUrl: previewUrl,
        onDownload: () => _saveImg(theme),
        onOpenExternal: () {
          launchUrl(
            Uri.parse(previewUrl),
            mode: LaunchMode.externalApplication,
          );
        },
      );
      return;
    }

    var previewProvider = _resolvePreviewImageProvider(widget.message);
    final placeholderProvider =
        ChatMessagePreviewImageResolver.resolvePlaceholder(widget.message);

    if (previewProvider == null && placeholderProvider == null) {
      try {
        await _ensurePreviewOriginalUrlIfNeeded().timeout(
          const Duration(milliseconds: 400),
          onTimeout: () {},
        );
      } catch (_) {}
      if (!mounted) {
        return;
      }
      previewProvider = _resolvePreviewImageProvider(widget.message);
    } else {
      unawaited(_ensurePreviewOriginalUrlIfNeeded());
    }
    previewProvider ??= placeholderProvider;
    if (previewProvider == null) {
      if (PlatformUtils().isWeb && isNetworkImage) {
        final fallbackUrl = TencentUtils.checkString(imgUrl) ??
            TencentUtils.checkString(widget.message.imageElem?.path);
        if (fallbackUrl != null) {
          previewProvider = NetworkImage(fallbackUrl);
        }
      }
    }
    if (previewProvider == null) {
      return;
    }
    ChatImageOriginalPrefetch.schedule(widget.message);

    _openMobileImagePreview(
      theme: theme,
      heroTag: heroTag,
      imageProvider: previewProvider,
      placeholderImageProvider: placeholderProvider,
    );
  }

  Future<void> _ensurePreviewOriginalUrlIfNeeded() async {
    if (PlatformUtils().isWeb || widget.message.isSelf == true) {
      return;
    }
    final msgID = TencentUtils.checkString(widget.message.msgID);
    if (msgID == null) {
      return;
    }
    if (!_needsPreviewOriginalUrl(widget.message)) {
      return;
    }
    try {
      final response = await _messageService.getMessageOnlineUrl(
        msgID: msgID,
        reportError: false,
      );
      final imageElem = response.data?.imageElem;
      if (imageElem != null && mounted) {
        widget.message.imageElem = imageElem;
        setState(() {});
      }
    } catch (_) {}
  }

  bool _needsPreviewOriginalUrl(V2TimMessage message) {
    if (message.isSelf == true) {
      final originalImg =
          _getImageFromListForMessage(message, V2TimImageTypesEnum.original);
      if (TencentUtils.checkString(originalImg?.url) != null) {
        return false;
      }
      final bigImg =
          _getImageFromListForMessage(message, V2TimImageTypesEnum.big);
      if (TencentUtils.checkString(bigImg?.url) != null) {
        return false;
      }
      return true;
    }
    final bigImg =
        _getImageFromListForMessage(message, V2TimImageTypesEnum.big);
    if (TencentUtils.checkString(bigImg?.url) != null) {
      return false;
    }
    final originalImg =
        _getImageFromListForMessage(message, V2TimImageTypesEnum.original);
    if (TencentUtils.checkString(originalImg?.url) != null) {
      return false;
    }
    return true;
  }

  /// 进场转场占位：固定尺寸灰块，不转圈（转场约 300ms，转圈会让用户误以为在加载）。
  Widget _imageTransitionPlaceholder(TUITheme theme) {
    return ColoredBox(
      color: theme.weakDividerColor ?? const Color(0xFFE8E8E8),
    );
  }

  Widget _renderAllImage({
    required dynamic heroTag,
    double? positionRadio,
    required TUITheme theme,
    required BoxConstraints constraints,
    bool isNetworkImage = false,
    String? webPath,
    V2TimImage? originalImg,
    V2TimImage? smallImg,
    String? smallLocalPath,
    String? originLocalPath,
    Size? localFileSize,
  }) {
    final maxW = constraints.maxWidth.isFinite ? constraints.maxWidth : 200.0;
    final maxH = constraints.maxHeight.isFinite
        ? constraints.maxHeight
        : kChatBubbleImageMaxHeight;
    final boxConstraints = BoxConstraints(maxWidth: maxW, maxHeight: maxH);
    final selectedNetworkUrl = isNetworkImage
        ? _resolveBubbleNetworkImageUrl(
            webPath: webPath,
            originalImg: originalImg,
            smallImg: smallImg,
          )
        : null;
    final selectedLocalPath =
        _preferExistingLocalPath(smallLocalPath, originLocalPath);
    final renderedMeta = resolveChatBubbleRenderedImageMeta(
      images: widget.message.imageElem?.imageList ?? const [],
      networkUrl: selectedNetworkUrl,
      localPath: selectedLocalPath,
    );
    final sourceIsThumb = _isBubbleSourceThumb(
      networkUrl: selectedNetworkUrl,
      localPath: selectedLocalPath,
    );
    // 布局跟原图/大图元数据，避免 THUMB 方形像素把气泡比例改掉。
    final metaForLayout =
        _imageMetaForAspectRatio(originalImg, smallImg) ?? renderedMeta;
    final selectedLocalSize =
        (!isNetworkImage && selectedLocalPath != null && !sourceIsThumb)
            ? (readLocalImageSizeSync(selectedLocalPath) ??
                _cachedLocalLayoutSizeForPath(selectedLocalPath))
            : null;
    final metaLayoutSize = (metaForLayout?.width != null &&
            metaForLayout!.width! > 0 &&
            metaForLayout.height != null &&
            metaForLayout.height! > 0)
        ? Size(
            metaForLayout.width!.toDouble(),
            metaForLayout.height!.toDouble(),
          )
        : null;
    final effectiveLayoutSize =
        metaLayoutSize ?? selectedLocalSize ?? localFileSize;
    final layoutRatio = _layoutAspectRatio(
      metaForLayout,
      positionRadio,
      localFileSize: effectiveLayoutSize,
    );
    final displaySize = _resolveImageDisplaySize(
      boxConstraints,
      metaForLayout,
      layoutRatio,
      localFileSize: effectiveLayoutSize,
    );
    // 是否裁切只看最终气泡框是不是 92×190，避免源尺寸与显示尺寸各判一次导致
    // 框已经是裁切框却仍用 contain，把整张长图再压进去。
    final cropTallPreview =
        _shouldCropTallImagePreview(displaySize, boxConstraints);
    // 普通图气泡比例已与原图一致，用 contain 避免解码拉伸。
    // 超长竖图：92×190 框 + cover 顶对齐，只显示前一段，避免整图压进框里发糊。
    final imageFit = cropTallPreview ? BoxFit.cover : BoxFit.contain;
    const imageAlignment = Alignment.topCenter;

    final dpr = MediaQuery.devicePixelRatioOf(context);
    final deferHeavyDecode = _shouldDeferHeavyBubbleDecode();
    // 列表气泡一律按显示尺寸有界解码（含 thumb 文件），避免开页多图无界尖刺。
    final decodeTarget = resolveChatBubbleImageDecodeTarget(
      displayWidth: displaySize.width,
      displayHeight: displaySize.height,
      devicePixelRatio: dpr,
      deferHeavyDecode: deferHeavyDecode,
      coverCropTallImage: cropTallPreview,
    );
    final bubbleFilterQuality =
        sourceIsThumb ? FilterQuality.medium : FilterQuality.high;

    ImageFrameBuilder frameBuilderForKey(String frameKey) {
      return (BuildContext context, Widget child, int? frame,
          bool wasSynchronouslyLoaded) {
        if (frame != null || wasSynchronouslyLoaded) {
          _markBubbleFrameReady(frameKey);
          return child;
        }
        // 已解出过帧（含同气泡换 URL/路径）：保留 child，避免转场/补链闪灰。
        if (_readyImageFrameKeys.contains(frameKey) ||
            _hasBubbleFrameReady()) {
          return child;
        }
        return SizedBox(
          width: displaySize.width,
          height: displaySize.height,
          child: _imageTransitionPlaceholder(theme),
        );
      };
    }

    Widget buildLocalImage(String imgPath) {
      if (PlatformUtils().isWeb && _isWebRenderableImageUrl(imgPath)) {
        _probeBubbleDecodeProvider(
          provider: NetworkImage(imgPath),
          source: 'web',
          pathOrUrl: imgPath,
          sdkType: _sdkTypeLabelForLocalPath(
            imgPath,
            originalImg: originalImg,
            smallImg: smallImg,
          ),
          displaySize: displaySize,
          cacheW: -1,
          cacheH: -1,
          deferHeavyDecode: deferHeavyDecode,
          dpr: dpr,
          metaImg: _imageMetaForAspectRatio(originalImg, smallImg),
        );
        return SizedBox(
          width: displaySize.width,
          height: displaySize.height,
          child: Image.network(
            imgPath,
            key: ValueKey<String>(_bubbleImageWidgetKey('web', urlOrPathFallback: imgPath)),
            width: displaySize.width,
            height: displaySize.height,
            fit: imageFit,
            alignment: imageAlignment,
            filterQuality: FilterQuality.high,
            gaplessPlayback: true,
            webHtmlElementStrategy: _webImageElementStrategyFor(imgPath),
            frameBuilder: frameBuilderForKey('net:$imgPath'),
            errorBuilder: (_, __, ___) => _bubbleLoadFailure(theme),
          ),
        );
      }
      final ImageProvider localProvider = ResizeImage(
        FileImage(File(imgPath)),
        width: decodeTarget.width,
        height: decodeTarget.height,
      );
      _probeBubbleDecodeProvider(
        provider: localProvider,
        source: 'file',
        pathOrUrl: imgPath,
        sdkType: _sdkTypeLabelForLocalPath(
          imgPath,
          originalImg: originalImg,
          smallImg: smallImg,
        ),
        displaySize: displaySize,
        cacheW: decodeTarget.width ?? -1,
        cacheH: decodeTarget.height ?? -1,
        deferHeavyDecode: deferHeavyDecode,
        dpr: dpr,
        metaImg: _imageMetaForAspectRatio(originalImg, smallImg),
      );
      return SizedBox(
        width: displaySize.width,
        height: displaySize.height,
        child: Image.file(
          File(imgPath),
          key: ValueKey<String>(
            _bubbleImageWidgetKey('local', urlOrPathFallback: imgPath),
          ),
          width: displaySize.width,
          height: displaySize.height,
          fit: imageFit,
          alignment: imageAlignment,
          filterQuality: bubbleFilterQuality,
          cacheWidth: decodeTarget.width,
          cacheHeight: decodeTarget.height,
          gaplessPlayback: true,
          frameBuilder: frameBuilderForKey('local:$imgPath'),
        ),
      );
    }

    Widget networkFallback() {
      if (selectedLocalPath != null && _hasLocalImageFile(selectedLocalPath)) {
        return buildLocalImage(selectedLocalPath);
      }
      return _bubbleLoadFailure(theme);
    }

    ImageFrameBuilder networkFrameBuilderForKey(String frameKey) {
      return (BuildContext context, Widget child, int? frame,
          bool wasSynchronouslyLoaded) {
        if (frame != null || wasSynchronouslyLoaded) {
          _markBubbleFrameReady(frameKey);
          return child;
        }
        if (_readyImageFrameKeys.contains(frameKey) ||
            _hasBubbleFrameReady()) {
          return child;
        }
        if (selectedLocalPath != null &&
            _hasLocalImageFile(selectedLocalPath)) {
          return buildLocalImage(selectedLocalPath);
        }
        return SizedBox(
          width: displaySize.width,
          height: displaySize.height,
          child: _imageTransitionPlaceholder(theme),
        );
      };
    }

    Widget? buildNetworkImageIfPossible() {
      final imageUrl = _resolveBubbleNetworkImageUrl(
        webPath: webPath,
        originalImg: originalImg,
        smallImg: smallImg,
      );
      if (imageUrl == null || imageUrl.isEmpty) {
        return null;
      }
      if (PlatformUtils().isWeb) {
        _probeBubbleDecodeProvider(
          provider: NetworkImage(imageUrl),
          source: 'web',
          pathOrUrl: imageUrl,
          sdkType: _sdkTypeLabelForNetworkUrl(
            imageUrl,
            originalImg: originalImg,
            smallImg: smallImg,
          ),
          displaySize: displaySize,
          cacheW: -1,
          cacheH: -1,
          deferHeavyDecode: deferHeavyDecode,
          dpr: dpr,
          metaImg: _imageMetaForAspectRatio(originalImg, smallImg),
        );
        return SizedBox(
          width: displaySize.width,
          height: displaySize.height,
          child: Image.network(
            imageUrl,
            key: ValueKey<String>(
              _bubbleImageWidgetKey('net', urlOrPathFallback: imageUrl),
            ),
            width: displaySize.width,
            height: displaySize.height,
            fit: imageFit,
            alignment: imageAlignment,
            filterQuality: FilterQuality.high,
            gaplessPlayback: true,
            webHtmlElementStrategy: _webImageElementStrategyFor(imageUrl),
            frameBuilder: networkFrameBuilderForKey('net:$imageUrl'),
            errorBuilder: (_, __, ___) => networkFallback(),
          ),
        );
      }
      final networkImageProvider = CachedNetworkImageProvider(
        imageUrl,
        cacheKey: chatMediaBubbleImageCacheKey(
          widget.message.msgID,
          urlFallback: imageUrl,
        ),
      );
      final ImageProvider networkProvider = ResizeImage(
        networkImageProvider,
        width: decodeTarget.width,
        height: decodeTarget.height,
      );
      _probeBubbleDecodeProvider(
        provider: networkProvider,
        source: 'network',
        pathOrUrl: imageUrl,
        sdkType: _sdkTypeLabelForNetworkUrl(
          imageUrl,
          originalImg: originalImg,
          smallImg: smallImg,
        ),
        displaySize: displaySize,
        cacheW: decodeTarget.width ?? -1,
        cacheH: decodeTarget.height ?? -1,
        deferHeavyDecode: deferHeavyDecode,
        dpr: dpr,
        metaImg: _imageMetaForAspectRatio(originalImg, smallImg),
      );
      return SizedBox(
        width: displaySize.width,
        height: displaySize.height,
        child: Image(
          key: ValueKey<String>(
            _bubbleImageWidgetKey('net', urlOrPathFallback: imageUrl),
          ),
          image: networkProvider,
          width: displaySize.width,
          height: displaySize.height,
          fit: imageFit,
          alignment: imageAlignment,
          filterQuality: bubbleFilterQuality,
          gaplessPlayback: true,
          frameBuilder: networkFrameBuilderForKey('net:$imageUrl'),
          errorBuilder: (_, __, ___) => networkFallback(),
        ),
      );
    }

    Widget buildImageContent() {
      // 转场期间（TickerMode 关闭）：
      // - 已有网络 URL：直接挂 Image（disk/memory cache 可同步出帧），进页立刻出图；
      // - 本地缩略图可直接显示；
      // - 尚无 URL/本地文件才用静态灰块，URL 由 initImages 尽快补齐。
      if (!TickerMode.of(context)) {
        if (isNetworkImage) {
          final kept = buildNetworkImageIfPossible();
          if (kept != null) {
            return kept;
          }
        }
        // 网络路径未带 localPath 时，仍可从 SDK imageList.localUrl 兜底。
        final localPath = _preferExistingLocalPath(
          smallLocalPath ?? smallImg?.localUrl,
          originLocalPath ?? originalImg?.localUrl,
        );
        if (localPath != null && localPath.isNotEmpty) {
          return buildLocalImage(localPath);
        }
        return SizedBox(
          width: displaySize.width,
          height: displaySize.height,
          child: _imageTransitionPlaceholder(theme),
        );
      }

      if (isNetworkImage) {
        final networkImage = buildNetworkImageIfPossible();
        if (networkImage == null) {
          return networkFallback();
        }
        return networkImage;
      }

      final imgPath = _preferExistingLocalPath(smallLocalPath, originLocalPath);
      if (imgPath == null || imgPath.isEmpty) {
        return _bubbleLoadFailure(theme);
      }
      return buildLocalImage(imgPath);
    }

    return GestureDetector(
      onTap: () => onClickImage(
          theme: theme,
          heroTag: heroTag,
          isNetworkImage: isNetworkImage,
          imgUrl: _resolvePreviewNetworkImageUrl(
                webPath: webPath,
                originalImg: originalImg,
                smallImg: smallImg,
              ) ??
              "",
          imgPath: (TencentUtils.checkString(originLocalPath) != null
                  ? originLocalPath
                  : smallLocalPath) ??
              ""),
      child: ClipRRect(
        borderRadius: _imageBorderRadius,
        child: ConstrainedBox(
          constraints: BoxConstraints.tight(displaySize),
          child: Stack(
            clipBehavior: Clip.hardEdge,
            children: [
              PreviewHero(
                tag: heroTag,
                placeholderBuilder: (context, size, child) {
                  return ClipRRect(
                    borderRadius: _imageBorderRadius,
                    child: SizedBox(
                      width: size.width,
                      height: size.height,
                    ),
                  );
                },
                child: ClipRRect(
                  borderRadius: _imageBorderRadius,
                  child: buildImageContent(),
                ),
              ),
              _buildImageBottomGradient(),
              _buildImageWatermarkMeta(theme),
              TimUIKitMessageUploadOverlayLayer(
                message: widget.message,
                conversationID: widget.chatModel.conversationID,
                globalModel: globalModel,
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool _isHttpImageUrl(String? url) {
    final value = TencentUtils.checkString(url);
    return value != null &&
        (value.startsWith('http://') || value.startsWith('https://'));
  }

  bool _isWebRenderableImageUrl(String? url) {
    final value = TencentUtils.checkString(url);
    if (value == null) {
      return false;
    }
    return value.startsWith('blob:') ||
        value.startsWith('data:image') ||
        value.startsWith('http://') ||
        value.startsWith('https://');
  }

  WebHtmlElementStrategy _webImageElementStrategyFor(String url) {
    if (url.startsWith('blob:') || url.startsWith('data:image')) {
      return WebHtmlElementStrategy.fallback;
    }
    return WebHtmlElementStrategy.prefer;
  }

  bool _hasLocalImageFile(String? path) {
    final value = TencentUtils.checkString(path);
    if (value == null) {
      return false;
    }
    if (PlatformUtils().isWeb) {
      return _isWebRenderableImageUrl(value);
    }
    return File(value).existsSync();
  }

  String? _resolveWebLightboxPreviewUrl({
    String? imgUrl,
    required bool isNetworkImage,
  }) {
    final originalImg = getImageFromList(V2TimImageTypesEnum.original);
    final bigImg = getImageFromList(V2TimImageTypesEnum.big);
    final smallImg = getImageFromList(V2TimImageTypesEnum.small);

    final httpUrl = _firstNonEmptyImageUrl([originalImg, bigImg, smallImg]);
    if (_isHttpImageUrl(httpUrl)) {
      return httpUrl;
    }

    final bubbleUrl = _resolveWebBubblePreviewUrl(
      originalImg: originalImg,
      smallImg: smallImg,
    );
    if (bubbleUrl != null && bubbleUrl.isNotEmpty) {
      return bubbleUrl;
    }

    if (isNetworkImage) {
      return TencentUtils.checkString(imgUrl) ??
          TencentUtils.checkString(widget.message.imageElem?.path);
    }
    return TencentUtils.checkString(widget.message.imageElem?.path);
  }

  String? _resolveWebBubblePreviewUrl({
    V2TimImage? originalImg,
    V2TimImage? smallImg,
  }) {
    if (!PlatformUtils().isWeb) {
      return null;
    }
    final bigImg = getImageFromList(V2TimImageTypesEnum.big);
    final remote = _firstNonEmptyImageUrl([
      for (final type in kChatBubbleImageSdkTypePriority)
        _getImageBySdkType(type),
      smallImg,
      originalImg,
      bigImg,
    ]);
    if (_isHttpImageUrl(remote)) {
      return remote;
    }
    final elemPath = TencentUtils.checkString(widget.message.imageElem?.path);
    if (_isWebRenderableImageUrl(elemPath)) {
      return elemPath;
    }
    for (final key in [widget.message.id, widget.message.msgID]) {
      final id = TencentUtils.checkString(key);
      if (id == null) {
        continue;
      }
      final saved = globalModel.getFileMessageLocation(id);
      if (_isWebRenderableImageUrl(saved)) {
        return saved;
      }
    }
    return _isWebRenderableImageUrl(remote) ? remote : null;
  }

  String? _preferExistingLocalPath(String? primary, String? fallback) {
    for (final candidate in [primary, fallback]) {
      if (_hasLocalImageFile(candidate)) {
        return candidate;
      }
    }
    if (PlatformUtils().isWeb) {
      return _isWebRenderableImageUrl(primary)
          ? primary
          : (_isWebRenderableImageUrl(fallback) ? fallback : null);
    }
    return primary ?? fallback;
  }

  String? _firstNonEmptyImageUrl(Iterable<V2TimImage?> images) {
    for (final image in images) {
      final url = TencentUtils.checkString(image?.url);
      if (url != null && url.isNotEmpty) {
        return url;
      }
    }
    return null;
  }

  /// 聊天气泡展示：IM THUMB 优先；无缩略图才用大图，原图最后。
  String? _resolveBubbleNetworkImageUrl({
    String? webPath,
    V2TimImage? originalImg,
    V2TimImage? smallImg,
  }) {
    final bigImg = getImageFromList(V2TimImageTypesEnum.big);
    final remote = _firstNonEmptyImageUrl([
      for (final type in kChatBubbleImageSdkTypePriority)
        _getImageBySdkType(type),
      smallImg,
      originalImg,
      bigImg,
    ]);
    if (_isHttpImageUrl(remote)) {
      return remote;
    }
    final direct = TencentUtils.checkString(webPath);
    if (direct != null && direct.isNotEmpty) {
      return direct;
    }
    return remote;
  }

  /// 大图预览：自己发的原图优先；收到的图片大图优先。
  String? _resolvePreviewNetworkImageUrl({
    String? webPath,
    V2TimImage? originalImg,
    V2TimImage? smallImg,
  }) {
    final direct = TencentUtils.checkString(webPath);
    if (direct != null && direct.isNotEmpty) {
      return direct;
    }
    if (widget.message.isSelf == true) {
      return _firstNonEmptyImageUrl([
        originalImg,
        _getImageBySdkType(2),
        smallImg,
        _getImageBySdkType(1),
      ]);
    }
    return _firstNonEmptyImageUrl([
      _getImageBySdkType(2),
      originalImg,
      smallImg,
      _getImageBySdkType(1),
    ]);
  }

  /// 发送中优先 imageElem.path，其次 globalModel 按 clientId/msgID 缓存的本地路径。
  String? _resolveSelfSendLocalImagePath() {
    final elemPath = TencentUtils.checkString(widget.message.imageElem?.path);
    if (_hasLocalImageFile(elemPath)) {
      return elemPath;
    }
    for (final key in [widget.message.id, widget.message.msgID]) {
      final id = TencentUtils.checkString(key);
      if (id == null) {
        continue;
      }
      final saved = globalModel.getFileMessageLocation(id);
      if (_hasLocalImageFile(saved)) {
        return saved;
      }
    }
    return null;
  }

  bool _isArchiveHistoryImage() {
    return HistoryPaginationAnchor.isArchiveHistoryMessage(widget.message);
  }

  ChatBubbleLocalImageChoice? _resolveReceivedLocalChoice({
    V2TimImage? originalImg,
    V2TimImage? smallImg,
  }) {
    final msgID = TencentUtils.checkString(widget.message.msgID);
    final saved =
        msgID == null ? null : globalModel.getFileMessageLocation(msgID);
    final archivePath = _archiveCachePath ??
        (msgID == null
            ? null
            : ChatBubbleArchiveImageStore.instance.existingPathSync(msgID));
    return resolveChatBubbleLocalImageChoice(
      largeLocalUrl: _getImageBySdkType(2)?.localUrl,
      originalLocalUrl:
          originalImg?.localUrl ?? _getImageBySdkType(0)?.localUrl,
      extraLargeLocalUrl: saved,
      archiveCachePath: archivePath,
      thumbLocalUrl: smallImg?.localUrl ?? _getImageBySdkType(1)?.localUrl,
      fileExists: _hasLocalImageFile,
    );
  }

  bool _hasBubbleLocalFile({
    V2TimImage? originalImg,
    V2TimImage? smallImg,
  }) {
    return _resolveReceivedLocalChoice(
      originalImg: originalImg,
      smallImg: smallImg,
    ) != null;
  }

  void _attachLocalPathToImageElem(String path, String? matchingUrl) {
    final list = widget.message.imageElem?.imageList;
    if (list == null || list.isEmpty) {
      return;
    }
    V2TimImage? matched;
    final url = matchingUrl?.trim() ?? '';
    if (url.isNotEmpty) {
      matched = list.firstWhereOrNull(
        (image) => (image?.url?.trim() ?? '') == url,
      );
    }
    matched ??= list.firstWhereOrNull((image) => image?.type == 1);
    matched ??= list.firstWhereOrNull((image) => image?.type == 2);
    matched ??= list.firstWhereOrNull((image) => image != null);
    matched?.localUrl = path;
  }

  Future<void> _persistArchiveHttpIfNeeded(String msgID) async {
    final url = _resolveBubbleNetworkImageUrl(
      originalImg: getImageFromList(V2TimImageTypesEnum.original),
      smallImg: getImageFromList(V2TimImageTypesEnum.small),
    );
    if (url == null || !_isHttpImageUrl(url)) {
      return;
    }
    try {
      final existing =
          await ChatBubbleArchiveImageStore.instance.existingPath(msgID);
      final path = existing ??
          await ChatBubbleArchiveImageStore.instance.ensureCached(
            msgID: msgID,
            url: url,
          );
      if (!mounted || path == null || path.isEmpty) {
        return;
      }
      _archiveCachePath = path;
      _attachLocalPathToImageElem(path, url);
      if (TickerMode.of(context)) {
        // 网图已出帧：落盘仅供下次冷启动，避免 local↔network 切换闪一下。
        if (_hasBubbleFrameReady() ||
            _isNetworkFrameReady(
              originalImg: getImageFromList(V2TimImageTypesEnum.original),
              smallImg: getImageFromList(V2TimImageTypesEnum.small),
            )) {
          ChatJitterDiag.log(
            'image_archive_persist_silent',
            msgId: msgID,
            extras: const <String, Object?>{'reason': 'frame_ready'},
          );
          return;
        }
        ChatJitterDiag.logSetState(
          widget: 'TIMUIKitImageElem',
          reason: 'archive_http_persisted',
          msgId: msgID,
        );
        setState(() {});
      }
    } catch (e) {
      ChatImgTrace.log(
        '[ChatImg] event=archive_persist_error msgId=$msgID err=$e',
      );
    }
  }

  Future<void> _downloadThumbnailSilently(String msgID) async {
    if (_isArchiveHistoryImage()) {
      ChatImgTrace.log(
          '[ChatImg] event=download_skip msgId=$msgID reason=archive');
      ChatJitterDiag.log(
        'image_download_skip',
        msgId: msgID,
        extras: const <String, Object?>{'reason': 'archive'},
      );
      return;
    }
    if (!_hasDownloadableThumbnail()) {
      ChatImgTrace.log(
          '[ChatImg] event=download_skip msgId=$msgID reason=no_remote_url');
      ChatJitterDiag.log(
        'image_download_skip',
        msgId: msgID,
        extras: const <String, Object?>{'reason': 'no_remote_url'},
      );
      return;
    }
    // ignore: avoid_print
    ChatImgTrace.log(
        '[ChatImg] event=download_call msgId=$msgID imageType=1 source=thumb');
    try {
      await _messageService.downloadMessage(
        msgID: msgID,
        messageType: 3,
        imageType: 1,
        isSnapshot: false,
        reportError: false,
      );
    } catch (e) {
      ChatImgTrace.log('[ChatImg] event=download_error msgId=$msgID err=$e');
      // 接收图片阶段的大图下载失败不打断聊天，也不弹全局“操作失败”。
    }
  }

  bool _hasDownloadableThumbnail() {
    final list = widget.message.imageElem?.imageList;
    if (list == null || list.isEmpty) {
      return false;
    }
    final thumb = list.firstWhereOrNull((element) => element?.type == 1) ??
        list.firstWhereOrNull((element) => element?.type == 2);
    final url = TencentUtils.checkString(thumb?.url);
    return url != null && url.isNotEmpty;
  }

  /// imageList 上已有可用 HTTP URL（自建归档图常见）。
  bool _hasUsableHttpImageUrl() {
    final url = _resolveBubbleNetworkImageUrl(
      originalImg: getImageFromList(V2TimImageTypesEnum.original),
      smallImg: getImageFromList(V2TimImageTypesEnum.small),
    );
    final value = url?.trim() ?? '';
    return value.startsWith('http://') || value.startsWith('https://');
  }

  Future<void> initImages() async {
    if (PlatformUtils().isWeb) {
      return;
    }

    final isSending =
        widget.message.status == MessageStatus.V2TIM_MSG_STATUS_SENDING;
    if (isSending) {
      return;
    }

    final msgID = TencentUtils.checkString(widget.message.msgID);
    if (msgID == null) {
      return;
    }

    final localPath = _resolveSelfSendLocalImagePath() ??
        TencentUtils.checkString(widget.message.imageElem?.path);
    if (_hasLocalImageFile(localPath)) {
      return;
    }

    if (widget.message.isSelf == true) {
      // 自己发送的图片优先走发送时本地 path，不自动拉 THUMB。
      return;
    }

    final originalImg = getImageFromList(V2TimImageTypesEnum.original);
    final smallImg = getImageFromList(V2TimImageTypesEnum.small);
    final persistAction = resolveChatBubbleImagePersistAction(
      isSelf: false,
      isArchive: _isArchiveHistoryImage(),
      hasUsableHttpUrl: _hasUsableHttpImageUrl(),
      hasBubbleLocalFile: _hasBubbleLocalFile(
        originalImg: originalImg,
        smallImg: smallImg,
      ),
    );

    if (persistAction == ChatBubbleImagePersistAction.httpPersistArchive) {
      ChatImgTrace.log(
        '[ChatImg] event=init_archive_persist msgId=$msgID',
      );
      unawaited(_persistArchiveHttpIfNeeded(msgID));
      return;
    }

    if (_isArchiveHistoryImage()) {
      ChatImgTrace.log(
        '[ChatImg] event=init_skip_archive msgId=$msgID',
      );
      return;
    }

    final needsUrl = widget.message.imageElem?.imageList == null ||
        widget.message.imageElem!.imageList!.isEmpty ||
        _needsPreviewOriginalUrl(widget.message);

    if (needsUrl) {
      ChatImgTrace.log('[ChatImg] event=get_online_url msgId=$msgID');
      try {
        final beforeOriginal = getImageFromList(V2TimImageTypesEnum.original);
        final beforeSmall = getImageFromList(V2TimImageTypesEnum.small);
        final beforeUrl = _resolveBubbleNetworkImageUrl(
          originalImg: beforeOriginal,
          smallImg: beforeSmall,
        );
        final response = await _messageService.getMessageOnlineUrl(
          msgID: msgID,
          reportError: false,
        );
        final elem = response.data;
        if (elem != null && elem.imageElem != null && mounted) {
          widget.message.imageElem = elem.imageElem;
          final afterOriginal = getImageFromList(V2TimImageTypesEnum.original);
          final afterSmall = getImageFromList(V2TimImageTypesEnum.small);
          final afterUrl = _resolveBubbleNetworkImageUrl(
            originalImg: afterOriginal,
            smallImg: afterSmall,
          );
          final gainedUrl = (beforeUrl == null || beforeUrl.isEmpty) &&
              afterUrl != null &&
              afterUrl.isNotEmpty;
          if (gainedUrl) {
            // 已出过帧或已有本地文件：只写 imageElem（供预览/落盘），勿 setState 闪一下。
            final alreadyShowing = _hasBubbleFrameReady() ||
                _hasBubbleLocalFile(
                  originalImg: afterOriginal,
                  smallImg: afterSmall,
                );
            if (!alreadyShowing) {
              ChatJitterDiag.logSetState(
                widget: 'TIMUIKitImageElem',
                reason: 'initImages_getMessageOnlineUrl',
                msgId: msgID,
              );
              setState(() {});
            } else {
              ChatJitterDiag.log(
                'image_online_url_silent',
                msgId: msgID,
                extras: const <String, Object?>{
                  'reason': 'frame_or_local_ready',
                },
              );
            }
          }
        }
      } catch (_) {
        return;
      }
    }

    if (shouldCallSdkImageDownload(
          action: resolveChatBubbleImagePersistAction(
            isSelf: false,
            isArchive: _isArchiveHistoryImage(),
            hasUsableHttpUrl: _hasUsableHttpImageUrl(),
            hasBubbleLocalFile: _hasBubbleLocalFile(
              originalImg: getImageFromList(V2TimImageTypesEnum.original),
              smallImg: getImageFromList(V2TimImageTypesEnum.small),
            ),
          ),
        ) &&
        !_hasBubbleLocalFile(
          originalImg: getImageFromList(V2TimImageTypesEnum.original),
          smallImg: getImageFromList(V2TimImageTypesEnum.small),
        )) {
      unawaited(_downloadThumbnailSilently(msgID));
    }
  }

  @override
  void initState() {
    super.initState();
    final msgID = TencentUtils.checkString(widget.message.msgID);
    if (msgID != null) {
      _trackedFileLocation = globalModel.getFileMessageLocation(msgID);
      _trackedDownloadProgress = globalModel.getMessageProgress(msgID);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      // 立刻拉在线 URL / 缩略图，不再等转场结束；进页有 URL 或本地文件即可出图。
      // 转场中的 setState 由 frameBuilder + 固定 displaySize 兜住，避免整页抖。
      unawaited(initImages());
    });
  }

  @override
  void dispose() {
    super.dispose();
  }

  Widget _renderImage(
    dynamic heroTag,
    TUITheme theme,
    BoxConstraints constraints, {
    V2TimImage? originalImg,
    V2TimImage? smallImg,
  }) {
    if (widget.message.imageElem == null) {
      return errorDisplay(context, theme);
    }

    final metaImg = _imageMetaForAspectRatio(originalImg, smallImg);
    final localFileSize = _localLayoutSizeForRender(
      metaImg,
      originalImg: originalImg,
      smallImg: smallImg,
    );
    final positionRadio = _layoutAspectRatio(
      metaImg,
      1.0,
      localFileSize: localFileSize,
    );

    final webPreviewPath = _resolveWebBubblePreviewUrl(
      originalImg: originalImg,
      smallImg: smallImg,
    );
    if (PlatformUtils().isWeb && webPreviewPath != null) {
      return _renderAllImage(
          heroTag: heroTag,
          theme: theme,
          constraints: constraints,
          isNetworkImage: true,
          smallImg: smallImg,
          originalImg: originalImg,
          positionRadio: positionRadio,
          localFileSize: localFileSize,
          webPath: webPreviewPath);
    }

    try {
      final selfLocalPath = _resolveSelfSendLocalImagePath();
      if (widget.message.isSelf == true &&
          selfLocalPath != null &&
          selfLocalPath.isNotEmpty) {
        if (PlatformUtils().isWeb && _isWebRenderableImageUrl(selfLocalPath)) {
          return _renderAllImage(
              heroTag: heroTag,
              theme: theme,
              constraints: constraints,
              isNetworkImage: true,
              smallImg: smallImg,
              originalImg: originalImg,
              positionRadio: positionRadio,
              localFileSize: localFileSize,
              webPath: selfLocalPath);
        }
        return _renderAllImage(
            smallLocalPath: selfLocalPath,
            heroTag: heroTag,
            theme: theme,
            constraints: constraints,
            positionRadio: positionRadio,
            localFileSize: localFileSize,
            originLocalPath: selfLocalPath);
      }
    } catch (e) {
      // ignore: avoid_print
      outputLogger.i(e.toString());
    }

    try {
      final localChoice = _resolveReceivedLocalChoice(
        originalImg: originalImg,
        smallImg: smallImg,
      );
      final networkUrl = _resolveBubbleNetworkImageUrl(
        originalImg: originalImg,
        smallImg: smallImg,
      );
      final hasNetworkUrl = networkUrl != null && networkUrl.isNotEmpty;
      final plan = planChatBubbleDisplay(
        hasNetworkUrl: hasNetworkUrl,
        local: localChoice,
        keepNetworkAfterFrameReady: _hasBubbleFrameReady() && hasNetworkUrl,
      );
      if (plan.useNetwork) {
        return _renderAllImage(
          heroTag: heroTag,
          theme: theme,
          constraints: constraints,
          isNetworkImage: true,
          positionRadio: positionRadio,
          localFileSize: localFileSize,
          smallImg: smallImg,
          originalImg: originalImg,
          smallLocalPath: plan.localPath,
          originLocalPath: plan.localPath,
        );
      }
      if (plan.localPath != null && plan.localPath!.isNotEmpty) {
        return _renderAllImage(
          smallLocalPath: plan.localPath,
          heroTag: heroTag,
          theme: theme,
          constraints: constraints,
          positionRadio: positionRadio,
          localFileSize: localFileSize,
          originLocalPath: plan.localPath,
        );
      }
    } catch (e) {
      // ignore: avoid_print
      outputLogger.i(e.toString());
      return _renderAllImage(
          heroTag: heroTag,
          theme: theme,
          constraints: constraints,
          isNetworkImage: true,
          smallImg: smallImg,
          positionRadio: positionRadio,
          localFileSize: localFileSize,
          originalImg: originalImg);
    }

    final networkUrl = _resolveBubbleNetworkImageUrl(
      originalImg: originalImg,
      smallImg: smallImg,
    );
    if (networkUrl != null && networkUrl.isNotEmpty) {
      return _renderAllImage(
          heroTag: heroTag,
          theme: theme,
          constraints: constraints,
          isNetworkImage: true,
          positionRadio: positionRadio,
          localFileSize: localFileSize,
          smallImg: smallImg,
          originalImg: originalImg);
    }

    return errorDisplay(context, theme);
  }

  @override
  Widget tuiBuild(BuildContext context, TUIKitBuildValue value) {
    final convId = widget.chatModel.conversationID;
    final msgKey = ChatUiStateStore.messageKeyOf(widget.message);
    final rowRevision = context.select<ChatUiStateStore, int>(
      (store) => store.rowRevision(convId, msgKey),
    );
    _onRowRevisionUpdate(rowRevision);

    final theme = value.theme;
    final isDesktopScreen =
        TUIKitScreenUtils.getFormFactor(context) == DeviceType.Desktop;
    final stableMessageKey = widget.message.id ??
        widget.message.msgID ??
        widget.message.timestamp ??
        DateTime.now().millisecondsSinceEpoch;
    final heroTag = "$stableMessageKey${widget.isFrom}";

    V2TimImage? originalImg = getImageFromList(V2TimImageTypesEnum.original);
    V2TimImage? smallImg = getImageFromList(V2TimImageTypesEnum.small);
    return VisibilityDetector(
      key: Key(
        'chat_img_vis_${widget.message.msgID ?? widget.message.id ?? widget.message.timestamp}',
      ),
      onVisibilityChanged: (info) {
        ChatImageOriginalPrefetch.onVisibilityChanged(widget.message, info);
      },
      child: TIMUIKitMessageReactionWrapper(
        chatModel: widget.chatModel,
        isShowJump: widget.isShowJump,
        clearJump: widget.clearJump,
        isFromSelf: widget.message.isSelf ?? true,
        isShowMessageReaction: widget.isShowMessageReaction ?? true,
        message: widget.message,
        child: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
          final screenSize = MediaQuery.sizeOf(context);
          final layoutLimits = resolveChatBubbleImageLayoutLimits(
            screenWidth: screenSize.width,
            screenHeight: screenSize.height,
            isDesktop: isDesktopScreen,
          );
          final availableWidth = constraints.maxWidth.isFinite
              ? constraints.maxWidth
              : MediaQuery.sizeOf(context).width *
                  (isDesktopScreen ? 0.45 : 0.7);
          final maxImageWidth = min(
            availableWidth * layoutLimits.widthFactor,
            layoutLimits.maxWidth,
          );
          final imageConstraints = BoxConstraints(
            maxWidth: maxImageWidth,
            maxHeight: layoutLimits.maxHeight,
          );
          return Align(
            alignment: (widget.message.isSelf ?? true)
                ? Alignment.centerRight
                : Alignment.centerLeft,
            child: _renderImage(
              heroTag,
              theme,
              imageConstraints,
              originalImg: originalImg,
              smallImg: smallImg,
            ),
          );
        }),
      ),
    );
  }
}
