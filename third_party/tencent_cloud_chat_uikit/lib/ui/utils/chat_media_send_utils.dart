import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:fc_native_video_thumbnail/fc_native_video_thumbnail.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_message.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_message.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_image.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_image.dart';
import 'package:tencent_cloud_chat_uikit/tencent_cloud_chat_uikit.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/platform.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/screen_shot.dart';

const String kChatImageLayoutWidthKey = 'chatImageLayoutW';
const String kChatImageLayoutHeightKey = 'chatImageLayoutH';
const String kChatOutgoingStableIdKey = 'chatOutgoingStableId';
const String kChatMediaBatchIdKey = 'chatMediaBatchId';
const String kChatMediaBatchIndexKey = 'chatMediaBatchIndex';
const String kChatImageSourcePendingKey = 'chatImageSourcePending';
const String kChatImageDecodeStaggerKey = 'chatImageDecodeStagger';

int _lastChatMediaUniqueValue = 0;

/// 单 isolate 内严格递增的媒体临时身份。
///
/// DateTime 在部分设备上的实际分辨率低于微秒；批量并发发送若直接使用
/// microsecondsSinceEpoch，可能让多个 optimistic 行或压缩文件共享同一 key。
String nextChatMediaUniqueToken() {
  final now = DateTime.now().microsecondsSinceEpoch;
  _lastChatMediaUniqueValue =
      now > _lastChatMediaUniqueValue ? now : _lastChatMediaUniqueValue + 1;
  return _lastChatMediaUniqueValue.toString();
}

/// 聊天图片发送：普通图最长边上限（像素）。
const int kChatImageMaxLongEdge = 3072;

/// 超长竖图（海报/规则长图）最长边上限；需保留足够宽度供文字阅读。
const int kChatImageUltraTallMaxLongEdge = 8192;

/// 宽高比低于此值视为超长竖图（宽/高）。
const double kChatImageUltraTallAspectRatio = 0.45;

/// 超长竖图发送时尽量保留的宽度下限（不放大，只防止被「压长边」压成 ~200px 宽）。
const int kChatImageUltraTallPreserveMinWidth = 1280;

/// 聊天图片发送：JPEG 质量（0–100）。文字图适当提高，减轻块效应。
const int kChatImageJpegQuality = 94;

/// 已是较小 JPEG 且无需重编码时跳过压缩（字节）。
const int kChatImageSkipCompressBelowBytes = 1200 * 1024;

/// 聊天气泡解码像素上限（逻辑像素 × DPR 后 clamp）。
/// 1920 ≈ 640pt@3x，覆盖气泡长边并留一点过采样，全屏预览前气泡也不易发糊。
const int kChatBubbleImageDecodeMaxPx = 1920;

/// 列表滑动中、且只能落到 LARGE 时的解码上限（IM 大图短边约 720）。
/// 气泡默认应走 THUMB（短边约 198），不要把 720 当成列表档。
const int kChatBubbleImageDecodeScrollDeferMaxPx = 720;

/// IM 气泡网络图档优先级（SDK type：0 原图 / 1 缩略图 / 2 大图）。
/// 列表只用 THUMB；LARGE / ORIGINAL 留给点击预览。
const List<int> kChatBubbleImageSdkTypePriority = [1, 2, 0];

bool isChatBubbleSdkThumbType(int? type) => type == 1;

bool _chatBubbleImageHasSize(V2TimImage? image) {
  final width = image?.width;
  final height = image?.height;
  return image != null &&
      width != null &&
      height != null &&
      width > 0 &&
      height > 0;
}

/// 返回与气泡当前实际渲染资源对应的 SDK 图片元数据。
///
/// 同一条图片消息通常同时带原图、大图和缩略图，它们的宽高比不一定相同。
/// 布局必须跟随当前选中的 URL/本地文件，否则 [BoxFit.contain] 会在气泡内
/// 留出明显空白，时间水印也会看起来像单独挂在一块灰色区域上。
V2TimImage? resolveChatBubbleRenderedImageMeta({
  required Iterable<V2TimImage?> images,
  String? networkUrl,
  String? localPath,
}) {
  final normalizedNetwork = networkUrl?.trim() ?? '';
  final normalizedLocal = localPath?.trim() ?? '';
  if (normalizedNetwork.isEmpty && normalizedLocal.isEmpty) {
    return null;
  }
  if (normalizedNetwork.isNotEmpty) {
    for (final image in images) {
      if (!_chatBubbleImageHasSize(image)) {
        continue;
      }
      if (image!.url?.trim() == normalizedNetwork) {
        return image;
      }
    }
  }
  if (normalizedLocal.isNotEmpty) {
    for (final image in images) {
      if (!_chatBubbleImageHasSize(image)) {
        continue;
      }
      if (image!.localUrl?.trim() == normalizedLocal) {
        return image;
      }
    }
  }
  return null;
}

V2TimImage? _chatBubbleImageOfSdkType(
  Iterable<V2TimImage?> images,
  int type,
) {
  for (final image in images) {
    if (image?.type == type && _chatBubbleImageHasSize(image)) {
      return image;
    }
  }
  return null;
}

