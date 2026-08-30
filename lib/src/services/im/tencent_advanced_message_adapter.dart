import 'dart:async';
import 'dart:collection';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:tencent_cloud_chat_demo/src/services/im/contracts/contracts.dart';
import 'package:tencent_cloud_chat_demo/src/services/im/durable_ingress_gateway.dart';
import 'package:tencent_cloud_chat_demo/src/services/im/im_ingress_store.dart';
import 'package:tencent_cloud_chat_demo/src/services/im/message_withdraw_ledger.dart';
import 'package:tencent_cloud_chat_demo/src/utils/message_conversation_id.dart';
import 'package:tencent_cloud_chat_sdk/enum/V2TimAdvancedMsgListener.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_message.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_message.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_message_download_progress.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_message_download_progress.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_message_receipt.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_message_receipt.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_user_full_info.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_user_full_info.dart';
import 'package:tencent_cloud_chat_uikit/data_services/message/message_services.dart';

typedef ImAdvancedEventSink = FutureOr<void> Function(
  EventEnvelope<dynamic> event,
);

typedef ImAdvancedIngestFailureSink = void Function(
  ImIngressDraft<dynamic> draft,
  Object error,
  StackTrace stackTrace, {
  required int attempt,
  required bool dropped,
});

class _FailedIngressDraft {
  const _FailedIngressDraft({
    required this.draft,
    required this.error,
    required this.stackTrace,
    required this.attempt,
    required this.nextAttemptAtMs,
  });

  final ImIngressDraft<dynamic> draft;
  final Object error;
  final StackTrace stackTrace;
  final int attempt;
  final int nextAttemptAtMs;
}

class ImMessageRevokedEvent {
  const ImMessageRevokedEvent({
    required this.msgID,
    this.isAdmin = false,
    this.revoker,
  });

  final String msgID;
  final bool isAdmin;
  final V2TimUserFullInfo? revoker;
}

class ImMessageProgressEvent {
  const ImMessageProgressEvent({required this.message, required this.progress});

  final V2TimMessage message;
  final int progress;
}

class ImMessageDownloadProgressEvent {
  const ImMessageDownloadProgressEvent(this.progress);

  final V2TimMessageDownloadProgress progress;
}

/// Adapter event source for ordinary chat. Call signaling deliberately does
/// not use this class and remains in its own SDK listener namespace.
class TencentAdvancedMessageAdapter {
  TencentAdvancedMessageAdapter({
    required this.messageService,
    required this.ingress,
    required this.ownerUserId,
    required this.accountGeneration,
    required this.domainGeneration,
    required this.onEvent,
    this.onIngestFailure,
  });

  final MessageService messageService;
  final DurableIngressGateway ingress;
  final String ownerUserId;
  final int accountGeneration;
  final int domainGeneration;
  final ImAdvancedEventSink onEvent;
  final ImAdvancedIngestFailureSink? onIngestFailure;

  V2TimAdvancedMsgListener? _listener;
  Future<void>? _registerInFlight;
  bool _registered = false;
  static const int _failedIngressCap = 512;
  static const int _failedIngressBatchSize = 32;
  static const int _failedIngressAttemptLimit = 10;
  final LinkedHashMap<String, _FailedIngressDraft> _failedIngress =
      LinkedHashMap<String, _FailedIngressDraft>();
  Timer? _failedIngressRetryTimer;
  bool _failedIngressDrainActive = false;
  int _ingestFailureCount = 0;
  int _ingestDroppedCount = 0;

  bool get isRegistered => _registered;

  int get ingestFailureCount => _ingestFailureCount;

  int get ingestDroppedCount => _ingestDroppedCount;

  int get pendingFailedIngressCount => _failedIngress.length;

  Future<void> register() async {
    final pending = _registerInFlight;
    if (pending != null) {
      await pending;
      return;
    }
    if (_registered) return;
    final listener = _createListener();
    final task = () async {
      await messageService.addAdvancedMsgListener(listener: listener);
      if (identical(_listener, listener)) {
        _registered = true;
      } else {
        await messageService.removeAdvancedMsgListener(listener: listener);
      }
    }();
    _registerInFlight = task;
    try {
      await task;
    } finally {
      if (identical(_registerInFlight, task)) {
        _registerInFlight = null;
      }
    }
  }

