import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:tencent_cloud_chat_sdk/enum/message_elem_type.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_message.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_message.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/message_bubble_text_color.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/chat_media_send_utils.dart';

/// In-memory message row height cache keyed by stable message id.
///
/// Reduces repeated layout work when the message list rebuilds during bursts.
/// Also seeds type-based / TextPainter estimates so first-open short-history
/// alignment and list-push do not under-estimate before measured layout.
class ChatMessageHeightCache {
  ChatMessageHeightCache._();

  static final ChatMessageHeightCache instance = ChatMessageHeightCache._();

  static const int _maxEntries = 4000;
  static const int _maxConversationContentEntries = 200;

  /// Legacy large placeholder (kept for reference / callers that need bubble-only).
  /// Short-history row prime must NOT use this — it caused spacer 166→259 jumps.
  static const double imagePlaceholderBubbleHeight = 135;

  /// No-meta image row estimate near measured short-history rows (~59).
  /// Old 135+24=159 overstated contentH and understated first-frame spacer.
  static const double imageRowFallbackHeight = 76;

  /// Approximate vertical chrome around an image bubble (avatar gutter / gap).
  static const double imageRowChromeHeight = 24;

  /// Typical face / sticker glyph + bubble chrome.
  static const double faceRowPlaceholderHeight = 120;

  /// Max display width used when converting SDK meta to row height.
  static const double imageDisplayMaxWidth = 150;

  /// Fallback when screen width is unknown (session-list preload).
  static const double defaultScreenWidth = 390;

  /// Matches [TIMUIKitTextElem] body font size.
  static const double textBodyFontSize =
      MessageBubbleTextColor.messageBodyFontSize;

  /// Matches compact bubble line height used by text elem.
  static const double textBodyLineHeight =
      MessageBubbleTextColor.messageBodyLineHeight;

  /// Bubble horizontal padding total (left + right).
  static const double textBubbleHorizontalPadding =
      MessageBubbleTextColor.messageBubblePaddingHorizontal * 2;

  /// Bubble vertical padding total（对齐 TIMUIKitTextElem 上下各 8）。
  static const double textBubbleVerticalChrome =
      MessageBubbleTextColor.messageBubblePaddingVertical * 2;

  /// Row chrome outside the bubble（时间戳行/头像沟；短文本无 nick 时更紧）。
  static const double textRowChromeHeight = 16;

  /// Default row estimate used by short-history before type-aware estimate.
  /// 对齐单行文本气泡实测高度，避免 56/71 两套口径。
  static const double defaultRowHeight = 55;

  static const double groupTipsRowHeight = 80;
  static const double soundRowHeight = 72;
  static const double fileRowHeight = 88;
  static const double customCardRowHeight = 100;
  static const double videoRowMinHeight = 132;

  final Map<String, double> _heights = <String, double>{};
  final Map<String, double> _measuredContentHeightByConvSignature =
      <String, double>{};

  /// TextPainter.layout 结果缓存（进聊 seed 时同一文案会被反复估高）。
  /// 避免 UI 线程在字形线程上同步等待触发 QoS priority-inversion 告警。
  static const int _maxTextLayoutCacheEntries = 256;
  final Map<String, double> _textLayoutCache = <String, double>{};

  Iterable<String> _keysFor(V2TimMessage message) sync* {
    final msgID = message.msgID?.trim();
    if (msgID != null && msgID.isNotEmpty) {
      yield msgID;
    }
    final id = message.id?.trim();
    if (id != null && id.isNotEmpty && id != msgID) {
      yield id;
    }
  }

  String _conversationContentKey({
    required String conversationID,
    required String identitySignature,
  }) {
    return '$conversationID::${identitySignature.hashCode}';
  }

  /// Last measured short-history tile sum for [conversationID]+list identity.
  double? measuredContentHeightFor({
    required String conversationID,
    required String identitySignature,
  }) {
    final conv = conversationID.trim();
    final sig = identitySignature.trim();
    if (conv.isEmpty || sig.isEmpty) {
      return null;
    }
    final height =
        _measuredContentHeightByConvSignature[_conversationContentKey(
      conversationID: conv,
      identitySignature: sig,
    )];
    if (height == null || !height.isFinite || height <= 0) {
      return null;
    }
    return height;
  }