/// 布局用宽高：原图(0) > 大图(2) > 缩略图(1)。
///
/// 与 IM SDK `V2TIM_IMAGE_TYPE` 对齐。原图尺寸常为 0，此时必须用大图，
/// 不能误用缩略图（部分通道会给出近方形 width/height）。
V2TimImage? preferChatBubbleImageLayoutMeta(Iterable<V2TimImage?> images) {
  return _chatBubbleImageOfSdkType(images, 0) ??
      _chatBubbleImageOfSdkType(images, 2) ??
      _chatBubbleImageOfSdkType(images, 1);
}

/// 普通图片气泡最大高度（逻辑像素）。
const double kChatBubbleImageMaxHeight = 230;

/// 手机 / 桌面图片气泡最大宽度（逻辑像素）。
const double kChatBubbleImageMaxWidthMobile = 200;
const double kChatBubbleImageMaxWidthDesktop = 260;

/// 相对消息行可用宽的图片宽度系数。
const double kChatBubbleImageWidthFactorMobile = 0.54;
const double kChatBubbleImageWidthFactorDesktop = 0.34;

/// 当前屏幕下图片气泡的布局上限（逻辑像素）。
class ChatBubbleImageLayoutLimits {
  const ChatBubbleImageLayoutLimits({
    required this.maxWidth,
    required this.maxHeight,
    required this.widthFactor,
  });

  final double maxWidth;
  final double maxHeight;
  final double widthFactor;
}

/// 根据屏幕逻辑尺寸选择聊天图片气泡档位。
///
/// 手机档位控制最大高度，使连续三条最大图片消息在常见聊天视口中仍有空间
/// 容纳昵称、时间和输入栏；平板/桌面沿用既有较大展示规格。
ChatBubbleImageLayoutLimits resolveChatBubbleImageLayoutLimits({
  required double screenWidth,
  required double screenHeight,
  required bool isDesktop,
}) {
  if (isDesktop || screenWidth >= 600) {
    return const ChatBubbleImageLayoutLimits(
      maxWidth: kChatBubbleImageMaxWidthDesktop,
      maxHeight: kChatBubbleImageMaxHeight,
      widthFactor: kChatBubbleImageWidthFactorDesktop,
    );
  }

  if (screenWidth < 360 || screenHeight < 700) {
    return const ChatBubbleImageLayoutLimits(
      maxWidth: 132,
      maxHeight: 150,
      widthFactor: kChatBubbleImageWidthFactorMobile,
    );
  }

  if (screenHeight < 840) {
    return const ChatBubbleImageLayoutLimits(
      maxWidth: 144,
      maxHeight: 160,
      widthFactor: kChatBubbleImageWidthFactorMobile,
    );
  }

  return const ChatBubbleImageLayoutLimits(
    maxWidth: 156,
    maxHeight: 176,
    widthFactor: kChatBubbleImageWidthFactorMobile,
  );
}

/// 宽/高低于此值视为超长竖图，与发送侧 [kChatImageUltraTallAspectRatio] 对齐。
///
/// 仅用 1/3 会漏掉 IM 压到 1024 高的排行榜（如 383×1024 ≈ 1:2.67），
/// 整图被 contain 塞进 230 高气泡后变成细长糊条。
const double kChatBubbleLongImageAspectRatio = kChatImageUltraTallAspectRatio;

/// 超长图气泡固定裁切框（逻辑像素）。
const double kChatBubbleLongImageCropBoxWidth = 92;
const double kChatBubbleLongImageCropBoxHeight = 190;

/// 将原图像素尺寸约束到聊天气泡显示框。
///
/// 普通图一次性等比缩进 maxWidth × maxHeight，气泡比例等于原图。
/// 超长竖图：使用 92×190 裁切框，[BoxFit.cover] 顶对齐只显示顶部一段。
Size resolveChatBubbleImageDisplaySize({
  required double maxWidth,
  required double maxHeight,
  required double sourceWidth,
  required double sourceHeight,
}) {
  if (maxWidth <= 0 ||
      maxHeight <= 0 ||
      sourceWidth <= 0 ||
      sourceHeight <= 0) {
    return Size.zero;
  }

  final scaleW = maxWidth / sourceWidth;
  final scaleH = maxHeight / sourceHeight;
  final scale = scaleW < scaleH ? scaleW : scaleH;
  final fittedWidth = sourceWidth * scale;
  final fittedHeight = sourceHeight * scale;

  if (shouldUseChatBubbleLongImageCropBox(
    sourceWidth: sourceWidth,
    sourceHeight: sourceHeight,
    fittedWidth: fittedWidth,
    fittedHeight: fittedHeight,
    maxHeight: maxHeight,
  )) {
    final clampedWidth = kChatBubbleLongImageCropBoxWidth < maxWidth
        ? kChatBubbleLongImageCropBoxWidth
        : maxWidth;
    final clampedHeight = kChatBubbleLongImageCropBoxHeight < maxHeight
        ? kChatBubbleLongImageCropBoxHeight
        : maxHeight;
    return Size(clampedWidth, clampedHeight);
  }

  return Size(fittedWidth, fittedHeight);
}

