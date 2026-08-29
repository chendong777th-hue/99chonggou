import 'package:flutter/material.dart';
import 'package:tencent_cloud_chat_demo/src/chat.dart';
import 'package:tencent_cloud_chat_demo/src/navigation/app_page_transitions.dart';
import 'package:tencent_cloud_chat_demo/src/utils/message_conversation_id.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_conversation.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_conversation.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_message.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_message.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/message_anchor.dart';

/// Telegram-style route presence registry: a conversation owns at most one
/// active Chat route in the same Navigator. It does not share Chat State across
/// conversations; it only lets callers return to an existing conversation
/// route instead of stacking a duplicate instance.
class AppChatRouteRegistry {
  AppChatRouteRegistry._();

  static final AppChatRouteRegistry instance = AppChatRouteRegistry._();

  final Map<NavigatorState, Map<String, List<Route<dynamic>>>> _routes =
      <NavigatorState, Map<String, List<Route<dynamic>>>>{};

  void register({
    required NavigatorState navigator,
    required String sessionKey,
    required Route<dynamic> route,
  }) {
    final key = sessionKey.trim();
    if (key.isEmpty) {
      return;
    }
    final routes =
        (_routes[navigator] ??= <String, List<Route<dynamic>>>{}).putIfAbsent(
      key,
      () => <Route<dynamic>>[],
    );
    routes.removeWhere((candidate) => identical(candidate, route));
    routes.add(route);
  }

  void unregister({
    required NavigatorState navigator,
    required String sessionKey,
    required Route<dynamic> route,
  }) {
    final routes = _routes[navigator];
    if (routes == null) {
      return;
    }
    final key = sessionKey.trim();
    final sessionRoutes = routes[key];
    sessionRoutes?.removeWhere((candidate) => identical(candidate, route));
    if (sessionRoutes?.isEmpty ?? false) {
      routes.remove(key);
    }
    if (routes.isEmpty) {
      _routes.remove(navigator);
    }
  }

  Route<dynamic>? activeRoute(
    NavigatorState navigator,
    String sessionKey,
  ) {
    final key = sessionKey.trim();
    final navigatorRoutes = _routes[navigator];
    final sessionRoutes = navigatorRoutes?[key];
    if (sessionRoutes == null) {
      return null;
    }
    sessionRoutes.removeWhere(
      (route) => !route.isActive || !identical(route.navigator, navigator),
    );
    if (sessionRoutes.isEmpty) {
      navigatorRoutes?.remove(key);
      if (navigatorRoutes?.isEmpty ?? false) {
        _routes.remove(navigator);
      }
      return null;
    }
    return sessionRoutes.last;
  }

  @visibleForTesting
  void reset() => _routes.clear();
}

String appChatSessionKey(V2TimConversation conversation) {
  final resolved = MessageConversationId.resolve(
        conversationID: conversation.conversationID,
        groupID: conversation.groupID,
        userID: conversation.userID,
      ) ??
      '';
  final comparable = MessageConversationId.normalizeComparableKey(resolved);
  if (comparable.isEmpty) {
    return '';
  }
  final isGroup = conversation.type == 2 ||
      (conversation.groupID?.trim().isNotEmpty ?? false) ||
      MessageConversationId.looksLikeGroupConversationId(resolved);
  return '${isGroup ? 'group' : 'c2c'}:$comparable';
}

class _AppChatRoutePresence extends StatefulWidget {
  const _AppChatRoutePresence({
    required this.sessionKey,
    required this.child,
  });

  final String sessionKey;
  final Widget child;

  @override
  State<_AppChatRoutePresence> createState() => _AppChatRoutePresenceState();
}

