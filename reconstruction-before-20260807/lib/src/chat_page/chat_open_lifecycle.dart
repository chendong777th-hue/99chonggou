/// One-shot / gate flags for opening a chat conversation page.
class ChatOpenLifecycle {
  bool postOpenTasksScheduled = false;
  bool muteStatusFetchStarted = false;
  bool scheduledVisibleSdkUnreadClean = false;
  bool clearedExternalEntryOnDeactivate = false;
  Future<void>? openHistoryGate;
  String openHistoryGateConvKey = '';

  /// 递增后丢弃已 schedule 的禁言网络补证（退页 / 重进）。
  int muteFetchGeneration = 0;

  void cancelPendingMuteFetch() {
    muteFetchGeneration++;
    muteStatusFetchStarted = false;
  }

  void resetForDispose() {
    cancelPendingMuteFetch();
    postOpenTasksScheduled = false;
    scheduledVisibleSdkUnreadClean = false;
    clearedExternalEntryOnDeactivate = false;
    openHistoryGate = null;
    openHistoryGateConvKey = '';
  }
}