/// 竖图且宽/高低于 [kChatBubbleLongImageAspectRatio] 时裁切顶部。
bool isChatBubbleLongImage({
  required double sourceWidth,
  required double sourceHeight,
}) {
  if (sourceWidth <= 0 || sourceHeight <= 0) {
    return false;
  }
  if (sourceHeight <= sourceWidth) {
    return false;
  }
  return sourceWidth / sourceHeight < kChatBubbleLongImageAspectRatio;
}

/// contain 进气泡后会变成「顶满高度的细长条」时，改用裁切框，避免整图被压糊。
bool shouldUseChatBubbleLongImageCropBox({
  required double sourceWidth,
  required double sourceHeight,
  required double fittedWidth,
  required double fittedHeight,
  required double maxHeight,
}) {
  if (isChatBubbleLongImage(
    sourceWidth: sourceWidth,
    sourceHeight: sourceHeight,
  )) {
    return true;
  }
  if (sourceHeight <= sourceWidth) {
    return false;
  }
  final hitHeightCap = fittedHeight >= maxHeight - 0.5;
  return hitHeightCap && fittedWidth < kChatBubbleLongImageCropBoxWidth;
}

/// 当前气泡显示尺寸是否为超长图裁切框（cover 必须跟这个走，不能再 contain）。
bool isChatBubbleLongImageCropDisplay(
  Size displaySize, {
  required double maxWidth,
  required double maxHeight,
}) {
  if (displaySize.width <= 0 || displaySize.height <= 0) {
    return false;
  }
  final cropW = kChatBubbleLongImageCropBoxWidth < maxWidth
      ? kChatBubbleLongImageCropBoxWidth
      : maxWidth;
  final cropH = kChatBubbleLongImageCropBoxHeight < maxHeight
      ? kChatBubbleLongImageCropBoxHeight
      : maxHeight;
  return (displaySize.width - cropW).abs() < 0.51 &&
      (displaySize.height - cropH).abs() < 0.51;
}

/// 气泡单轴解码像素：展示逻辑尺寸 × DPR，并 clamp 到 [min, max]。
int resolveChatBubbleImageDecodeSide(
  double logicalSide,
  double devicePixelRatio, {
  int min = 64,
  int max = kChatBubbleImageDecodeMaxPx,
}) {
  if (!logicalSide.isFinite || logicalSide <= 0) {
    return min;
  }
  return (logicalSide * devicePixelRatio).round().clamp(min, max);
}

/// 列表滑动/松手短窗内使用更低解码上限。
int resolveChatBubbleImageDecodeSideForChatList(
  double logicalSide,
  double devicePixelRatio, {
  required bool deferHeavyDecode,
}) {
  return resolveChatBubbleImageDecodeSide(
    logicalSide,
    devicePixelRatio,
    max: deferHeavyDecode
        ? kChatBubbleImageDecodeScrollDeferMaxPx
        : kChatBubbleImageDecodeMaxPx,
  );
}

/// 气泡解码目标：只约束较长边，避免 width+height 同时指定触发 exact 拉伸。
class ChatBubbleImageDecodeTarget {
  const ChatBubbleImageDecodeTarget({this.width, this.height});

  final int? width;
  final int? height;
}

ChatBubbleImageDecodeTarget resolveChatBubbleImageDecodeTarget({
  required double displayWidth,
  required double displayHeight,
  required double devicePixelRatio,
  required bool deferHeavyDecode,
  bool coverCropTallImage = false,
}) {
  // 顶对齐 cover 时按宽度解码，让原图高度按比例变长，再裁掉下半段。
  // 若按气泡高度解码，整张长图会被压进框里，预览又全又糊。
  if (coverCropTallImage) {
    return ChatBubbleImageDecodeTarget(
      width: resolveChatBubbleImageDecodeSideForChatList(
        displayWidth,
        devicePixelRatio,
        deferHeavyDecode: deferHeavyDecode,
      ),
    );
  }
  if (displayWidth >= displayHeight) {
    return ChatBubbleImageDecodeTarget(
      width: resolveChatBubbleImageDecodeSideForChatList(
        displayWidth,
        devicePixelRatio,
        deferHeavyDecode: deferHeavyDecode,
      ),
    );
  }
  return ChatBubbleImageDecodeTarget(
    height: resolveChatBubbleImageDecodeSideForChatList(
      displayHeight,
      devicePixelRatio,
      deferHeavyDecode: deferHeavyDecode,
    ),
  );
}

/// 聊天气泡视频封面最大逻辑宽度（与 [TIMUIKitVideoElem] 约束同量级）。
const double kChatVideoBubbleMaxLogicalWidth = 180.0;

/// 相对消息行可用宽的视频宽度系数（Web 用固定上限）。
const double kChatVideoBubbleWidthFactor = 0.41;
const double kChatVideoBubbleMaxWidthWeb = 250;