  Future<void> unregister() async {
    final pending = _registerInFlight;
    if (pending != null) {
      try {
        await pending;
      } catch (_) {}
    }
    final listener = _listener;
    _listener = null;
    _registered = false;
    _failedIngressRetryTimer?.cancel();
    _failedIngressRetryTimer = null;
    _failedIngress.clear();
    if (listener == null) return;
    await messageService.removeAdvancedMsgListener(listener: listener);
  }

  V2TimAdvancedMsgListener _createListener() {
    final listener = V2TimAdvancedMsgListener(
      onRecvNewMessage: (message) {
        _submitMessage(
          eventId: _messageEventId('received', message),
          kind: ImEventKind.realtimeMessage,
          scope: _scopeForMessage(message),
          payload: message,
          recoveryMode: ImRecoveryMode.sdkOverlapReplay,
          recoveryRef: _messageRecoveryRef(message),
        );
      },
      onRecvMessageModified: (message) {
        final digest = _payloadDigest(message);
        _submitMessage(
          eventId: 'modified:${message.msgID?.trim() ?? ''}:$digest',
          kind: ImEventKind.messageMutation,
          scope: _scopeForMessage(message),
          payload: message,
          payloadHash: digest,
          recoveryMode: ImRecoveryMode.sdkOverlapReplay,
          recoveryRef: _messageRecoveryRef(message),
        );
      },
      onRecvMessageRevoked: (msgID) {
        _submitRevoked(msgID);
      },
      onRecvMessageRevokedWithInfo: (msgID, operateUser, reason) {
        _submitRevoked(
          msgID,
          isAdmin: _isAdminRevokeReason(reason),
          revoker: operateUser,
        );
      },
      onRecvC2CReadReceipt: (receipts) {
        for (final receipt in receipts) {
          _submitReceipt(receipt, prefix: 'c2c-read');
        }
      },
      onRecvMessageReadReceipts: (receipts) {
        for (final receipt in receipts) {
          _submitReceipt(receipt, prefix: 'message-read');
        }
      },
      onSendMessageProgress: (message, progress) {
        _submitAccountEvent(
          eventId: 'send-progress:${message.id ?? message.msgID}:$progress',
          kind: ImEventKind.notification,
          payload: ImMessageProgressEvent(
            message: message,
            progress: progress,
          ),
          payloadHash: '$progress:${_messageRecoveryRef(message)}',
          recoveryMode: ImRecoveryMode.ephemeralUi,
          recoveryRef: 'send-progress:${message.id ?? message.msgID}',
        );
      },
      onMessageDownloadProgressCallback: (progress) {
        _submitAccountEvent(
          eventId:
              'download-progress:${progress.msgID}:${progress.currentSize}:${progress.isFinish}:${progress.errorCode}',
          kind: ImEventKind.notification,
          payload: ImMessageDownloadProgressEvent(progress),
          payloadHash: _payloadDigest(progress),
          recoveryMode: ImRecoveryMode.ephemeralUi,
          recoveryRef: 'download-progress:${progress.msgID}',
        );
      },
      onRecvMessageExtensionsChanged: (msgID, extensions) {
        _submitAccountEvent(
          eventId: 'extension-changed:$msgID:${_payloadDigest(extensions)}',
          kind: ImEventKind.notification,
          payload: extensions,
          recoveryMode: ImRecoveryMode.commandArguments,
          recoveryRef: 'message-extension:$msgID',
        );
      },
      onRecvMessageExtensionsDeleted: (msgID, extensionKeys) {
        _submitAccountEvent(
          eventId: 'extension-deleted:$msgID:${_payloadDigest(extensionKeys)}',
          kind: ImEventKind.notification,
          payload: extensionKeys,
          recoveryMode: ImRecoveryMode.commandArguments,
          recoveryRef: 'message-extension:$msgID',
        );
      },
      onRecvMessageReactionsChanged: (changeInfos) {
        _submitAccountEvent(
          eventId: 'reactions:${_payloadDigest(changeInfos)}',
          kind: ImEventKind.notification,
          payload: changeInfos,
          recoveryMode: ImRecoveryMode.commandArguments,
          recoveryRef: 'message-reactions',
        );
      },
      onGroupMessagePinned: (groupID, message, isPinned, _) {
        final scope = AccountScopedConversationKey(
          ownerUserId: ownerUserId,
          conversationType: ImConversationType.group,
          conversationId: groupID,
        );
        _submitMessage(
          eventId:
              'group-pinned:$groupID:${message.msgID}:$isPinned:${_payloadDigest(message)}',
          kind: ImEventKind.messageMutation,
          scope: scope,
          payload: message,
          recoveryMode: ImRecoveryMode.commandArguments,
          recoveryRef: 'group-pinned:$groupID:${message.msgID}',
        );
      },
    );
    _listener = listener;
    return listener;
  }

