import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:tencent_cloud_chat_sdk/models/v2_tim_message.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_message.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/chat_message_preview_image_resolver.dart';
import 'package:visibility_detector/visibility_detector.dart';

/// 列表气泡只用 THUMB。大图/原图在进入全屏预览后由 resolver 加载，不在列表预取。
class ChatImageOriginalPrefetch {
  ChatImageOriginalPrefetch._();

  static const double visibilityThreshold = 0.08;

  static bool isOriginalReady(V2TimMessage message) {
    return ChatMessagePreviewImageResolver.hasLocalPreviewImage(message);
  }

  static void onVisibilityChanged(
    V2TimMessage _,
    VisibilityInfo __,
  ) {
    // 视口可见不再预下原图/大图，避免列表把 720/原图解进缓存。
  }

  static void schedule(V2TimMessage _) {
    // 保留调用点；真正拉大图发生在全屏 resolve / refreshOriginal。
  }

  @visibleForTesting
  static void resetForTest() {}
}