/// 竖屏视频气泡最大逻辑高度（与图片档位独立，保持原比例）。
const double kChatVideoBubbleMaxHeight = 250;

/// 视频发送前抽帧最短边像素下限。
const int kChatVideoSnapshotMinPx = 480;

/// 视频发送前抽帧最短边像素上限。
const int kChatVideoSnapshotMaxPx = 720;

/// 视频封面 JPEG 质量（0–100）。
const int kChatVideoSnapshotJpegQuality = 90;

/// 视为有效封面文件的最小字节数（排除 1×1 占位图）。
const int kChatVideoSnapshotMinFileBytes = 256;

/// 按气泡最大宽 × DPR 估算发送前抽帧像素尺寸。
int chatVideoSnapshotPixelSize({double devicePixelRatio = 3.0}) {
  return (kChatVideoBubbleMaxLogicalWidth * devicePixelRatio)
      .round()
      .clamp(kChatVideoSnapshotMinPx, kChatVideoSnapshotMaxPx);
}

/// 聊天气泡内视频封面解码宽度（与发送抽帧对齐）。
int chatVideoBubbleSnapshotDecodeWidth({required double devicePixelRatio}) {
  return chatVideoSnapshotPixelSize(devicePixelRatio: devicePixelRatio);
}

bool isUsableVideoSnapshotFile(String path) {
  try {
    final file = File(path.trim());
    return file.existsSync() &&
        file.lengthSync() >= kChatVideoSnapshotMinFileBytes;
  } catch (_) {
    return false;
  }
}

/// 从本地视频生成发送用封面（带重试，失败返回 null，不写 1×1 占位图）。
Future<String?> buildVideoSnapshotForSend({
  required String videoPath,
  double? devicePixelRatio,
  int maxAttempts = 3,
}) async {
  if (PlatformUtils().isWeb) {
    return null;
  }
  final src = videoPath.trim();
  if (src.isEmpty || !File(src).existsSync()) {
    return null;
  }
  final pixelSize = chatVideoSnapshotPixelSize(
    devicePixelRatio: devicePixelRatio ??
        WidgetsBinding.instance.platformDispatcher.views.first.devicePixelRatio,
  );
  final plugin = FcNativeVideoThumbnail();
  final tempDir = await getTemporaryDirectory();
  Object? lastError;
  for (var attempt = 0; attempt < maxAttempts; attempt++) {
    try {
      final dest =
          '${tempDir.path}/chat_video_snap_${nextChatMediaUniqueToken()}_$attempt.jpeg';
      await plugin.saveThumbnailToFile(
        srcFile: src,
        destFile: dest,
        width: pixelSize,
        height: pixelSize,
        quality: kChatVideoSnapshotJpegQuality,
      );
      if (isUsableVideoSnapshotFile(dest)) {
        return dest;
      }
    } catch (e) {
      lastError = e;
    }
    if (attempt < maxAttempts - 1) {
      await Future<void>.delayed(Duration(milliseconds: 140 * (attempt + 1)));
    }
  }
  if (lastError != null && kDebugMode) {
    debugPrint('[ChatVideoSnapshot] build failed path=$src err=$lastError');
  }
  return null;
}

bool isPreparedChatImageSendPath(String path) {
  final normalized = path.replaceAll('\\', '/');
  return normalized.contains('/chat_send_') && normalized.endsWith('.jpg');
}

bool isStagedChatImageSendPath(String path) {
  final normalized = path.replaceAll('\\', '/');
  return normalized.contains('/chat_stage_');
}

bool isStagedChatVideoSendPath(String path) {
  final normalized = path.replaceAll('\\', '/');
  return normalized.contains('/chat_video_stage_');
}

bool _isEphemeralMediaPath(String path) {
  final normalized = path.replaceAll('\\', '/').toLowerCase();
  return normalized.contains('image_picker') ||
      normalized.contains('/tmp/') ||
      normalized.contains('photospicker') ||
      normalized.contains('/cache/image_picker');
}

/// 是否需要在后台压缩（小 JPEG / GIF / 已压缩文件返回 false）。
bool needsChatImageBackgroundCompression(String sourcePath) {
  if (PlatformUtils().isWeb) {
    return false;
  }
  final trimmed = sourcePath.trim();
  if (trimmed.isEmpty) {
    return false;
  }
  if (isPreparedChatImageSendPath(trimmed)) {
    return false;
  }
  final ext = _imageExtension(trimmed);
  if (ext == 'gif') {
    return false;
  }
  try {
    final size = File(trimmed).lengthSync();
    final isJpeg = ext == 'jpg' || ext == 'jpeg';
    if (isJpeg && size <= kChatImageSkipCompressBelowBytes) {
      return false;
    }
  } catch (_) {}
  return true;
}

String? _imageExtension(String path) {
  final name = path.replaceAll('\\', '/').split('/').last;
  final dot = name.lastIndexOf('.');
  if (dot <= 0 || dot >= name.length - 1) {
    return null;
  }
  return name.substring(dot + 1).toLowerCase();
}

