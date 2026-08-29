import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:tencent_cloud_chat_demo/src/services/auth_bootstrap_service.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_local/conversation_list_notifier.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_local/conversation_list_sync_notifier.dart';
import 'package:tencent_cloud_chat_demo/src/services/login_coordinator.dart';
import 'package:tencent_cloud_chat_uikit/theme/tui_theme.dart';

enum ConversationFeedMountMode { cached, active }

/// Lightweight diagnostics for the rare "feed no longer drags" state.
///
/// Opt in with `--dart-define=CONVERSATION_FEED_SCROLL_DIAG=true`. Keeping the
/// release guard here makes it impossible for production builds to emit it.
class ConversationFeedScrollDiagnostics {
  static const bool enabled = bool.fromEnvironment(
    'CONVERSATION_FEED_SCROLL_DIAG',
  );

  static void snapshot(
    String event, {
    required ScrollController controller,
    required ConversationFeedMountMode? mode,
    required bool tickerEnabled,
    bool? routeVisible,
    bool? hydratePending,
    bool? slidableOpen,
  }) {
    if (kReleaseMode || !enabled) return;
    final positions = controller.positions.toList(growable: false);
    final position = positions.length == 1 ? positions.single : null;
    debugPrint(
      '[ConversationFeedScrollDiag] event=$event mode=${mode?.name ?? 'none'} '
      'positions=${positions.length} offset=${position?.pixels} '
      'max=${position?.maxScrollExtent} activity=${position?.activity.runtimeType} '
      'scrolling=${position?.isScrollingNotifier.value} ticker=$tickerEnabled '
      'route=$routeVisible hydrate=$hydratePending slidable=$slidableOpen',
    );
  }
}

bool conversationFeedHasSinglePosition(ScrollController controller) =>
    controller.positions.length == 1;

bool conversationFeedModeSwitchNeedsDetach({
  required ConversationFeedMountMode? mounted,
  required ConversationFeedMountMode desired,
}) =>
    mounted != null && mounted != desired;

class ConversationFeedSyncGate extends StatefulWidget {
  const ConversationFeedSyncGate({
    super.key,
    required this.theme,
    required this.feedScrollController,
    required this.cachedFeedBuilder,
    required this.feedBuilder,
  });

  final TUITheme theme;
  final ScrollController feedScrollController;
  final Widget Function(BuildContext context, TUITheme theme) cachedFeedBuilder;
  final Widget Function(BuildContext context) feedBuilder;

  @override
  State<ConversationFeedSyncGate> createState() =>
      _ConversationFeedSyncGateState();
}

class _ConversationFeedSyncGateState extends State<ConversationFeedSyncGate> {
  ConversationFeedMountMode? _mountedMode;
  ConversationFeedMountMode? _pendingMode;

  ConversationFeedMountMode _desiredMode() {
    final sync = ConversationListSyncNotifier.instance.state;
    final isLoadingFirstScreen = !sync.hasSyncedOnce &&
        (sync.isSyncing ||
            AuthBootstrapService.instance.backgroundSyncing.value);
    return isLoadingFirstScreen &&
            !ConversationListNotifier.instance.hasLocalData
        ? ConversationFeedMountMode.cached
        : ConversationFeedMountMode.active;
  }

  void _finishModeSwitch(ConversationFeedMountMode desired) {
    if (_pendingMode == desired) return;
    _pendingMode = desired;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _pendingMode != desired) return;
      setState(() {
        _mountedMode = desired;
        _pendingMode = null;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _mountedMode != desired) return;
        ConversationFeedScrollDiagnostics.snapshot(
          'mode_mounted',
          controller: widget.feedScrollController,
          mode: desired,
          tickerEnabled: TickerMode.of(context),
          routeVisible: TickerMode.of(context),
        );
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    // 勿监听 ConversationListNotifier：置顶/未读会高频 notify，
    // 否则每次都会重建整个 FeedBody（日志里的 feed_state_build），造成闪动。
    // 列表内容由 ConversationFeedBody 内部自行监听。
    return AnimatedBuilder(
      animation: Listenable.merge([
        ConversationListSyncNotifier.instance,
        AuthBootstrapService.instance.backgroundSyncing,
        LoginCoordinator.instance,
      ]),
      builder: (context, child) {
        final desired = _desiredMode();
        _mountedMode ??= desired;
        if (conversationFeedModeSwitchNeedsDetach(
          mounted: _mountedMode,
          desired: desired,
        )) {
          // Do not mount cached and active scrollables in the same frame. The
          // empty hand-off frame lets the old ScrollPosition detach first.
          _finishModeSwitch(desired);
          return const SizedBox.shrink(
            key: ValueKey<String>('conversation_feed_detaching'),
          );
        }
        // A newer sync state may have returned to the already mounted owner
        // before the hand-off frame completed. Cancel the stale switch.
        _pendingMode = null;
        if (_mountedMode == ConversationFeedMountMode.cached) {
          return KeyedSubtree(
            key: const ValueKey<String>('conversation_feed_cached_owner'),
            child: widget.cachedFeedBuilder(context, widget.theme),
          );
        }
        return KeyedSubtree(
          key: const ValueKey<String>('conversation_feed_active_owner'),
          child: widget.feedBuilder(context),
        );
      },
    );
  }
}