  /// Persist short-history measured content height for warm-open spacer prime.
  void rememberMeasuredContentHeight({
    required String conversationID,
    required String identitySignature,
    required double contentHeight,
  }) {
    final conv = conversationID.trim();
    final sig = identitySignature.trim();
    if (conv.isEmpty ||
        sig.isEmpty ||
        !contentHeight.isFinite ||
        contentHeight <= 0) {
      return;
    }
    final key = _conversationContentKey(
      conversationID: conv,
      identitySignature: sig,
    );
    final rounded = (contentHeight * 2).roundToDouble() / 2;
    if (_measuredContentHeightByConvSignature.length >=
            _maxConversationContentEntries &&
        !_measuredContentHeightByConvSignature.containsKey(key)) {
      _measuredContentHeightByConvSignature
          .remove(_measuredContentHeightByConvSignature.keys.first);
    }
    _measuredContentHeightByConvSignature[key] = rounded;
  }

  double? heightFor(V2TimMessage message) {
    // 发送成功后 msgID 从 temp → server：两把钥匙都查，避免失缓存再估高抖动。
    for (final key in _keysFor(message)) {
      final height = _heights[key];
      if (height != null && height > 0) {
        return height;
      }
    }
    return null;
  }

  void remember(V2TimMessage message, double height) {
    if (!height.isFinite || height <= 0) {
      return;
    }
    final keys = _keysFor(message).toList(growable: false);
    if (keys.isEmpty) {
      return;
    }
    final rounded = (height * 2).roundToDouble() / 2;
    var changed = false;
    for (final key in keys) {
      final previous = _heights[key];
      if (previous != null && (previous - rounded).abs() < 0.5) {
        continue;
      }
      if (_heights.length >= _maxEntries && !_heights.containsKey(key)) {
        _heights.remove(_heights.keys.first);
      }
      _heights[key] = rounded;
      changed = true;
    }
    if (!changed) {
      return;
    }
  }

  /// 占位 id → 正式 msgID：把已测行高迁过去，供 send_done 后首帧直接命中。
  void rememberAlias(String? fromKey, String? toKey) {
    final from = fromKey?.trim();
    final to = toKey?.trim();
    if (from == null ||
        from.isEmpty ||
        to == null ||
        to.isEmpty ||
        from == to) {
      return;
    }
    final height = _heights[from];
    if (height == null || height <= 0) {
      return;
    }
    if (_heights.length >= _maxEntries && !_heights.containsKey(to)) {
      _heights.remove(_heights.keys.first);
    }
    _heights[to] = height;
  }

  /// Migrate row heights across both msgID and client id of two correlated rows.
  void rememberAliasesBetween(V2TimMessage a, V2TimMessage b) {
    final aKeys = _keysFor(a).toList(growable: false);
    final bKeys = _keysFor(b).toList(growable: false);
    if (aKeys.isEmpty || bKeys.isEmpty) {
      return;
    }
    for (final from in aKeys) {
      for (final to in bKeys) {
        rememberAlias(from, to);
      }
    }
    for (final from in bKeys) {
      for (final to in aKeys) {
        rememberAlias(from, to);
      }
    }
  }

  /// Seeds estimates for any messages missing a cached height.
  void seedEstimatesForMessages(
    Iterable<V2TimMessage?> messages, {
    double screenWidth = defaultScreenWidth,
  }) {
    final width =
        screenWidth.isFinite && screenWidth > 0 ? screenWidth : defaultScreenWidth;
    for (final message in messages) {
      if (message == null) {
        continue;
      }
      seedEstimateIfAbsent(message, screenWidth: width);
    }
  }

