import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:tencent_cloud_chat_uikit/business_logic/mobile_async_commit_guard.dart';

class ConversationRefreshEvent {
  const ConversationRefreshEvent({
    required this.sequence,
    required this.reason,
    required this.conversationId,
  });

  final int sequence;
  final String? reason;
  final String? conversationId;
}

class ConversationRefreshBus {
  ConversationRefreshBus._();

  static final ConversationRefreshBus instance = ConversationRefreshBus._();

  final ValueNotifier<int> revision = ValueNotifier<int>(0);
  Timer? _debounce;
  final MobileAsyncCommitGuard _commitGuard = MobileAsyncCommitGuard();
  MobileAsyncCommitToken? _emitToken;
  DateTime? _holdUntil;
  DateTime? _lastEmitAt;
  String? _lastReason;
  String? _lastConversationId;
  int _eventSequence = 0;
  final List<ConversationRefreshEvent> _pendingEvents =
      <ConversationRefreshEvent>[];
  List<ConversationRefreshEvent> _lastEvents =
      const <ConversationRefreshEvent>[];

  String? get lastReason => _lastReason;

  String? get lastConversationId => _lastConversationId;

  List<ConversationRefreshEvent> get lastEvents => _lastEvents;

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
    _emitToken = _commitGuard.begin('conversation-refresh-batch');
    final nextConversationId = conversationId?.trim() ?? '';
    _pendingEvents.add(
      ConversationRefreshEvent(
        sequence: ++_eventSequence,
        reason: reason,
        conversationId: nextConversationId.isEmpty ? null : nextConversationId,
      ),
    );
    // Bound bursts without losing distinct semantics. Identical older entries
    // are redundant because consumers only need the latest occurrence.
    if (_pendingEvents.length > 64) {
      _pendingEvents.removeAt(0);
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
    final token = _emitToken;
    if (token == null || !_commitGuard.canCommit(token)) {
      return;
    }
    _emitToken = null;
    _lastEmitAt = DateTime.now();
    if (_pendingEvents.isEmpty) {
      return;
    }
    _lastEvents = List<ConversationRefreshEvent>.unmodifiable(_pendingEvents);
    _pendingEvents.clear();
    final last = _lastEvents.last;
    _lastReason = last.reason;
    _lastConversationId = last.conversationId;
    revision.value++;
  }

  void dispose() {
    _debounce?.cancel();
    _commitGuard.advancePage();
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
    _eventSequence = 0;
    _pendingEvents.clear();
    _lastEvents = const <ConversationRefreshEvent>[];
    _emitToken = null;
    _commitGuard.reset();
  }
}