/// 相机/临时文件发送前：快速复制到稳定路径（不压缩），避免 picker 临时文件被回收。
Future<String?> stageImageForChatSend(String sourcePath) async {
  if (PlatformUtils().isWeb) {
    return TencentUtils.checkString(sourcePath);
  }
  final trimmed = sourcePath.trim();
  if (trimmed.isEmpty) {
    return null;
  }
  if (isPreparedChatImageSendPath(trimmed) ||
      isStagedChatImageSendPath(trimmed)) {
    return File(trimmed).existsSync() ? trimmed : null;
  }
  final source = File(trimmed);
  if (!source.existsSync()) {
    return null;
  }
  if (!_isEphemeralMediaPath(trimmed)) {
    return trimmed;
  }

  final ext = _imageExtension(trimmed);
  final suffix = ext == 'png'
      ? '.png'
      : ext == 'gif'
          ? '.gif'
          : '.jpg';
  final tempDir = await getTemporaryDirectory();
  final targetPath =
      '${tempDir.path}/chat_stage_${nextChatMediaUniqueToken()}$suffix';
  try {
    await source.copy(targetPath);
    if (File(targetPath).existsSync()) {
      return targetPath;
    }
  } catch (_) {}
  return trimmed;
}

/// 系统相册返回的媒体通常位于临时目录。视频发送是异步的，先复制到本应用的
/// 稳定临时路径，避免选择器清理文件后 SDK 上传读不到源文件。
Future<String?> stageVideoForChatSend(String sourcePath) async {
  if (PlatformUtils().isWeb) {
    return TencentUtils.checkString(sourcePath);
  }
  final trimmed = sourcePath.trim();
  if (trimmed.isEmpty) {
    return null;
  }
  final source = File(trimmed);
  if (!source.existsSync()) {
    return null;
  }
  if (isStagedChatVideoSendPath(trimmed) || !_isEphemeralMediaPath(trimmed)) {
    return trimmed;
  }

  final ext = _imageExtension(trimmed);
  final suffix = ext == null ? '.mp4' : '.$ext';
  final tempDir = await getTemporaryDirectory();
  final targetPath =
      '${tempDir.path}/chat_video_stage_${nextChatMediaUniqueToken()}$suffix';
  try {
    await source.copy(targetPath);
    if (File(targetPath).existsSync()) {
      return targetPath;
    }
  } catch (_) {}
  return trimmed;
}

/// 计算发送前压缩目标像素尺寸（可单测）。
///
/// 普通图：限制最长边 [kChatImageMaxLongEdge]。
/// 超长竖图：优先保留可读宽度，避免 1080×8000 被压成 ~200×1600 导致文字糊掉。
({int width, int height}) resolveChatImageSendTargetSize({
  required double sourceWidth,
  required double sourceHeight,
}) {
  int clampSide(double value) => value.round().clamp(1, 1 << 20);

  if (sourceWidth <= 0 || sourceHeight <= 0) {
    return (width: kChatImageMaxLongEdge, height: kChatImageMaxLongEdge);
  }

  final aspect = sourceWidth / sourceHeight;
  if (aspect < kChatImageUltraTallAspectRatio) {
    var targetWidth = sourceWidth;
    var targetHeight = sourceHeight;

    if (sourceWidth >= kChatImageUltraTallPreserveMinWidth) {
      targetWidth = kChatImageUltraTallPreserveMinWidth.toDouble();
      targetHeight = sourceHeight * targetWidth / sourceWidth;
    }

    final longEdge = targetWidth > targetHeight ? targetWidth : targetHeight;
    if (longEdge > kChatImageUltraTallMaxLongEdge) {
      final scale = kChatImageUltraTallMaxLongEdge / longEdge;
      targetWidth *= scale;
      targetHeight *= scale;
    }

    return (
      width: clampSide(targetWidth),
      height: clampSide(targetHeight),
    );
  }

  final longEdge = sourceWidth > sourceHeight ? sourceWidth : sourceHeight;
  final scale =
      longEdge > kChatImageMaxLongEdge ? kChatImageMaxLongEdge / longEdge : 1.0;
  return (
    width: clampSide(sourceWidth * scale),
    height: clampSide(sourceHeight * scale),
  );
}