class _AppChatRoutePresenceState extends State<_AppChatRoutePresence> {
  NavigatorState? _navigator;
  Route<dynamic>? _route;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final navigator = Navigator.of(context);
    final route = ModalRoute.of(context);
    if (route == null ||
        (identical(_navigator, navigator) && identical(_route, route))) {
      return;
    }
    _unregister();
    _navigator = navigator;
    _route = route;
    AppChatRouteRegistry.instance.register(
      navigator: navigator,
      sessionKey: widget.sessionKey,
      route: route,
    );
  }

  void _unregister() {
    final navigator = _navigator;
    final route = _route;
    if (navigator == null || route == null) {
      return;
    }
    AppChatRouteRegistry.instance.unregister(
      navigator: navigator,
      sessionKey: widget.sessionKey,
      route: route,
    );
    _navigator = null;
    _route = null;
  }

  @override
  void dispose() {
    _unregister();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

Route<T> appChatRoute<T>(
  V2TimConversation conversation, {
  int? entryUnreadCount,
  V2TimMessage? initFindingMsg,
  MessageAnchor? searchJumpAnchor,
  bool? initialC2cCanMessage,
  String? c2cPermissionHintSource,
}) {
  final resolvedAnchor = searchJumpAnchor ??
      (initFindingMsg == null
          ? null
          : MessageAnchor.fromConversationMessage(
              conversation,
              initFindingMsg,
            ));
  final sessionKey = appChatSessionKey(conversation);
  return AppMaterialPageRoute<T>(
    settings: const RouteSettings(name: AppRoutes.chat),
    // 聊天页禁止转场 snapshot：转场结束切回 live 树时会卸掉消息列表 State，
    // 表现为 t+300ms partition_cache_miss 全字段 -1→N 的整表重建抖动。
    allowSnapshotting: false,
    routeVisibilityDeferredFrames: 1,
    // 消息列表与上推动画抢边缘命中时，略加宽左缘返回条更稳。
    edgeStartWidthPx: 40,
    builder: (_) => _AppChatRoutePresence(
      sessionKey: sessionKey,
      child: RepaintBoundary(
        // 侧滑只合成图层，避免 20 条气泡跟着手势每帧 relayout。
        child: Chat(
          key: ValueKey<String>('chat_session_$sessionKey'),
          selectedConversation: conversation,
          entryUnreadCount: entryUnreadCount,
          initFindingMsg: initFindingMsg,
          searchJumpAnchor: resolvedAnchor,
          initialC2cCanMessage: initialC2cCanMessage,
          c2cPermissionHintSource: c2cPermissionHintSource,
        ),
      ),
    ),
  );
}

/// Opens a conversation or returns to its existing active route in this
/// Navigator. Different conversations never share a Chat State.
Future<T?> openOrReuseAppChat<T>(
  BuildContext context,
  V2TimConversation conversation, {
  int? entryUnreadCount,
  V2TimMessage? initFindingMsg,
  MessageAnchor? searchJumpAnchor,
  bool? initialC2cCanMessage,
  String? c2cPermissionHintSource,
}) {
  if (!context.mounted) {
    return Future<T?>.value();
  }
  final navigator = Navigator.of(context);
  final sessionKey = appChatSessionKey(conversation);
  // Search/anchor opens carry a new navigation subject. Until the existing
  // Chat State exposes an in-place target-message activation API, preserve the
  // established dedicated route semantics instead of silently dropping it.
  final canReuse = initFindingMsg == null && searchJumpAnchor == null;
  final existing = canReuse
      ? AppChatRouteRegistry.instance.activeRoute(navigator, sessionKey)
      : null;
  if (existing != null) {
    if (!existing.isCurrent) {
      navigator.popUntil((route) => identical(route, existing));
    }
    // Keep the same completion contract as Navigator.push: callers awaiting
    // this helper must resume only after the chat route is actually popped.
    // Returning an already-completed Future here makes a reused route look as
    // if the user had left chat, which can trigger unread finalize/hydrate
    // while the reused chat is still visible.
    return existing.popped.then<T?>((value) {
      if (value == null) {
        return null;
      }
      return value is T ? value : null;
    });
  }
  return navigator.push<T>(
    appChatRoute<T>(
      conversation,
      entryUnreadCount: entryUnreadCount,
      initFindingMsg: initFindingMsg,
      searchJumpAnchor: searchJumpAnchor,
      initialC2cCanMessage: initialC2cCanMessage,
      c2cPermissionHintSource: c2cPermissionHintSource,
    ),
  );
}

Future<T?> openChatWithAnchor<T>(
  BuildContext context,
  V2TimConversation conversation, {
  MessageAnchor? anchor,
}) {
  if (!context.mounted) {
    return Future<T?>.value();
  }
  return openOrReuseAppChat<T>(
    context,
    conversation,
    searchJumpAnchor: anchor,
  );
}
