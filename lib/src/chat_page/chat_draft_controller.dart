import 'dart:async';

/// Debounced local draft text for the open chat page.
class ChatDraftController {
  String? text;
  Timer? _debounce;
  int _writeGeneration = 0;
  int _stateRevision = 0;
  bool _sendClearBarrier = false;
  int get writeGeneration => _writeGeneration;
  bool get shouldSuppressLifecyclePersist => _sendClearBarrier;
  int get stateRevision => _stateRevision;

  static const Duration debounceDuration = Duration(milliseconds: 250);

  void setTextImmediate(String? value) {
    final trimmed = value?.trim() ?? '';
    text = trimmed.isEmpty ? null : value;
  }

  void onChanged(
    String value, {
    required void Function(String raw, int generation) persist,
  }) {
    _sendClearBarrier = false;
    _stateRevision++;
    setTextImmediate(value);
    _debounce?.cancel();
    // Programmatic controller.clear() after send does not emit TextField's
    // onChanged by itself. Once the input layer forwards it explicitly, clear
    // the persisted draft immediately so a fast route pop cannot expose stale
    // sent text in the conversation list.
    if (value.trim().isEmpty) {
      _writeGeneration++;
      persist(value, _writeGeneration);
      return;
    }
    final generation = _writeGeneration;
    _debounce = Timer(debounceDuration, () {
      if (generation == _writeGeneration) {
        persist(value, generation);
      }
    });
  }

  void cancelDebounce() {
    _debounce?.cancel();
    _debounce = null;
  }

  void clear() {
    _writeGeneration++;
    _stateRevision++;
    cancelDebounce();
    text = null;
  }

  void dispose() {
    cancelDebounce();
  }

  void markSendCompleted() {
    _sendClearBarrier = true;
    clear();
  }

  /// Invalidates work owned by the previous conversation while allowing the
  /// new conversation to start persisting immediately.
  void beginConversation() {
    _sendClearBarrier = false;
    clear();
  }

  bool canApplyLoadedDraft(int capturedRevision) =>
      !_sendClearBarrier && capturedRevision == _stateRevision;
}

/// Serializes draft mutations without allowing one failed write to poison all
/// writes scheduled after it.
class ChatDraftWriteQueue {
  Future<void> _tail = Future<void>.value();

  Future<void> enqueue(
    Future<void> Function() operation, {
    void Function(Object error, StackTrace stackTrace)? onError,
  }) {
    final next = _tail.then((_) => operation());
    _tail = next.then<void>(
      (_) {},
      onError: (Object error, StackTrace stackTrace) {
        try {
          onError?.call(error, stackTrace);
        } catch (_) {
          // Diagnostics must never become the next queue failure.
        }
      },
    );
    return _tail;
  }
}
