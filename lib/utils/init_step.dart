// ignore_for_file: avoid_print

import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:tencent_cloud_chat_demo/src/api/api_client.dart';
import 'package:tencent_cloud_chat_demo/src/api/auth_api.dart';
import 'package:tencent_cloud_chat_demo/src/pages/cross_platform/wide_screen/home_page.dart';
import 'package:tencent_cloud_chat_demo/src/pages/home_page.dart';
import 'package:tencent_cloud_chat_demo/src/pages/login.dart';
import 'package:tencent_cloud_chat_demo/src/provider/custom_sticker_package.dart';
import 'package:tencent_cloud_chat_demo/src/provider/user_sticker_provider.dart';
import 'package:tencent_cloud_chat_demo/src/provider/starred_friend_provider.dart';
import 'package:tencent_cloud_chat_demo/src/provider/login_user_Info.dart';
import 'package:tencent_cloud_chat_demo/src/provider/theme.dart';
import 'package:tencent_cloud_chat_demo/src/provider/local_setting.dart';
import 'package:tencent_cloud_chat_demo/src/services/device_sync_service.dart';
import 'package:tencent_cloud_chat_demo/src/platform/listener_store.dart';
import 'package:tencent_cloud_chat_demo/src/services/login_coordinator.dart';
import 'package:tencent_cloud_chat_demo/src/services/auth_session_service.dart';
import 'package:tencent_cloud_chat_demo/src/services/account_session_service.dart';
import 'package:tencent_cloud_chat_demo/src/services/notification_settings_service.dart';
import 'package:tencent_cloud_chat_demo/src/navigation/app_page_transitions.dart';
import 'package:tencent_cloud_chat_demo/src/services/platform_official_account_service.dart';
import 'package:tencent_cloud_chat_demo/src/services/im_connect_status_service.dart';
import 'package:tencent_cloud_chat_demo/src/widgets/message_notification_banner.dart';
import 'package:tencent_cloud_chat_demo/utils/theme.dart';
import 'package:tencent_cloud_chat_demo/src/utils/push_identity_cache.dart';
import 'package:tencent_cloud_chat_demo/utils/user_avatar.dart';
import 'package:provider/provider.dart';
import 'package:tencent_cloud_chat_sdk/tencent_im_sdk_plugin.dart';
import 'package:tencent_cloud_chat_uikit/tencent_cloud_chat_uikit.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/screen_utils.dart';

class InitStep {
  static const bool _sessionLogEnabled = false;

  static void _sessionLog(String message) {
    if (!_sessionLogEnabled) return;
    print(message);
  }

  static Future<void>? _activeCheckLogin;

  static setTheme(String themeTypeString, BuildContext context) {
    final CoreServicesImpl _coreInstance = TIMUIKitCore.getInstance();
    ThemeType themeType = DefTheme.themeTypeFromString(themeTypeString);
    Provider.of<DefaultThemeData>(context, listen: false).currentThemeType =
        themeType;
    Provider.of<DefaultThemeData>(context, listen: false).theme =
        DefTheme.getTheme(themeType);
    _coreInstance.setTheme(theme: DefTheme.getTheme(themeType));
  }

  static Future<void> publishStickerPackages(BuildContext context) async {
    if (!context.mounted) {
      return;
    }
    UserStickerProvider.shared.publishTo(
      Provider.of<CustomStickerPackageData>(context, listen: false),
    );
  }

  static setCustomSticker(BuildContext context) async {
    await publishStickerPackages(context);
  }

  static void removeLocalSetting() async {}

  static bool _isAlreadyOnLoginPage() {
    final ctx = AppNavigator.context;
    if (ctx == null) return false;
    final route = ModalRoute.of(ctx);
    return route?.settings.name == '/login';
  }

  static void _safeDirectToLogin(
    BuildContext context, [
    Future<void> Function()? initIMSDKAndAddIMListeners,
  ]) {
    if (AuthSessionService.instance.isInAuthFlow) {
      _sessionLog('InitStep: skip directToLogin (auth flow active)');
      return;
    }
    directToLogin(context, initIMSDKAndAddIMListeners);
  }

  static void directToLogin(
    BuildContext context, [
    Future<void> Function()? initIMSDKAndAddIMListeners,
  ]) {
    if (_isAlreadyOnLoginPage()) {
      _sessionLog('InitStep: already on login, skip navigate');
      return;
    }
    _setConnectStatus(context, ConnectStatus.success);
    leaveLaunchScreen(
      toHome: false,
      context: context,
      initIMSDK: initIMSDKAndAddIMListeners,
    );
  }

