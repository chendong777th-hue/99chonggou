import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tencent_cloud_chat_demo/src/i18n/app_i18n.dart';
import 'package:tencent_cloud_chat_demo/src/provider/local_setting.dart';
import 'package:tencent_cloud_chat_demo/src/services/auth_bootstrap_service.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_local/conversation_list_sync_notifier.dart';
import 'package:tencent_cloud_chat_demo/src/services/im_connect_status_service.dart';
import 'package:tencent_cloud_chat_demo/src/services/login_coordinator.dart';
import 'package:tencent_cloud_chat_demo/src/services/login_error.dart';
import 'package:tencent_cloud_chat_demo/src/services/login_state.dart';
import 'package:tencent_cloud_chat_demo/src/widgets/app_empty_state.dart';

class ConversationFeedEmptyState extends StatelessWidget {
  const ConversationFeedEmptyState({
    super.key,
    required this.isGroupTab,
    required this.businessEmptyBuilder,
  });

  final bool isGroupTab;
  final Widget Function(BuildContext context) businessEmptyBuilder;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        ConversationListSyncNotifier.instance,
        AuthBootstrapService.instance.backgroundSyncing,
        LoginCoordinator.instance,
        ImConnectStatusService.instance,
      ]),
      builder: (context, child) {
        final localSetting = Provider.of<LocalSetting>(context, listen: false);
        if (_shouldShowSyncing(localSetting)) {
          return AppEmptyState(
            padding: const EdgeInsets.only(top: 80),
            message: AppI18n.of(context).t(
              zhHans: '正在同步会话，请稍候',
              zhHant: '正在同步會話，請稍候',
              en: 'Syncing chats, please wait',
              ja: '会話を同期しています',
              ko: '대화를 동기화하는 중입니다',
            ),
          );
        }
        if (_shouldShowSyncFailed()) {
          return AppEmptyState(
            padding: const EdgeInsets.only(top: 80),
            message: AppI18n.of(context).t(
              zhHans: '会话同步失败，请稍后重试',
              zhHant: '會話同步失敗，請稍後重試',
              en: 'Chat sync failed, please try again later',
              ja: '会話の同期に失敗しました。しばらくしてから再試行してください',
              ko: '대화 동기화에 실패했습니다. 잠시 후 다시 시도하세요',
            ),
          );
        }
        return businessEmptyBuilder(context);
      },
    );
  }

  bool _shouldShowSyncing(LocalSetting localSetting) {
    final sync = ConversationListSyncNotifier.instance.state;
    final syncing = AuthBootstrapService.instance.backgroundSyncing.value;
    if (syncing || sync.isSyncing) {
      return true;
    }
    if (sync.hasSyncedOnce) {
      return false;
    }
    if (localSetting.connectStatusForUi == ConnectStatus.connecting ||
        ImConnectStatusService.isHandshakePending ||
        !ImConnectStatusService.isSocketReady) {
      return true;
    }
    final state = LoginCoordinator.instance.state;
    return state.phase == LoginPhase.businessAuthenticated ||
        state.phase == LoginPhase.imConnecting ||
        state.phase == LoginPhase.homeEnteredSyncingIm;
  }

  bool _shouldShowSyncFailed() {
    final error = LoginCoordinator.instance.state.lastError;
    return error?.type == LoginErrorType.imLoginFailed ||
        error?.type == LoginErrorType.conversationBootstrapFailed;
  }
}
