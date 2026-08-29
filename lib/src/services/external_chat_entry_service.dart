import 'dart:convert';

import 'package:tencent_cloud_chat_demo/config.dart';
import 'package:tencent_cloud_chat_demo/src/services/active_chat_registry.dart';
import 'package:tencent_cloud_chat_demo/src/services/chat_history_refresh_bus.dart';
import 'package:tencent_cloud_chat_demo/src/services/contact_social_cache_store.dart';
import 'package:tencent_cloud_chat_demo/src/utils/message_conversation_id.dart';

class ExternalChatEntryService {
  ExternalChatEntryService._();

  static final ExternalChatEntryService instance = ExternalChatEntryService._();

  _ActiveChatSnapshot? _activeChat;
  String? _lastStateSignature;
  int? _activeSourceToken;

  void _syncRegistry({
    required String conversationID,
    required bool isRouteVisible,
    required bool hasVisibleMessages,
  }) {
    ActiveChatRegistry.instance.enter(
      conversationID,
      routeVisible: isRouteVisible,
    );
    ActiveChatRegistry.instance.updateRouteVisible(isRouteVisible);
    ActiveChatRegistry.instance.updateHasVisibleMessages(hasVisibleMessages);
  }

  /// Claims the active publisher for a mounted chat page. Delayed callbacks
  /// from older pages are ignored once another page claims this token.
  void claimActiveChatSource(int sourceToken) {
    _activeSourceToken = sourceToken;
  }

  String? resolveConversationId({
    String? conversationID,
    String? groupID,
    String? userID,
    String? sender,
    String? loginUserId,
  }) {
    return MessageConversationId.resolve(
      conversationID: conversationID,
      groupID: groupID,
      userID: userID,
      sender: sender,
      loginUserId: loginUserId ?? ContactSocialCacheStore.safeLoginUserId(),
    );
  }

  String? conversationIdFromExt(String? ext) {
    final raw = ext?.trim() ?? '';
    if (raw.isEmpty) {
      return null;
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        return null;
      }
      final conversationID = decoded['conversationID']?.toString().trim() ?? '';
      if (conversationID.isNotEmpty) {
        return conversationID;
      }

      final threadId = (decoded['threadId'] ?? decoded['thread_id'])
              ?.toString()
              .trim() ??
          '';
      if (threadId.startsWith('c2c_') || threadId.startsWith('group_')) {
        return threadId;
      }

      final type = decoded['type']?.toString().trim().toLowerCase() ?? '';
      final chatType = (decoded['chatType'] ?? decoded['chat_type'])
              ?.toString()
              .trim()
              .toLowerCase() ??
          '';
      if (type == 'register_welcome') {
        return 'c2c_99Messenger';
      }
      if (type == 'platform_wallet_notice') {
        final official = IMDemoConfig.platformOfficialAccountId.trim();
        return official.isNotEmpty ? 'c2c_$official' : null;
      }
      if (type == 'im_chat' || chatType.isNotEmpty) {
        if (chatType == 'group') {
          final groupId = (decoded['groupId'] ??
                  decoded['groupID'] ??
                  decoded['group_id'])
              ?.toString()
              .trim() ??
              '';
          if (groupId.isNotEmpty) {
            return 'group_$groupId';
          }
        }
        final userId = (decoded['fromAccount'] ??
                decoded['from_account'] ??
                decoded['sender'] ??
                decoded['userID'] ??
                decoded['userId'])
            ?.toString()
            .trim() ??
            '';
        if (userId.isNotEmpty) {
          return 'c2c_$userId';
        }
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  void updateActiveChatState({
    required String conversationID,
    required bool isRouteVisible,
    required bool hasVisibleMessages,
    int? sourceToken,
  }) {
    final id = conversationID.trim();
    if (id.isEmpty) {
      return;
    }
    if (_activeSourceToken != null &&
        sourceToken != null &&
        _activeSourceToken != sourceToken) {
      return;
    }
    _activeSourceToken ??= sourceToken;
    final next = _ActiveChatSnapshot(
      conversationID: id,
      isRouteVisible: isRouteVisible,
      hasVisibleMessages: hasVisibleMessages,
    );
    final nextSignature = next.signature;
    if (_lastStateSignature == nextSignature) {
      _activeChat = next;
      _syncRegistry(
        conversationID: id,
        isRouteVisible: isRouteVisible,
        hasVisibleMessages: hasVisibleMessages,
      );
      return;
    }
    _activeChat = next;
    _lastStateSignature = nextSignature;
    _syncRegistry(
      conversationID: id,
      isRouteVisible: isRouteVisible,
      hasVisibleMessages: hasVisibleMessages,
    );
    logFlow(
      'active_chat_state',
      source: 'chat_page',
      conversationID: id,
      extras: <String, Object?>{
        'visible': isRouteVisible,
        'hasMessages': hasVisibleMessages,
      },
    );
  }

  void clearActiveChatState(String? conversationID, {int? sourceToken}) {
    final id = conversationID?.trim() ?? '';
    final current = _activeChat;
    if (id.isEmpty ||
        current == null ||
        !MessageConversationId.sameConversation(id, current.conversationID)) {
      return;
    }
    if (_activeSourceToken != null &&
        sourceToken != null &&
        _activeSourceToken != sourceToken) {
      return;
    }
    logFlow(
      'active_chat_cleared',
      source: 'chat_page',
      conversationID: id,
    );
    _activeChat = null;
    _lastStateSignature = null;
    _activeSourceToken = null;
    ActiveChatRegistry.instance.leave(id);
  }

  bool isVisibleChat(String? conversationID) {
    return ActiveChatRegistry.instance.isActiveChat(conversationID);
  }

  bool isVisibleChatReady(String? conversationID) {
    return ActiveChatRegistry.instance.isActiveChat(conversationID) &&
        ActiveChatRegistry.instance.hasVisibleMessages;
  }

  void requestActivation({
    required String conversationID,
    required String source,
    required String reason,
    Duration? delay,
  }) {
    final id = conversationID.trim();
    if (id.isEmpty) {
      return;
    }
    logFlow(
      'request_activation',
      source: source,
      conversationID: id,
      extras: <String, Object?>{
        'reason': reason,
        'delayMs': delay?.inMilliseconds ?? 0,
      },
    );
    ChatHistoryRefreshBus.instance.requestRefresh(
      conversationId: id,
      reason: '$source:$reason',
      delay: delay,
    );
  }

  /// 发布版也输出，便于排查「列表有预览、聊天页无历史」。
  static const bool _verboseLog = false;

  void logFlow(
    String event, {
    required String source,
    String? conversationID,
    Map<String, Object?> extras = const <String, Object?>{},
  }) {
    if (!_verboseLog) return;
    final buffer = StringBuffer(
      '[ExternalChatEntry] event=$event source=$source',
    );
    final id = conversationID?.trim() ?? '';
    if (id.isNotEmpty) {
      buffer.write(' conversationID=$id');
    }
    extras.forEach((key, value) {
      if (value == null) {
        return;
      }
      buffer.write(' $key=$value');
    });
    // ignore: avoid_print
    print(buffer.toString());
  }
}

class _ActiveChatSnapshot {
  const _ActiveChatSnapshot({
    required this.conversationID,
    required this.isRouteVisible,
    required this.hasVisibleMessages,
  });

  final String conversationID;
  final bool isRouteVisible;
  final bool hasVisibleMessages;

  String get signature => '$conversationID|$isRouteVisible|$hasVisibleMessages';
}