  void _submitMessage({
    required String eventId,
    required ImEventKind kind,
    required AccountScopedConversationKey? scope,
    required V2TimMessage payload,
    String? payloadHash,
    required ImRecoveryMode recoveryMode,
    required String recoveryRef,
  }) {
    if (scope == null) {
      _submitAccountEvent(
        eventId: eventId,
        kind: ImEventKind.notification,
        payload: payload,
        payloadHash: payloadHash ?? _payloadDigest(payload),
        recoveryMode: recoveryMode,
        recoveryRef: recoveryRef,
      );
      return;
    }
    _submit(
      ImIngressDraft<V2TimMessage>(
        eventId: eventId,
        eventNamespace: 'chat',
        kind: kind,
        scope: scope,
        ownerUserId: ownerUserId,
        accountGeneration: accountGeneration,
        domainGeneration: domainGeneration,
        clearEpoch: 0,
        source: ImEventSource.sdkListener,
        authority: ImEventAuthority.provider,
        observedAtMs: DateTime.now().millisecondsSinceEpoch,
        payloadHash: payloadHash ?? _payloadDigest(payload),
        recoveryMode: recoveryMode,
        recoveryRef: recoveryRef,
        payload: payload,
      ),
    );
  }

  void _submitReceipt(
    V2TimMessageReceipt receipt, {
    required String prefix,
  }) {
    final scope = _scopeForReceipt(receipt);
    final msgID = receipt.msgID?.trim() ?? '';
    final identity =
        '${receipt.groupID ?? receipt.userID}:$msgID:${receipt.timestamp}';
    _submitAccountEvent(
      eventId: '$prefix:$identity',
      kind: scope == null ? ImEventKind.notification : ImEventKind.readReceipt,
      scope: scope,
      payload: receipt,
      payloadHash: _payloadDigest(receipt),
      recoveryMode: ImRecoveryMode.commandArguments,
      recoveryRef: 'receipt:$identity',
    );
  }

  void _submitRevoked(
    String msgID, {
    bool isAdmin = false,
    V2TimUserFullInfo? revoker,
  }) {
    final normalized = msgID.trim();
    if (normalized.isEmpty) return;
    _submitAccountEvent(
      // The SDK can deliver both revoke callbacks for the same message. The
      // message identity, not the callback shape, is the Inbox idempotency key.
      eventId: 'revoked:$normalized',
      kind: ImEventKind.notification,
      payload: ImMessageRevokedEvent(
        msgID: normalized,
        isAdmin: isAdmin,
        revoker: revoker,
      ),
      payloadHash: normalized,
      recoveryMode: ImRecoveryMode.commandArguments,
      recoveryRef: 'revoke:$normalized',
    );
    // IM-08 P0-High B2: 每条撤回事件持久化到本地账本,
    // 防止 SDK listener 回调丢失导致冷启动 UI 残留原消息。
    // IM-08 P0-High B2: 持久化撤回事件,带 isAdmin + revokerID
    // 让 SDK 重启后 UI 仍能恢复"谁撤回"信息。
    final revokerID = revoker?.userID?.trim();
    unawaited(MessageWithdrawLedger.instance.recordRevokedWithInfo(
      msgID: normalized,
      isAdmin: isAdmin,
      revokerID: (revokerID == null || revokerID.isEmpty) ? null : revokerID,
    ));
  }

