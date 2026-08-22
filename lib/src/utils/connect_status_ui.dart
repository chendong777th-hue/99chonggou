import 'package:tencent_cloud_chat_demo/src/api/api_client.dart';
import 'package:tencent_cloud_chat_demo/src/i18n/app_i18n.dart';
import 'package:tencent_cloud_chat_demo/src/provider/local_setting.dart';
import 'package:tencent_cloud_chat_demo/src/services/auth_bootstrap_service.dart';
import 'package:tencent_cloud_chat_demo/src/services/login_coordinator.dart';
import 'package:tencent_cloud_chat_demo/src/services/login_state.dart';
import 'package:tencent_cloud_chat_demo/src/services/im_connect_status_service.dart';
import 'package:tencent_cloud_chat_demo/src/services/network_status_service.dart';

/// 五个主 Tab 顶部标题：区分 IM SDK 与自建后端未就绪时的展示态。
class ConnectStatusUi {
  ConnectStatusUi._();

  /// 自建后端接口是否已就绪（token 有效且不在拉 me / userSig 等 bootstrap 阶段）。
  static bool isBackendReady() {
    if (AuthBootstrapService.instance.backgroundSyncing.value) {
      return false;
    }
    if (!ApiClient.isValidJwt(ApiClient.instance.token)) {
      return false;
    }
    switch (LoginCoordinator.instance.state.phase) {
      case LoginPhase.businessAuthenticating:
      case LoginPhase.businessAuthenticated:
      case LoginPhase.sessionRefreshing:
        return false;
      default:
        return true;
    }
  }

  /// 系统网络是否可用（飞行模式 / 无蜂窝与 Wi‑Fi 时为 false）。
  static bool isNetworkReady() {
    return NetworkStatusService.instance.status.value !=
        NetworkReachability.offline;
  }

  /// IM SDK 长连接是否已就绪（以 [onConnectSuccess] 为准，登录态 ≠ 已连上服务器）。
  static bool isImSdkReady(LocalSetting localSetting) {
    if (!isNetworkReady()) {
      return false;
    }
    if (localSetting.connectStatusForUi == ConnectStatus.failed) {
      return false;
    }
    if (!ImConnectStatusService.isSocketReady) {
      return false;
    }
    switch (LoginCoordinator.instance.state.phase) {
      case LoginPhase.imConnecting:
      case LoginPhase.homeEnteredSyncingIm:
        return false;
      default:
        break;
    }
    if (AuthBootstrapService.instance.isCoreServicesUserReady()) {
      return true;
    }
    if (LoginCoordinator.instance.state.isImReady) {
      return true;
    }
    return localSetting.connectStatusForUi == ConnectStatus.success;
  }

  /// 主 Tab 大标题连接指示：busy/failed 时标题只显示转圈或错误图标。
  static ConversationTabConnectIndicator conversationTabConnectIndicator(
    LocalSetting localSetting,
  ) {
    final connectStatus = localSetting.connectStatusForUi;
    if (connectStatus == ConnectStatus.failed) {
      return ConversationTabConnectIndicator.failed;
    }
    if (!isNetworkReady() ||
        AuthBootstrapService.instance.backgroundSyncing.value ||
        !isBackendReady() ||
        !isImSdkReady(localSetting)) {
      return ConversationTabConnectIndicator.busy;
    }
    return ConversationTabConnectIndicator.ready;
  }

  /// 消息 / 群聊 Tab 纯标题（不再附带连接状态小字）。
  static String formatConversationTabTitle({
    required AppI18n i18n,
    required String baseTitle,
    required LocalSetting localSetting,
  }) {
    return baseTitle;
  }
}

/// 主 Tab 大标题旁连接指示。
enum ConversationTabConnectIndicator {
  ready,
  busy,
  failed,
}
