import 'package:flutter/material.dart';
import 'package:tencent_cloud_chat_demo/src/services/auth_bootstrap_service.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_local/conversation_list_notifier.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_local/conversation_list_sync_notifier.dart';
import 'package:tencent_cloud_chat_demo/src/services/login_coordinator.dart';
import 'package:tencent_cloud_chat_uikit/theme/tui_theme.dart';

class ConversationFeedSyncGate extends StatelessWidget {
  const ConversationFeedSyncGate({
    super.key,
    required this.theme,
    required this.cachedFeedBuilder,
    required this.feedBuilder,
  });

  final TUITheme theme;
  final Widget Function(BuildContext context, TUITheme theme) cachedFeedBuilder;
  final Widget Function(BuildContext context) feedBuilder;

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
        final sync = ConversationListSyncNotifier.instance.state;
        final isLoadingFirstScreen = !sync.hasSyncedOnce &&
            (sync.isSyncing ||
                AuthBootstrapService.instance.backgroundSyncing.value);
        if (isLoadingFirstScreen &&
            !ConversationListNotifier.instance.hasLocalData) {
          return cachedFeedBuilder(context, theme);
        }
        return feedBuilder(context);
      },
    );
  }
}