  void _submitAccountEvent({
    required String eventId,
    required ImEventKind kind,
    required Object? payload,
    required ImRecoveryMode recoveryMode,
    required String recoveryRef,
    AccountScopedConversationKey? scope,
    String? payloadHash,
  }) {
    _submit(
      ImIngressDraft<Object?>(
        eventId: eventId,
        eventNamespace: 'chat',
        kind: kind,
        scope: scope,
        ownerUserId: ownerUserId,
        accountGeneration: accountGeneration,
        domainGeneration: domainGeneration,
        clearEpoch: 0,
        source: ImEventSource.sdkListener,
        authority: ImEventAuthority.provider,
        observedAtMs: DateTime.now().millisecondsSinceEpoch,
        payloadHash: payloadHash ?? _payloadDigest(payload),
        recoveryMode: recoveryMode,
        recoveryRef: recoveryRef,
        payload: payload,
      ),
    );
  }

  void _submit<T>(ImIngressDraft<T> draft) {
    unawaited(_attemptSubmit(draft, attempt: 0));
  }

  Future<void> _attemptSubmit<T>(
    ImIngressDraft<T> draft, {
    required int attempt,
  }) async {
    try {
      final result = await ingress.append(draft);
      await onEvent(result.event);
      _failedIngress.remove(_failedIngressKey(draft));
    } catch (error, stackTrace) {
      _retainFailedIngress(
        draft,
        error: error,
        stackTrace: stackTrace,
        attempt: attempt + 1,
      );
    }
  }