/// 聊天图片发送前：复制到稳定临时路径、校正方向并统一为 JPEG，提升上传与缩略图清晰度。
Future<String?> prepareImageForChatSend(String sourcePath) async {
  if (PlatformUtils().isWeb) {
    return TencentUtils.checkString(sourcePath);
  }
  final trimmed = sourcePath.trim();
  if (trimmed.isEmpty) {
    return null;
  }
  if (isPreparedChatImageSendPath(trimmed)) {
    final prepared = File(trimmed);
    if (prepared.existsSync()) {
      return trimmed;
    }
  }

  final source = File(trimmed);
  if (!source.existsSync()) {
    return null;
  }

  final ext = _imageExtension(trimmed);
  if (ext == 'gif') {
    return trimmed;
  }

  try {
    final originSize = await source.length();
    final isJpeg = ext == 'jpg' || ext == 'jpeg';
    if (isJpeg && originSize <= kChatImageSkipCompressBelowBytes) {
      return trimmed;
    }
  } catch (_) {}

  final tempDir = await getTemporaryDirectory();
  final targetPath =
      '${tempDir.path}/chat_send_${nextChatMediaUniqueToken()}.jpg';

  // flutter_image_compress 的 minWidth/minHeight 是目标尺寸提示；先按比例
  // 计算目标框。超长竖图单独保宽度，普通图限制最长边。
  var targetWidth = kChatImageMaxLongEdge;
  var targetHeight = kChatImageMaxLongEdge;
  final sourceSize = await probeLocalImageSize(trimmed);
  if (sourceSize != null && sourceSize.width > 0 && sourceSize.height > 0) {
    final target = resolveChatImageSendTargetSize(
      sourceWidth: sourceSize.width,
      sourceHeight: sourceSize.height,
    );
    targetWidth = target.width;
    targetHeight = target.height;
  }

  // 统一校正 EXIF 方向并写入像素（keepExif: false），避免 SDK 读到与显示不一致的宽高。
  try {
    final result = await FlutterImageCompress.compressAndGetFile(
      source.absolute.path,
      targetPath,
      minWidth: targetWidth,
      minHeight: targetHeight,
      quality: kChatImageJpegQuality,
      format: CompressFormat.jpeg,
      keepExif: false,
      autoCorrectionAngle: true,
    );
    final outPath = result?.path.trim() ?? '';
    if (outPath.isNotEmpty && File(outPath).existsSync()) {
      return outPath;
    }
  } catch (_) {}

  try {
    await source.copy(targetPath);
    if (File(targetPath).existsSync()) {
      return targetPath;
    }
  } catch (_) {}

  return null;
}

/// 相机拍摄图发送前：快速复制到稳定路径（压缩在 sendImageMessage 后台进行）。
Future<String?> prepareCameraImageForChatSend(String sourcePath) async {
  return stageImageForChatSend(sourcePath);
}

Size? readPersistedImageLayoutSize(V2TimMessage? message) {
  final raw = TencentUtils.checkString(message?.localCustomData);
  if (raw == null || raw.isEmpty) {
    return null;
  }
  try {
    final decoded = jsonDecode(raw);
    if (decoded is! Map) {
      return null;
    }
    final width = _layoutNumToDouble(decoded[kChatImageLayoutWidthKey]);
    final height = _layoutNumToDouble(decoded[kChatImageLayoutHeightKey]);
    if (width == null || height == null || width <= 0 || height <= 0) {
      return null;
    }
    return Size(width, height);
  } catch (_) {
    return null;
  }
}

String? readOutgoingStableId(V2TimMessage? message) {
  final raw = TencentUtils.checkString(message?.localCustomData);
  if (raw == null || raw.isEmpty) {
    return null;
  }
  try {
    final decoded = jsonDecode(raw);
    if (decoded is! Map) {
      return null;
    }
    return TencentUtils.checkString(
        decoded[kChatOutgoingStableIdKey]?.toString());
  } catch (_) {
    return null;
  }
}

String? readChatMediaBatchId(V2TimMessage? message) {
  final raw = TencentUtils.checkString(message?.localCustomData);
  if (raw == null || raw.isEmpty) return null;
  try {
    final decoded = jsonDecode(raw);
    if (decoded is! Map) return null;
    return TencentUtils.checkString(decoded[kChatMediaBatchIdKey]?.toString());
  } catch (_) {
    return null;
  }
}

int? readChatMediaBatchIndex(V2TimMessage? message) {
  final raw = TencentUtils.checkString(message?.localCustomData);
  if (raw == null || raw.isEmpty) return null;
  try {
    final decoded = jsonDecode(raw);
    if (decoded is! Map) return null;
    final value = decoded[kChatMediaBatchIndexKey];
    return value is num ? value.toInt() : int.tryParse(value?.toString() ?? "");
  } catch (_) {
    return null;
  }
}

double? _layoutNumToDouble(Object? value) {
  if (value is num) {
    return value.toDouble();
  }
  if (value is String) {
    return double.tryParse(value);
  }
  return null;
}

String mergeImageLayoutIntoLocalCustomData(String? existing, Size size) {
  Map<String, dynamic> map;
  final raw = TencentUtils.checkString(existing);
  if (raw != null && raw.isNotEmpty) {
    try {
      final decoded = jsonDecode(raw);
      map = decoded is Map
          ? Map<String, dynamic>.from(decoded)
          : <String, dynamic>{};
    } catch (_) {
      map = <String, dynamic>{};
    }
  } else {
    map = <String, dynamic>{};
  }
  map[kChatImageLayoutWidthKey] = size.width.round();
  map[kChatImageLayoutHeightKey] = size.height.round();
  return jsonEncode(map);
}

void applyImageLayoutToMessage(V2TimMessage message, Size size) {
  message.localCustomData = mergeImageLayoutIntoLocalCustomData(
    message.localCustomData,
    size,
  );
}