  /// Seeds a stable row-height estimate before first measured layout.
  /// Returns the seeded (or existing) height when applicable.
  /// Never overwrites an existing cached height with a fresh estimate.
  double? seedEstimateIfAbsent(
    V2TimMessage message, {
    double screenWidth = defaultScreenWidth,
  }) {
    final existing = heightFor(message);
    if (existing != null && existing > 0) {
      return existing;
    }
    final estimated = estimateRowHeight(message, screenWidth: screenWidth);
    if (estimated == null || estimated <= 0) {
      return null;
    }
    remember(message, estimated);
    return estimated;
  }

  /// Seeds a stable row-height estimate for media before first measured layout.
  /// Returns the seeded (or existing) height when applicable.
  double? seedPlaceholderIfAbsent(V2TimMessage message) {
    return seedEstimateIfAbsent(message);
  }

  /// Best-effort full-row height before decode / first layout.
  double? estimateRowHeight(
    V2TimMessage message, {
    double screenWidth = defaultScreenWidth,
  }) {
    switch (message.elemType) {
      case MessageElemType.V2TIM_ELEM_TYPE_IMAGE:
        return _imagePlaceholderHeight(message);
      case MessageElemType.V2TIM_ELEM_TYPE_FACE:
        return faceRowPlaceholderHeight;
      case MessageElemType.V2TIM_ELEM_TYPE_VIDEO:
        return _videoPlaceholderHeight(message);
      case MessageElemType.V2TIM_ELEM_TYPE_SOUND:
        return soundRowHeight;
      case MessageElemType.V2TIM_ELEM_TYPE_FILE:
        return fileRowHeight;
      case MessageElemType.V2TIM_ELEM_TYPE_GROUP_TIPS:
        return groupTipsRowHeight;
      case MessageElemType.V2TIM_ELEM_TYPE_CUSTOM:
        return customCardRowHeight;
      case MessageElemType.V2TIM_ELEM_TYPE_TEXT:
        return _estimateTextRowHeight(message, screenWidth: screenWidth);
      default:
        return defaultRowHeight;
    }
  }

  /// Type-based row height before decode / first layout. Null for text etc.
  double? placeholderHeightFor(V2TimMessage message) {
    switch (message.elemType) {
      case MessageElemType.V2TIM_ELEM_TYPE_IMAGE:
        return _imagePlaceholderHeight(message);
      case MessageElemType.V2TIM_ELEM_TYPE_FACE:
        return faceRowPlaceholderHeight;
      case MessageElemType.V2TIM_ELEM_TYPE_VIDEO:
        return _videoPlaceholderHeight(message);
      default:
        return null;
    }
  }

  double _estimateTextRowHeight(
    V2TimMessage message, {
    required double screenWidth,
  }) {
    final raw = message.textElem?.text ?? '';
    if (raw.isEmpty) {
      return defaultRowHeight;
    }
    // Mobile chat uses ~70% screen for bubble max width (see chatMessageMaxWidth).
    final maxBubbleWidth = math.max(160.0, screenWidth * 0.70);
    final contentMaxWidth =
        math.max(80.0, maxBubbleWidth - textBubbleHorizontalPadding);
    final cacheKey =
        '${contentMaxWidth.toStringAsFixed(0)}:${raw.length}:${raw.hashCode}';
    final cached = _textLayoutCache[cacheKey];
    if (cached != null) {
      return cached;
    }

    final double row;
    final hasLineBreak = raw.contains('\n');
    // 保守字宽 ≈ fontSize（中文接近；拉丁偏宽估 → 略高估行数，安全）。
    final estimatedTextWidth = raw.length * textBodyFontSize;
    if (!hasLineBreak && estimatedTextWidth <= contentMaxWidth) {
      // 单行：跳过 TextPainter.layout，避免进聊 seed 时 UI↔字形线程 QoS 倒置。
      const textHeight = textBodyFontSize * textBodyLineHeight;
      row = (textHeight + textBubbleVerticalChrome + textRowChromeHeight)
          .clamp(defaultRowHeight, 1200.0)
          .toDouble();
    } else if (!hasLineBreak) {
      final lines = math.max(
        1,
        (estimatedTextWidth / contentMaxWidth).ceil(),
      );
      final textHeight = lines * textBodyFontSize * textBodyLineHeight;
      row = (textHeight + textBubbleVerticalChrome + textRowChromeHeight)
          .clamp(defaultRowHeight, 1200.0)
          .toDouble();
    } else {
      final style = MessageBubbleTextColor.messageBodyBaseStyle(
        fontSize: textBodyFontSize,
        lineHeight: textBodyLineHeight,
      ).copyWith(
        fontWeight: null,
        fontVariations: const [
          FontVariation(
            'wght',
            MessageBubbleTextColor.messageBodyFontVariationWeight,
          ),
        ],
      );
      final painter = TextPainter(
        text: TextSpan(text: raw, style: style),
        textDirection: ui.TextDirection.ltr,
        maxLines: null,
      )..layout(maxWidth: contentMaxWidth);
      final textHeight = painter.height;
      row = (textHeight + textBubbleVerticalChrome + textRowChromeHeight)
          .clamp(defaultRowHeight, 1200.0)
          .toDouble();
    }

    if (_textLayoutCache.length >= _maxTextLayoutCacheEntries) {
      _textLayoutCache.clear();
    }
    _textLayoutCache[cacheKey] = row;
    return row;
  }

