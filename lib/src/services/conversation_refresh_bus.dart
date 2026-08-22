import 'dart:async';

import 'package:flutter/foundation.dart';

class ConversationRefreshBus {
  ConversationRefreshBus._();

  static final ConversationRefreshBus instance = ConversationRefreshBus._();

  final ValueNotifier<int> revision = ValueNotifier<int>(0);
  Timer? _debounce;
  DateTime? _holdUntil;
  DateTime? _lastEmitAt;
  String? _lastReason;
  String? _lastConversationId;

  String? get lastReason => _lastReason;

  String? get lastConversationId => _lastConversationId;

  static const Duration _debounceDuration = Duration(milliseconds: 500);
  static const Duration _minInterval = Duration(milliseconds: 900);

  void hold({Duration? duration, Duration? delay, String? reason}) {
    final holdDuration = duration ?? delay;
    if (holdDuration == null || holdDuration <= Duration.zero) return;

    final until = DateTime.now().add(holdDuration);
    final current = _holdUntil;
    if (current == null || until.isAfter(current)) {
      _holdUntil = until;
    }
  }

  void requestRefresh({
    String? reason,
    String? conversationId,
    Duration? debounce,
    Duration? delay,
  }) {
    _lastReason = reason;
    // 省略 conversationId 时保留上一笔，避免 tip 等定向刷新被后续无 id 事件冲掉。
    final nextConversationId = conversationId?.trim() ?? '';
    if (nextConversationId.isNotEmpty) {
      _lastConversationId = nextConversationId;
    }
    _debounce?.cancel();
    final now = DateTime.now();
    final holdUntil = _holdUntil;
    var wait = debounce ?? delay ?? _debounceDuration;

    if (holdUntil != null && holdUntil.isAfter(now)) {
      final holdDelay = holdUntil.difference(now);
      if (holdDelay > wait) wait = holdDelay;
    }

    final immediate = reason == 'new_message' &&
        (debounce == Duration.zero || delay == Duration.zero);
    if (immediate) {
      _debounce?.cancel();
      _emit();
      return;
    }

    final last = _lastEmitAt;
    if (last != null) {
      final sinceLast = now.difference(last);
      if (sinceLast < _minInterval) {
        final intervalDelay = _minInterval - sinceLast;
        if (intervalDelay > wait) wait = intervalDelay;
      }
    }

    _debounce = Timer(wait, _emit);
  }

  void _emit() {
    _debounce = null;
    _lastEmitAt = DateTime.now();
    revision.value++;
  }

  void dispose() {
    _debounce?.cancel();
    revision.dispose();
  }

  @visibleForTesting
  void resetForTest() {
    _debounce?.cancel();
    _debounce = null;
    _holdUntil = null;
    _lastEmitAt = null;
    _lastReason = null;
    _lastConversationId = null;
  }
}