void applyOutgoingStableIdToMessage(
  V2TimMessage message,
  String stableId,
) {
  final id = stableId.trim();
  if (id.isEmpty) {
    return;
  }
  Map<String, dynamic> map;
  final raw = TencentUtils.checkString(message.localCustomData);
  if (raw != null && raw.isNotEmpty) {
    try {
      final decoded = jsonDecode(raw);
      map = decoded is Map
          ? Map<String, dynamic>.from(decoded)
          : <String, dynamic>{};
    } catch (_) {
      map = <String, dynamic>{};
    }
  } else {
    map = <String, dynamic>{};
  }
  map[kChatOutgoingStableIdKey] = id;
  message.localCustomData = jsonEncode(map);
}

void applyChatMediaBatchToMessage(V2TimMessage message, {required String batchId, required int batchIndex}) {
  final id = batchId.trim();
  if (id.isEmpty || batchIndex < 0) return;
  Map<String, dynamic> map = <String, dynamic>{};
  final raw = TencentUtils.checkString(message.localCustomData);
  if (raw != null && raw.isNotEmpty) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) map = Map<String, dynamic>.from(decoded);
    } catch (_) {}
  }
  map[kChatMediaBatchIdKey] = id;
  map[kChatMediaBatchIndexKey] = batchIndex;
  message.localCustomData = jsonEncode(map);
}

bool isImageSourcePending(V2TimMessage? message) {
  final raw = TencentUtils.checkString(message?.localCustomData);
  if (raw == null || raw.isEmpty) {
    return false;
  }
  try {
    final decoded = jsonDecode(raw);
    return decoded is Map && decoded[kChatImageSourcePendingKey] == true;
  } catch (_) {
    return false;
  }
}

bool shouldStaggerImageDecode(V2TimMessage? message) {
  final raw = TencentUtils.checkString(message?.localCustomData);
  if (raw == null || raw.isEmpty) {
    return false;
  }
  try {
    final decoded = jsonDecode(raw);
    return decoded is Map && decoded[kChatImageDecodeStaggerKey] == true;
  } catch (_) {
    return false;
  }
}

void setImageSourcePending(V2TimMessage message, bool pending) {
  Map<String, dynamic> map;
  final raw = TencentUtils.checkString(message.localCustomData);
  if (raw != null && raw.isNotEmpty) {
    try {
      final decoded = jsonDecode(raw);
      map = decoded is Map
          ? Map<String, dynamic>.from(decoded)
          : <String, dynamic>{};
    } catch (_) {
      map = <String, dynamic>{};
    }
  } else {
    map = <String, dynamic>{};
  }
  if (pending) {
    map[kChatImageSourcePendingKey] = true;
  } else {
    map.remove(kChatImageSourcePendingKey);
  }
  message.localCustomData = jsonEncode(map);
}

void setImageDecodeStagger(V2TimMessage message, bool enabled) {
  Map<String, dynamic> map;
  final raw = TencentUtils.checkString(message.localCustomData);
  if (raw != null && raw.isNotEmpty) {
    try {
      final decoded = jsonDecode(raw);
      map = decoded is Map
          ? Map<String, dynamic>.from(decoded)
          : <String, dynamic>{};
    } catch (_) {
      map = <String, dynamic>{};
    }
  } else {
    map = <String, dynamic>{};
  }
  if (enabled) {
    map[kChatImageDecodeStaggerKey] = true;
  } else {
    map.remove(kChatImageDecodeStaggerKey);
  }
  message.localCustomData = jsonEncode(map);
}

/// 同步读取本地图片显示尺寸（JPEG/PNG 头 + EXIF 方向），冷启动首帧可用。
Size? readLocalImageSizeSync(String sourcePath) {
  if (PlatformUtils().isWeb) {
    return null;
  }
  final trimmed = sourcePath.trim();
  if (trimmed.isEmpty) {
    return null;
  }
  final file = File(trimmed);
  if (!file.existsSync()) {
    return null;
  }
  try {
    final totalLength = file.lengthSync();
    if (totalLength <= 0) {
      return null;
    }
    final readLength = totalLength < 262144 ? totalLength : 262144;
    final raf = file.openSync();
    try {
      final bytes = raf.readSync(readLength);
      if (bytes.isEmpty) {
        return null;
      }
      final ext = _imageExtension(trimmed);
      if (ext == 'png') {
        return _readPngDisplaySize(bytes);
      }
      return _readJpegDisplaySize(bytes);
    } finally {
      raf.closeSync();
    }
  } catch (_) {
    return null;
  }
}

Size? _readPngDisplaySize(Uint8List bytes) {
  if (bytes.length < 24 ||
      bytes[0] != 0x89 ||
      bytes[1] != 0x50 ||
      bytes[2] != 0x4E ||
      bytes[3] != 0x47) {
    return null;
  }
  final width =
      (bytes[16] << 24) | (bytes[17] << 16) | (bytes[18] << 8) | bytes[19];
  final height =
      (bytes[20] << 24) | (bytes[21] << 16) | (bytes[22] << 8) | bytes[23];
  if (width <= 0 || height <= 0) {
    return null;
  }
  return Size(width.toDouble(), height.toDouble());
}