  static void directToHomePage(BuildContext context) {
    leaveLaunchScreen(toHome: true, context: context);
  }

  static void leaveLaunchScreen({
    required bool toHome,
    required BuildContext context,
    Future<void> Function()? initIMSDK,
  }) {
    if (toHome) {
      NotificationSettingsService.instance.endColdStartBannerSuppression();
    }
    void navigate() {
      if (toHome) {
        _pushAndRemoveUntil(
          context,
          _homeRoute(context),
          debugLabel: 'home',
        );
      } else {
        _pushAndRemoveUntil(
          context,
          AppMaterialPageRoute(
            settings: const RouteSettings(name: '/login'),
            enableFullScreenBackGesture: false,
            transitionDuration: kIsWeb
                ? Duration.zero
                : const Duration(milliseconds: 300),
            routeVisibilityDeferredFrames: kIsWeb ? 0 : 1,
            builder: (_) => LoginPage(initIMSDK: initIMSDK),
          ),
          debugLabel: 'login',
        );
      }
    }

    if (AppNavigator.key.currentState != null) {
      navigate();
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (AppNavigator.key.currentState != null) {
        navigate();
        return;
      }
      WidgetsBinding.instance.addPostFrameCallback((_) => navigate());
    });
  }

  static AppMaterialPageRoute<void> _homeRoute(BuildContext context) {
    final navContext = AppNavigator.context;
    final routeContext = context.mounted ? context : (navContext ?? context);
    final isWideScreen = routeContext.mounted &&
        TUIKitScreenUtils.getFormFactor(routeContext) == DeviceType.Desktop;
    return AppMaterialPageRoute(
      settings: const RouteSettings(name: '/homePage'),
      enableFullScreenBackGesture: false,
      transitionDuration:
          kIsWeb ? Duration.zero : const Duration(milliseconds: 300),
      routeVisibilityDeferredFrames: kIsWeb ? 0 : 1,
      builder: (_) =>
          isWideScreen ? const HomePageWideScreen() : const HomePage(),
    );
  }

  static void _pushAndRemoveUntil(
    BuildContext context,
    Route<void> route, {
    required String debugLabel,
  }) {
    NotificationSettingsService.instance.markHomeRouteNotReady();
    final nav = AppNavigator.key.currentState;
    if (nav != null) {
      nav.pushAndRemoveUntil(route, (_) => false);
      _sessionLog('InitStep: navigated to $debugLabel (AppNavigator)');
      return;
    }
    if (context.mounted) {
      Navigator.of(context).pushAndRemoveUntil(route, (_) => false);
      _sessionLog('InitStep: navigated to $debugLabel (context)');
      return;
    }
    _sessionLog('InitStep: navigate $debugLabel skipped (no navigator)');
  }

  /// Cold start: online auth + IM login before home (same order as password login).
  static void checkLogin(
    BuildContext context,
    Future<void> Function() initIMSDKAndAddIMListeners,
  ) {
    unawaited(_checkLoginGuarded(context, initIMSDKAndAddIMListeners));
  }

  static Future<void> _checkLoginGuarded(
    BuildContext context,
    Future<void> Function() initIMSDKAndAddIMListeners,
  ) async {
    if (_activeCheckLogin != null) {
      _sessionLog('InitStep: awaiting in-flight checkLogin');
      return _activeCheckLogin!;
    }

    _activeCheckLogin = _runCheckLogin(context, initIMSDKAndAddIMListeners);
    try {
      await _activeCheckLogin!;
    } finally {
      _activeCheckLogin = null;
    }
  }

  static Future<void> _runCheckLogin(
    BuildContext context,
    Future<void> Function() initIMSDKAndAddIMListeners,
  ) async {
    try {
      await _checkLoginCore(context, initIMSDKAndAddIMListeners);
    } catch (e, st) {
      _sessionLog('InitStep.checkLogin error: $e\n$st');
      final navContext = AppNavigator.context ?? context;
      if (navContext.mounted || AppNavigator.key.currentState != null) {
        _safeDirectToLogin(navContext, initIMSDKAndAddIMListeners);
      }
    }
  }

  static Future<void> _checkLoginCore(
    BuildContext context,
    Future<void> Function() initIMSDKAndAddIMListeners,
  ) async {
    await initIMSDKAndAddIMListeners();
    if (!context.mounted) return;

    unawaited(setCustomSticker(context));

    final token = ApiClient.instance.token;
    _sessionLog(
      'SESSION_LOG InitStep checkLogin start '
      'tokenValid=${ApiClient.isValidJwt(token)} '
      'hasToken=${token != null && token.trim().isNotEmpty} '
      'authFlow=${AuthSessionService.instance.isInAuthFlow}',
    );
    if (!ApiClient.isValidJwt(token)) {
      LoginCoordinator.instance.markLoggedOut();
      if (AuthSessionService.instance.isInAuthFlow) {
        _sessionLog('InitStep: skip checkLogin (no valid token, auth flow)');
        return;
      }
      _sessionLog(
          'SESSION_LOG InitStep checkLogin -> clearSessionAndGoLogin reason=invalid_token');
      await _clearSessionAndGoLogin(context, initIMSDKAndAddIMListeners);
      return;
    }

    _setConnectStatus(context, ConnectStatus.connecting);
    final recovery = await LoginCoordinator.instance.restoreColdStartSession();
    if (!context.mounted) return;
    _sessionLog(
      'SESSION_LOG InitStep checkLogin recovery '
      'action=${recovery.action} userId=${recovery.userId ?? '-'}',
    );

    switch (recovery.action) {
      case LoginRecoveryAction.goHome:
        final navContext = AppNavigator.context ?? context;
        ImConnectStatusService.applyForColdStartHome(navContext);
        NotificationSettingsService.instance.endColdStartBannerSuppression();
        leaveLaunchScreen(toHome: true, context: navContext);
        final me = recovery.me;
        if (me != null) {
          unawaited(_completeColdStartAfterHome(navContext, me));
        }
        return;
      case LoginRecoveryAction.goLogin:
      case LoginRecoveryAction.restartColdStart:
      case LoginRecoveryAction.stayOnHome:
        _safeDirectToLogin(context, initIMSDKAndAddIMListeners);
        return;
    }
  }

  static Future<void> _completeColdStartAfterHome(
    BuildContext context,
    MeResult me,
  ) async {
    try {
      await ListenerStore.afterLogin().timeout(const Duration(seconds: 6));
    } catch (_) {}

    try {
      await UserAvatarHelper.syncSelfAvatarFromBackend(me.avatarUrl).timeout(
        const Duration(seconds: 5),
      );
      await PushIdentityCache.instance.refreshSelf().timeout(
            const Duration(seconds: 5),
          );
    } catch (_) {}

    if (context.mounted) {
      await _syncLoginUserProfile(context).timeout(const Duration(seconds: 8));
    }

    if (context.mounted) {
      unawaited(
        ImConnectStatusService.reconcileStaleConnectingAfterColdStart(context),
      );
    }

    if (context.mounted) {
      unawaited(_runPostLoginSideEffects(context));
    }
  }

  static Future<void> _syncLoginUserProfile(BuildContext context) async {
    if (!context.mounted) return;
    final loginRes = await TencentImSDKPlugin.v2TIMManager.getLoginUser();
    final userId = loginRes.data?.trim() ?? '';
    if (userId.isEmpty) return;

    final result = await TencentImSDKPlugin.v2TIMManager
        .getUsersInfo(userIDList: [userId]);
    if (!context.mounted) return;
    if (result.code == 0 && result.data != null && result.data!.isNotEmpty) {
      Provider.of<LoginUserInfo>(context, listen: false)
          .setLoginUserInfo(result.data![0]);
    }
  }

  static Future<void> _runPostLoginSideEffects(BuildContext context) async {
    PlatformOfficialAccountService.resetSessionState();
    unawaited(
      PlatformOfficialAccountService.ensureSubscribed()
          .timeout(
            const Duration(seconds: 8),
            onTimeout: () => false,
          )
          .catchError((_) => false),
    );
    DeviceSyncService.instance.scheduleSyncAfterLogin();
    try {
      StarredFriendProvider.shared.refresh(force: true);
    } catch (_) {}
    // 原生贴纸由 NativePostHomeBootstrapQueue Stage9 串行执行，避免与进门后补全抢 IO。
    if (kIsWeb) {
      try {
        await UserStickerProvider.shared.refresh(force: true);
        if (context.mounted) {
          await publishStickerPackages(context);
        }
      } catch (_) {}
    }
  }

  static void _setConnectStatus(BuildContext context, ConnectStatus status) {
    if (!context.mounted) return;
    try {
      Provider.of<LocalSetting>(context, listen: false).connectStatus = status;
    } catch (_) {}
  }

  static Future<void> _clearSessionAndGoLogin(
    BuildContext context,
    Future<void> Function()? initIMSDKAndAddIMListeners,
  ) async {
    await AccountSessionService.instance.clearForLogout(
      reason: 'auth_state_invalid',
    );
    if (context.mounted) {
      directToLogin(context, initIMSDKAndAddIMListeners);
    }
  }
}