  void _retainFailedIngress(
    ImIngressDraft<dynamic> draft, {
    required Object error,
    required StackTrace stackTrace,
    required int attempt,
  }) {
    _ingestFailureCount++;
    final terminal = attempt >= _failedIngressAttemptLimit;
    _reportIngestFailure(
      draft,
      error,
      stackTrace,
      attempt: attempt,
      dropped: terminal,
    );
    if (terminal || _listener == null) {
      if (terminal) _ingestDroppedCount++;
      return;
    }

    final key = _failedIngressKey(draft);
    _failedIngress.remove(key);
    if (_failedIngress.length >= _failedIngressCap) {
      final evictedKey = _evictionCandidateKey();
      final evicted = _failedIngress.remove(evictedKey);
      if (evicted != null) {
        _ingestDroppedCount++;
        _reportIngestFailure(
          evicted.draft,
          evicted.error,
          evicted.stackTrace,
          attempt: evicted.attempt,
          dropped: true,
        );
      }
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    _failedIngress[key] = _FailedIngressDraft(
      draft: draft,
      error: error,
      stackTrace: stackTrace,
      attempt: attempt,
      nextAttemptAtMs: now + _retryBackoffMs(attempt),
    );
    _scheduleFailedIngressDrain();
  }

  String _evictionCandidateKey() {
    for (final entry in _failedIngress.entries) {
      if (entry.value.draft.recoveryMode != ImRecoveryMode.commandArguments) {
        return entry.key;
      }
    }
    return _failedIngress.keys.first;
  }

  void _scheduleFailedIngressDrain() {
    if (_listener == null ||
        _failedIngress.isEmpty ||
        _failedIngressDrainActive) {
      return;
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    var earliest = _failedIngress.values.first.nextAttemptAtMs;
    for (final pending in _failedIngress.values.skip(1)) {
      if (pending.nextAttemptAtMs < earliest) {
        earliest = pending.nextAttemptAtMs;
      }
    }
    final waitMs = earliest > now ? earliest - now : 0;
    _failedIngressRetryTimer?.cancel();
    _failedIngressRetryTimer = Timer(
      Duration(milliseconds: waitMs),
      () => unawaited(_drainFailedIngress()),
    );
  }

  Future<void> _drainFailedIngress() async {
    if (_listener == null || _failedIngressDrainActive) return;
    _failedIngressDrainActive = true;
    _failedIngressRetryTimer = null;
    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      final due = _failedIngress.entries
          .where((entry) => entry.value.nextAttemptAtMs <= now)
          .take(_failedIngressBatchSize)
          .toList(growable: false);
      for (final entry in due) {
        if (_listener == null) return;
        final current = _failedIngress[entry.key];
        if (!identical(current, entry.value)) continue;
        _failedIngress.remove(entry.key);
        await _attemptSubmit(
          entry.value.draft,
          attempt: entry.value.attempt,
        );
      }
    } finally {
      _failedIngressDrainActive = false;
      _scheduleFailedIngressDrain();
    }
  }

  void _reportIngestFailure(
    ImIngressDraft<dynamic> draft,
    Object error,
    StackTrace stackTrace, {
    required int attempt,
    required bool dropped,
  }) {
    debugPrint(
      'CHAT_INGRESS_FAILURE kind=${draft.kind.name} '
      'event=${_shortHash(draft.eventId)} attempt=$attempt dropped=$dropped '
      'errorType=${error.runtimeType}',
    );
    try {
      onIngestFailure?.call(
        draft,
        error,
        stackTrace,
        attempt: attempt,
        dropped: dropped,
      );
    } catch (callbackError) {
      debugPrint(
        'CHAT_INGRESS_FAILURE '
        'callbackErrorType=${callbackError.runtimeType}',
      );
    }
  }

  String _failedIngressKey(ImIngressDraft<dynamic> draft) =>
      '${draft.ownerUserId}|${draft.eventNamespace}|${draft.eventId}';

  int _retryBackoffMs(int attempt) {
    final exponent = attempt > 6 ? 6 : attempt;
    return (1 << exponent) * 250;
  }

  AccountScopedConversationKey? _scopeForMessage(V2TimMessage message) {
    final conversation = MessageConversationId.fromMessage(
      message,
      loginUserId: ownerUserId,
    );
    if (conversation == null) return null;
    final type = conversation.startsWith('group_')
        ? ImConversationType.group
        : ImConversationType.c2c;
    return AccountScopedConversationKey.tryParse(
      ownerUserId: ownerUserId,
      conversationType: type,
      conversationId: conversation,
    );
  }

  AccountScopedConversationKey? _scopeForReceipt(V2TimMessageReceipt receipt) {
    final group = receipt.groupID?.trim() ?? '';
    if (group.isNotEmpty) {
      return AccountScopedConversationKey.tryParse(
        ownerUserId: ownerUserId,
        conversationType: ImConversationType.group,
        conversationId: group,
      );
    }
    final user = receipt.userID.trim();
    if (user.isEmpty) return null;
    return AccountScopedConversationKey.tryParse(
      ownerUserId: ownerUserId,
      conversationType: ImConversationType.c2c,
      conversationId: user,
    );
  }

  String _messageEventId(String prefix, V2TimMessage message) {
    final id = message.msgID?.trim() ?? '';
    if (id.isNotEmpty) return '$prefix:$id';
    return '$prefix:${_payloadDigest(message)}';
  }

  String _messageRecoveryRef(V2TimMessage message) {
    final id = message.msgID?.trim() ?? '';
    return id.isEmpty ? 'sdk-message:${_payloadDigest(message)}' : 'msgID:$id';
  }
}

String _payloadDigest(Object? value) {
  Object? normalized = value;
  if (value is V2TimMessage) {
    normalized = value.toJson();
  } else if (value is V2TimMessageReceipt) {
    normalized = value.toJson();
  } else if (value is Iterable) {
    normalized = value.map(_payloadDigest).toList(growable: false);
  } else if (value is ImMessageRevokedEvent) {
    normalized = <String, Object?>{
      'msgID': value.msgID,
      'isAdmin': value.isAdmin,
      'revoker': value.revoker?.userID,
    };
  } else if (value is ImMessageProgressEvent) {
    normalized = <String, Object?>{
      'message': value.message.msgID ?? value.message.id,
      'progress': value.progress,
    };
  } else if (value is ImMessageDownloadProgressEvent) {
    normalized = value.progress.toJson();
  }
  return sha256.convert(utf8.encode(jsonEncode(normalized))).toString();
}

bool _isAdminRevokeReason(String reason) {
  final normalized = reason.trim().toLowerCase();
  if (normalized.isEmpty) return false;
  return normalized.contains('admin') || normalized.contains('groupowner');
}

String _shortHash(String value) =>
    sha256.convert(utf8.encode(value)).toString().substring(0, 12);
