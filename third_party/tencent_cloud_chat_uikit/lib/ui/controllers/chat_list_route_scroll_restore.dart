import 'package:tencent_cloud_chat_uikit/business_logic/view_models/tui_chat_global_model.dart';

/// Route / media-preview scroll restore + short-history alignment latches.
class ChatListRouteScrollRestore {
  /// 短历史顶对齐总闸：true = 消息从列表顶部开始展示，底部留白；
  /// false = 不足一页也贴底（底部对齐，顶部留白）。
  /// 仅影响不足一页的普通历史窗口；长历史和定位态仍按各自滚动策略处理。
  static const bool shortHistoryTopAlignmentEnabled = false;

  static const shortHistoryMessageEstimatedRowHeight = 55.0;
  static const shortHistoryGroupTipsEstimatedRowHeight = 80.0;
  static const shortHistoryTimeDividerEstimatedRowHeight = 36.0;
  static const shortHistoryAlignmentHysteresis = 48.0;
  static const shortHistorySpacerRebuildTolerancePx = 20.0;

  int lastRouteRestoreVersion = 0;
  int routeRestoreAttempt = 0;
  bool routeRestoreScheduled = false;
  bool wasInitialHistoryBootstrapping = true;
  bool openedWithCachedHistory = false;
  TUIChatGlobalModel? routeRestoreGlobalModel;

  double shortHistoryBottomSpacerHeight = 0;
  double shortHistoryContentHeight = -1;
  /// 一旦实测写入 contentH，estimate 不得再抬高/覆盖（B2）。
  bool shortHistoryContentHeightMeasured = false;
  bool shortHistoryAlignmentMeasureScheduled = false;
  bool shortViewportHistoryFillScheduled = false;
  bool shortHistoryAlignmentLatched = false;
  bool shortHistoryAlignmentSuppressedByLiveInsert = false;
  double shortHistoryBaselineViewportHeight = -1;
  bool shortHistoryKeyboardWasActive = false;
  bool shortHistoryKeyboardJustDismissed = false;
  double shortHistoryLastTrackedViewportHeight = -1;

  void clearShortHistoryAlignmentLatch() {
    shortHistoryAlignmentLatched = false;
    shortHistoryBaselineViewportHeight = -1;
    shortHistoryBottomSpacerHeight = 0;
    shortHistoryContentHeight = -1;
    shortHistoryContentHeightMeasured = false;
    shortHistoryAlignmentMeasureScheduled = false;
    shortHistoryLastTrackedViewportHeight = -1;
  }

  void bindGlobalModel(
    TUIChatGlobalModel? next, {
    required void Function() onUpdated,
    void Function(TUIChatGlobalModel?)? removeListener,
    void Function(TUIChatGlobalModel?)? addListener,
  }) {
    if (identical(routeRestoreGlobalModel, next)) {
      return;
    }
    removeListener?.call(routeRestoreGlobalModel);
    routeRestoreGlobalModel = next;
    addListener?.call(routeRestoreGlobalModel);
  }
}
