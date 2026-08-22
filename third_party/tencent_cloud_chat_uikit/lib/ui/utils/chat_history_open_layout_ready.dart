import 'dart:async';

import 'package:flutter/foundation.dart';

/// Bridges HistoryMessageList layout-ready → Chat page open gate.
///
/// Call [begin] when starting an open, [signal] when list geometry is ready,
/// and [wait] from the page gate Future.
class ChatHistoryOpenLayoutReady {
  ChatHistoryOpenLayoutReady._();

  static final Map<String, Completer<void>> _pending =
      <String, Completer<void>>{};
  static final Set<String> _signaled = <String>{};
  static final Map<String, int> _epoch = <String, int>{};

  /// Bumps on every [begin] so lists can invalidate stale ready state.
  static final ValueNotifier<int> epochRevision = ValueNotifier<int>(0);

  static String _key(String conversationID) => conversationID.trim();

  /// Current begin-generation for [conversationID] (0 if never begun).
  static int epochOf(String conversationID) {
    final id = _key(conversationID);
    if (id.isEmpty) {
      return 0;
    }
    return _epoch[id] ?? 0;
  }

  /// Reset for a new open / wait-phase of [conversationID]. Bumps epoch.
  static void begin(String conversationID) {
    final id = _key(conversationID);
    if (id.isEmpty) {
      return;
    }
    _signaled.remove(id);
    _epoch[id] = (_epoch[id] ?? 0) + 1;
    final existing = _pending.remove(id);
    if (existing != null && !existing.isCompleted) {
      existing.complete();
    }
    epochRevision.value++;
  }

  /// Completes waiters when geometry is ready for the current [epoch].
  /// If [epoch] is non-null and stale, the signal is ignored.
  static void signal(String conversationID, {int? epoch}) {
    final id = _key(conversationID);
    if (id.isEmpty) {
      return;
    }
    final current = _epoch[id] ?? 0;
    if (epoch != null && epoch != current) {
      return;
    }
    _signaled.add(id);
    final pending = _pending.remove(id);
    if (pending != null && !pending.isCompleted) {
      pending.complete();
    }
  }

  static void cancel(String conversationID) {
    final id = _key(conversationID);
    if (id.isEmpty) {
      return;
    }
    _signaled.remove(id);
    final pending = _pending.remove(id);
    if (pending != null && !pending.isCompleted) {
      pending.complete();
    }
  }

  /// Whether [signal] has fired for the current [begin] generation.
  /// Unlike a one-shot consume, this stays true until next [begin]/[cancel]
  /// so multiple waiters (chat gate + warm reconcile) can observe ready.
  static bool isReady(String conversationID) {
    final id = _key(conversationID);
    if (id.isEmpty) {
      return false;
    }
    return _signaled.contains(id);
  }

  /// Resolves when [signal] fires, or after [timeout].
  /// Returns `true` if layout signaled; `false` on timeout / empty id.
  ///
  /// Ready state is **not** consumed: later waiters still see [isReady].
  static Future<bool> wait(
    String conversationID, {
    Duration timeout = const Duration(milliseconds: 1000),
  }) async {
    final id = _key(conversationID);
    if (id.isEmpty) {
      return false;
    }
    if (_signaled.contains(id)) {
      return true;
    }
    final completer = _pending.putIfAbsent(id, Completer<void>.new);
    try {
      await completer.future.timeout(timeout);
      // [cancel]/[begin] complete waiters without signaling ready.
      return _signaled.contains(id);
    } on TimeoutException {
      _pending.remove(id);
      return _signaled.contains(id);
    }
  }
}
