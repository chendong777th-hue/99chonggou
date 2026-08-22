import 'package:flutter/scheduler.dart';
import 'package:tencent_cloud_chat_demo/src/widgets/app_dialog.dart';
import 'package:tencent_cloud_chat_demo/src/widgets/in_app_message_notification_banner.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/view_models/tui_chat_global_model.dart';
import 'package:tencent_cloud_chat_uikit/data_services/services_locatar.dart';
import 'package:tencent_cloud_chat_uikit/ui/widgets/wide_popup.dart';

/// 路由离栈后清理可能泄漏的全局 Overlay，避免挡住会话列表手势。
///
/// 必须在 post-frame 执行，避免在 Navigator 转场/build scope 内 remove OverlayEntry。
class OrphanOverlayGuard {
  OrphanOverlayGuard._();

  static void scheduleCleanup({
    required String reason,
    bool dismissInAppBanner = false,
    bool hideLoading = false,
  }) {
    SchedulerBinding.instance.addPostFrameCallback((_) {
      runCleanup(
        reason: reason,
        dismissInAppBanner: dismissInAppBanner,
        hideLoading: hideLoading,
      );
    });
  }

  static void runCleanup({
    required String reason,
    bool dismissInAppBanner = false,
    bool hideLoading = false,
  }) {
    try {
      serviceLocator<TUIChatGlobalModel>().dismissAllContextMenuOverlays();
    } catch (_) {}

    TUIKitWidePopup.forceDismiss();

    if (dismissInAppBanner && InAppMessageNotificationBanner.isExpanded) {
      InAppMessageNotificationBanner.hide();
    }

    if (hideLoading && AppDialog.isShowing) {
      AppDialog.hideLoading();
    }
  }
}
