import 'dart:async';

import 'package:tencent_cloud_chat_demo/src/api/api_client.dart';
import 'package:tencent_cloud_chat_demo/src/services/account_session_service.dart';
import 'package:tencent_cloud_chat_demo/src/i18n/app_i18n.dart';
import 'package:tencent_cloud_chat_demo/src/services/login_coordinator.dart';
import 'package:tencent_cloud_chat_demo/src/widgets/message_notification_banner.dart';
import 'package:tencent_cloud_chat_demo/utils/init_step.dart';
import 'package:tencent_cloud_chat_demo/utils/toast.dart';

class SessionExpiryService {
  SessionExpiryService._();

  static final SessionExpiryService instance = SessionExpiryService._();

  bool _handling = false;

  Future<void> handleExpired() async {
    if (_handling) {
      return;
    }
    final token = ApiClient.instance.token;
    if (token == null || token.isEmpty) {
      return;
    }
    _handling = true;
    try {
      final expiredMessage = AppI18n.current.t(
        zhHans: '登录状态已过期，请重新登录',
        zhHant: '登入狀態已過期，請重新登入',
        en: 'Session expired. Please sign in again.',
        ja: 'ログインの有効期限が切れました。再度ログインしてください。',
        ko: '로그인 상태가 만료되었습니다. 다시 로그인해 주세요.',
      );
      LoginCoordinator.instance.markSessionExpired(message: expiredMessage);
      await AccountSessionService.instance.clearForLogout(
        reason: 'session_expired',
      );

      ToastUtils.toast(expiredMessage);

      final context = AppNavigator.context;
      if (context != null && context.mounted) {
        scheduleMicrotask(() {
          final ctx = AppNavigator.context;
          if (ctx != null && ctx.mounted) {
            InitStep.directToLogin(ctx);
          }
        });
      }
    } finally {
      Future<void>.delayed(const Duration(seconds: 2), () {
        _handling = false;
      });
    }
  }
}
