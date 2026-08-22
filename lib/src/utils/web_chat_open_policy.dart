import 'package:flutter/foundation.dart';
import 'package:tencent_cloud_chat_demo/src/utils/conversation_preview_history_sync.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_message.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_message.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/view_models/tui_chat_global_model.dart';
import 'package:tencent_cloud_chat_uikit/ui/constants/history_message_constant.dart';

/// Web 进页性能策略：仅 [kIsWeb] 生效，移动端行为不变。
class WebChatOpenPolicy {
  WebChatOpenPolicy._();

  static bool get isActive => kIsWeb;

  /// 预载 / 并行 peek / 内存已有消息 → 不挡 1.2s 冷壳 gate。
  static bool shouldUseWarmHistoryGate({
    required TUIChatGlobalModel globalModel,
    required String convKey,
    required bool isOpenHistoryWarm,
  }) {
    if (isOpenHistoryWarm || globalModel.rawMessageCount(convKey) > 0) {
      return true;
    }
    if (!isActive) {
      return false;
    }
    if (globalModel.hasOpenHydrateInFlight(convKey)) {
      return true;
    }
    return canSkipHydrateRefetch(
      globalModel: globalModel,
      conversationKey: convKey,
      preview: null,
    );
  }

  /// bootstrap / gate 已灌窗：跳过 UIKit 或 gate 二次 peek。
  ///
  /// 短窗（<40）且仍可能有更早消息时，必须继续 refetch，避免用不完整暖窗当首屏。
  static bool canSkipHydrateRefetch({
    required TUIChatGlobalModel globalModel,
    required String conversationKey,
    V2TimMessage? preview,
  }) {
    if (!isActive) {
      return false;
    }
    if (!ConversationPreviewHistorySync.canSkipOpenRebootstrap(
      globalModel: globalModel,
      conversationKey: conversationKey,
      preview: preview,
    )) {
      return false;
    }

    final key = conversationKey.trim();
    if (key.isEmpty) {
      return false;
    }
    final warmCount = globalModel.rawMessageCount(key);
    final fetchCount = HistoryMessageDartConstant.initialOpenFetchCount;
    final mayHaveOlder = globalModel.mayHaveOlderHistory(key);
    final warmLoaded = globalModel.hasInitialHistoryLoaded(key);

    if (warmCount >= fetchCount) {
      return true;
    }
    if (warmLoaded && !mayHaveOlder) {
      return true;
    }
    return false;
  }

  /// 首屏归档与移动端一致：SDK 窗口不足时同步补拉，不 defer。
  ///
  /// 保留方法签名供调用方统一判断；Web 与移动端均返回 false。
  static bool shouldDeferInitialArchive({
    required bool isInitialWindow,
    required int sdkMessageCount,
  }) {
    return false;
  }

  /// 首屏不再后台静默补档（与移动端同步归档对齐）。
  static bool shouldScheduleSilentInitialArchive({
    required bool isInitialWindow,
    required int sdkMessageCount,
    required int requestedCount,
  }) {
    return false;
  }

  /// chat_open 延迟去重：只处理通话相关消息，避免整表 replace。
  static bool useCallOnlyOpenDedupe({required String scheduleSlot}) {
    if (!isActive) {
      return false;
    }
    return scheduleSlot == 'chat_open';
  }
}
