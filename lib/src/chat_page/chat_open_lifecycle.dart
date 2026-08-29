enum ChatOpenPhase {
  created,
  historyReady,
  interactive,
  enriched,
  disposed,
}

/// One-shot / gate flags for opening a chat conversation page.
class ChatOpenLifecycle {
  ChatOpenPhase phase = ChatOpenPhase.created;
  int conversationGeneration = 0;
  bool postOpenTasksScheduled = false;
  bool muteStatusFetchStarted = false;
  bool scheduledVisibleSdkUnreadClean = false;
  bool clearedExternalEntryOnDeactivate = false;
  Future<void>? openHistoryGate;
  // The layout gate may soft-timeout while history preparation continues.
  Future<void>? openHistoryPreparationGate;
  String openHistoryGateConvKey = '';
  int postOpenTasksGeneration = 0;

  /// 递增后丢弃已 schedule 的禁言网络补证（退页 / 重进）。
  int muteFetchGeneration = 0;

  int beginConversation() {
    cancelPendingMuteFetch();
    cancelPendingPostOpenTasks();
    phase = ChatOpenPhase.created;
    openHistoryGate = null;
    openHistoryPreparationGate = null;
    openHistoryGateConvKey = '';
    return ++conversationGeneration;
  }

  bool markHistoryReady(int generation) =>
      _advance(generation, ChatOpenPhase.created, ChatOpenPhase.historyReady);

  bool markInteractive(int generation) => _advance(
        generation,
        ChatOpenPhase.historyReady,
        ChatOpenPhase.interactive,
      );

  bool markEnriched(int generation) =>
      _advance(generation, ChatOpenPhase.interactive, ChatOpenPhase.enriched);

  bool _advance(
    int generation,
    ChatOpenPhase expected,
    ChatOpenPhase next,
  ) {
    if (generation != conversationGeneration || phase != expected) {
      return false;
    }
    phase = next;
    return true;
  }

  void cancelPendingMuteFetch() {
    muteFetchGeneration++;
    muteStatusFetchStarted = false;
  }

  int beginPostOpenTasks() {
    postOpenTasksScheduled = true;
    return ++postOpenTasksGeneration;
  }

  Future<void> waitForOpenHistoryGate() async {
    final gate = openHistoryGate;
    if (gate == null) {
      return;
    }
    try {
      await gate;
    } catch (_) {
      // Post-open tasks must still run when history preparation fails.
    }
  }

  Future<void> waitForOpenHistoryPreparationGate() async {
    final gates = <Future<void>>[
      if (openHistoryGate != null) openHistoryGate!,
      if (openHistoryPreparationGate != null) openHistoryPreparationGate!,
    ];
    await Future.wait(
      gates.map((gate) async {
        try {
          await gate;
        } catch (_) {
          // Post-open tasks must still run when either gate fails.
        }
      }),
    );
  }

  void cancelPendingPostOpenTasks() {
    postOpenTasksGeneration++;
    postOpenTasksScheduled = false;
  }

  void resetForDispose() {
    cancelPendingMuteFetch();
    cancelPendingPostOpenTasks();
    scheduledVisibleSdkUnreadClean = false;
    clearedExternalEntryOnDeactivate = false;
    openHistoryGate = null;
    openHistoryPreparationGate = null;
    openHistoryGateConvKey = '';
    conversationGeneration++;
    phase = ChatOpenPhase.disposed;
  }
}
