import 'conversation_perf_flags.dart';

/// Structured pending SDK synchronization request.
///
/// `conversationTypes == null` means all supported types. A non-null set keeps
/// C2C and Group requests independently, so concurrent typed requests cannot
/// overwrite each other through a single reason string.
class ConversationPendingSdkSync {
  const ConversationPendingSdkSync({
    required this.reason,
    required this.reset,
    required this.force,
    required this.loadAllPages,
    required this.reloadUiEachPage,
    required this.conversationTypes,
    this.drainMode,
  });

  final String reason;
  final bool reset;
  final bool force;
  final bool loadAllPages;
  final bool reloadUiEachPage;
  final Set<int>? conversationTypes;
  final ConversationSdkDrainMode? drainMode;

  bool get requestsAllTypes => conversationTypes == null;

  ConversationPendingSdkSync mergePreferStronger(
    ConversationPendingSdkSync other,
  ) {
    final preferOther = other.reset ||
        other.force ||
        other.loadAllPages ||
        other.drainMode == ConversationSdkDrainMode.foregroundLimited ||
        other.reason.contains('sync_server_finish');
    final mergedMode = _strongerDrainMode(drainMode, other.drainMode);
    final mergedTypes =
        conversationTypes == null || other.conversationTypes == null
            ? null
            : <int>{...conversationTypes!, ...other.conversationTypes!};
    return ConversationPendingSdkSync(
      reason: preferOther ? other.reason : reason,
      reset: reset || other.reset,
      force: force || other.force,
      loadAllPages: loadAllPages || other.loadAllPages,
      reloadUiEachPage: reloadUiEachPage && other.reloadUiEachPage,
      conversationTypes: mergedTypes,
      drainMode: mergedMode,
    );
  }

  static ConversationSdkDrainMode? _strongerDrainMode(
    ConversationSdkDrainMode? a,
    ConversationSdkDrainMode? b,
  ) {
    if (a == null) {
      return b;
    }
    if (b == null) {
      return a;
    }
    int rank(ConversationSdkDrainMode mode) {
      return switch (mode) {
        ConversationSdkDrainMode.singlePage => 1,
        ConversationSdkDrainMode.foregroundLimited => 2,
        ConversationSdkDrainMode.backgroundContinue => 3,
      };
    }

    return rank(a) >= rank(b) ? a : b;
  }
}