  double _imagePlaceholderHeight(V2TimMessage message) {
    final rowHeight = _imageRowHeightFromKnownSourceSize(message);
    if (rowHeight != null) {
      return rowHeight;
    }
    return imageRowFallbackHeight;
  }

  double _videoPlaceholderHeight(V2TimMessage message) {
    final meta = _videoMetaSize(message);
    if (meta != null && meta.width > 0 && meta.height > 0) {
      return _rowHeightFromSourceSize(
        meta.width,
        meta.height,
        minDisplayHeight: videoRowMinHeight,
        maxHeight: kChatVideoBubbleMaxHeight,
      );
    }
    return videoRowMinHeight + imageRowChromeHeight;
  }

  double? _imageRowHeightFromKnownSourceSize(V2TimMessage message) {
    final persisted = readPersistedImageLayoutSize(message);
    if (persisted != null && persisted.width > 0 && persisted.height > 0) {
      return _rowHeightFromSourceSize(persisted.width, persisted.height);
    }
    final meta = _imageMetaSize(message);
    if (meta != null && meta.width > 0 && meta.height > 0) {
      return _rowHeightFromSourceSize(meta.width, meta.height);
    }
    return null;
  }

  double _rowHeightFromSourceSize(
    double sourceWidth,
    double sourceHeight, {
    double minDisplayHeight = 72.0,
    double maxHeight = kChatBubbleImageMaxHeight,
  }) {
    final display = resolveChatBubbleImageDisplaySize(
      maxWidth: imageDisplayMaxWidth,
      maxHeight: maxHeight,
      sourceWidth: sourceWidth,
      sourceHeight: sourceHeight,
    );
    if (display.height <= 0) {
      return imageRowFallbackHeight;
    }
    return display.height.clamp(minDisplayHeight, 360.0) + imageRowChromeHeight;
  }

  ({double width, double height})? _imageMetaSize(V2TimMessage message) {
    final list = message.imageElem?.imageList;
    if (list == null || list.isEmpty) {
      return null;
    }
    for (final img in list) {
      final w = img?.width;
      final h = img?.height;
      if (w != null && h != null && w > 0 && h > 0) {
        return (width: w.toDouble(), height: h.toDouble());
      }
    }
    return null;
  }

  ({double width, double height})? _videoMetaSize(V2TimMessage message) {
    final elem = message.videoElem;
    if (elem == null) {
      return null;
    }
    final w = elem.snapshotWidth;
    final h = elem.snapshotHeight;
    if (w != null && h != null && w > 0 && h > 0) {
      return (width: w.toDouble(), height: h.toDouble());
    }
    return null;
  }

  void clear() {
    _heights.clear();
    _measuredContentHeightByConvSignature.clear();
    _textLayoutCache.clear();
  }
}