Size? _readJpegDisplaySize(Uint8List bytes) {
  if (bytes.length < 4 || bytes[0] != 0xFF || bytes[1] != 0xD8) {
    return null;
  }
  int? width;
  int? height;
  int? orientation;
  var offset = 2;
  while (offset + 4 < bytes.length) {
    if (bytes[offset] != 0xFF) {
      offset++;
      continue;
    }
    final marker = bytes[offset + 1];
    if (marker == 0xD9) {
      break;
    }
    final segmentLength = (bytes[offset + 2] << 8) | bytes[offset + 3];
    if (segmentLength < 2 || offset + 2 + segmentLength > bytes.length) {
      break;
    }
    if (marker >= 0xC0 && marker <= 0xC3 && segmentLength >= 7) {
      height = (bytes[offset + 5] << 8) | bytes[offset + 6];
      width = (bytes[offset + 7] << 8) | bytes[offset + 8];
    } else if (marker == 0xE1 && segmentLength > 10) {
      final exifStart = offset + 4;
      if (exifStart + 6 <= bytes.length) {
        final header =
            String.fromCharCodes(bytes.sublist(exifStart, exifStart + 6));
        if (header == 'Exif\u0000\u0000') {
          orientation = _readExifOrientation(bytes, exifStart + 6);
        }
      }
    }
    offset += 2 + segmentLength;
  }
  if (width == null || height == null || width <= 0 || height <= 0) {
    return null;
  }
  if (orientation == 5 ||
      orientation == 6 ||
      orientation == 7 ||
      orientation == 8) {
    final swapped = width;
    width = height;
    height = swapped;
  }
  return Size(width.toDouble(), height.toDouble());
}

int? _readExifOrientation(Uint8List bytes, int start) {
  if (start + 8 >= bytes.length) {
    return null;
  }
  final byteOrder = bytes[start] == 0x49 && bytes[start + 1] == 0x49
      ? Endian.little
      : Endian.big;
  int readUint16(int offset) {
    if (offset + 1 >= bytes.length) {
      return 0;
    }
    if (byteOrder == Endian.little) {
      return bytes[offset] | (bytes[offset + 1] << 8);
    }
    return (bytes[offset] << 8) | bytes[offset + 1];
  }

  int readUint32(int offset) {
    if (offset + 3 >= bytes.length) {
      return 0;
    }
    if (byteOrder == Endian.little) {
      return bytes[offset] |
          (bytes[offset + 1] << 8) |
          (bytes[offset + 2] << 16) |
          (bytes[offset + 3] << 24);
    }
    return (bytes[offset] << 24) |
        (bytes[offset + 1] << 16) |
        (bytes[offset + 2] << 8) |
        bytes[offset + 3];
  }

  final ifdOffset = start + readUint32(start + 4);
  if (ifdOffset + 2 >= bytes.length) {
    return null;
  }
  final entryCount = readUint16(ifdOffset);
  var entryOffset = ifdOffset + 2;
  for (var i = 0; i < entryCount; i++) {
    if (entryOffset + 12 > bytes.length) {
      break;
    }
    final tag = readUint16(entryOffset);
    if (tag == 0x0112) {
      final value = readUint16(entryOffset + 8);
      return value == 0 ? 1 : value;
    }
    entryOffset += 12;
  }
  return null;
}

/// 优先读文件头取尺寸，失败再完整解码（发送路径用，避免 readAsBytes 阻塞）。
Future<Size?> probeLocalImageSize(String sourcePath) async {
  final sync = readLocalImageSizeSync(sourcePath);
  if (sync != null) {
    return sync;
  }
  return readLocalImageSize(sourcePath);
}

/// 读取本地图片宽高（含 EXIF 方向校正），供发送前确定气泡尺寸。
Future<Size?> readLocalImageSize(String sourcePath) async {
  if (PlatformUtils().isWeb) {
    return null;
  }
  final trimmed = sourcePath.trim();
  if (trimmed.isEmpty) {
    return null;
  }
  final file = File(trimmed);
  if (!file.existsSync()) {
    return null;
  }
  try {
    final size = await ScreenshotHelper.getImageSize(trimmed).timeout(
      const Duration(seconds: 3),
    );
    if (size.width <= 0 || size.height <= 0) {
      return null;
    }
    return size;
  } catch (_) {
    return null;
  }
}

/// 视频发送前确保封面路径可用（与相册发送逻辑一致）。
Future<String?> ensureVideoSnapshotForSend({
  String? videoPath,
  String? snapshotPath,
  double? devicePixelRatio,
}) async {
  final existing = TencentUtils.checkString(snapshotPath);
  if (PlatformUtils().isWeb) {
    return existing;
  }
  if (existing != null && isUsableVideoSnapshotFile(existing)) {
    return existing;
  }
  final path = TencentUtils.checkString(videoPath);
  if (path == null) {
    return null;
  }
  return buildVideoSnapshotForSend(
    videoPath: path,
    devicePixelRatio: devicePixelRatio,
  );
}
