import 'package:tencent_cloud_chat_uikit/business_logic/view_models/tui_chat_global_model.dart';

/// Shared policy for whether mid-history / search-jump windows may page
/// toward the live tip via [LoadDirection.latest].
///
/// Keep UI (`_shouldAttemptLatestHistoryLoad`) and model
/// (`loadChatRecord` early skip) aligned through this helper.
class SearchJumpLatestGate {
  SearchJumpLatestGate._();

  /// UI / scroll scheduler: may we attempt a latest history page?
  static bool shouldAllowLatestPagination({
    required HistoryMessagePosition position,
    required bool haveMoreLatestData,
    required bool memoryWindowMissingNewer,
  }) {
    if (memoryWindowMissingNewer) {
      return true;
    }
    switch (position) {
      case HistoryMessagePosition.bottom:
      case HistoryMessagePosition.inTwoScreen:
        return true;
      case HistoryMessagePosition.notShowLatest:
      case HistoryMessagePosition.awayTwoScreen:
        // Mid-history / around-window: only page newer while more remain.
        return haveMoreLatestData;
    }
  }

  /// Model layer: should we no-op a latest fetch because the user is
  /// reading history and there is nothing contiguous to fill?
  static bool shouldSkipLatestWhileReadingHistory({
    required bool isReadingHistory,
    required bool haveMoreLatestData,
    required bool memoryWindowMissingNewer,
    required bool forceReloadNewest,
  }) {
    if (forceReloadNewest) {
      return false;
    }
    if (!isReadingHistory) {
      return false;
    }
    if (memoryWindowMissingNewer) {
      return false;
    }
    if (haveMoreLatestData) {
      return false;
    }
    return true;
  }
}
