// ignore_for_file: unused_import, deprecated_member_use

import 'dart:async';
import 'dart:io' show Platform;

import 'package:bitsdojo_window/bitsdojo_window.dart';
import 'package:desktop_webview_window_for_is/desktop_webview_window_for_is.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:image_picker_android/image_picker_android.dart';
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:tencent_chat_i18n_tool/language_json/strings.g.dart';
import 'package:tencent_chat_i18n_tool/tools/i18n_tool.dart';
import 'package:tencent_cloud_chat_demo/custom_animation.dart';
import 'package:tencent_cloud_chat_demo/config.dart';
import 'package:tencent_cloud_chat_demo/src/api/api_client.dart';
import 'package:tencent_cloud_chat_demo/src/services/api_node_service.dart';
import 'package:tencent_cloud_chat_demo/src/navigation/app_material_app_builder.dart';
import 'package:tencent_cloud_chat_demo/src/navigation/app_page_transitions.dart';
import 'package:tencent_cloud_chat_demo/src/navigation/app_route_lifecycle.dart';
import 'package:tencent_cloud_chat_demo/src/navigation/route_visibility.dart';
import 'package:tencent_cloud_chat_demo/src/pages/app.dart';
import 'package:tencent_cloud_chat_demo/src/utils/launch_system_ui.dart';
import 'package:tencent_cloud_chat_demo/src/pages/wallet/wallet_repository_provider.dart';
import 'package:tencent_cloud_chat_demo/src/provider/custom_sticker_package.dart';
import 'package:tencent_cloud_chat_demo/src/provider/local_setting.dart';
import 'package:tencent_cloud_chat_demo/src/pages/settings/language_switch_sheet.dart';
import 'package:tencent_cloud_chat_demo/src/services/device_sync_service.dart';
import 'package:tencent_cloud_chat_demo/src/services/android_performance_profile.dart';
import 'package:tencent_cloud_chat_demo/src/services/message_archive_history_service.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_history_clear_service.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_peer_read_sync_service.dart';
import 'package:tencent_cloud_chat_demo/src/services/network_status_service.dart';
import 'package:tencent_cloud_chat_demo/src/services/notification_settings_service.dart';
import 'package:tencent_cloud_chat_demo/src/platform/uikit_conversation_notify_bridge.dart';
import 'package:tencent_cloud_chat_demo/src/platform/uikit_conversation_local_bridge.dart';
import 'package:tencent_cloud_chat_demo/src/platform/c2c_friend_message_guard_bridge.dart';
import 'package:tencent_cloud_chat_demo/src/platform/uikit_self_hosted_friend_bridge.dart';
import 'package:tencent_cloud_chat_demo/src/services/group_join_application_service.dart';
import 'package:tencent_cloud_chat_demo/src/services/group_notice_entry_settings_service.dart';
import 'package:tencent_cloud_chat_demo/src/services/group_notice_unread_service.dart';
import 'package:tencent_cloud_chat_demo/src/platform/uikit_self_hosted_group_bridge.dart';
import 'package:tencent_cloud_chat_demo/src/platform/uikit_add_friend_bridge.dart';
import 'package:tencent_cloud_chat_demo/src/platform/uikit_permission_bridge.dart';
import 'package:tencent_cloud_chat_demo/src/platform/uikit_media_url_bridge.dart';
import 'package:tencent_cloud_chat_demo/src/platform/uikit_voice_to_text_bridge.dart';
import 'package:tencent_cloud_chat_demo/src/services/login_coordinator.dart';
import 'package:tencent_cloud_chat_demo/src/services/in_app_notification_sound.dart';
import 'package:tencent_cloud_chat_demo/src/services/group_live/group_live_tencent_licence.dart';
import 'package:tencent_cloud_chat_demo/src/services/ios_apns_push_service.dart';
import 'package:tencent_cloud_chat_demo/src/services/push_registration_service.dart';
import 'package:tencent_cloud_chat_demo/src/services/session_expiry_service.dart';
import 'package:tencent_cloud_chat_demo/src/services/splash_config_service.dart';
import 'package:tencent_cloud_chat_demo/src/widgets/forward_pick_pages.dart';
import 'package:tencent_cloud_chat_demo/src/widgets/message_notification_banner.dart';
import 'package:tencent_cloud_chat_demo/src/widgets/app_privacy_cover.dart';
import 'package:tencent_cloud_chat_demo/src/provider/login_user_Info.dart';
import 'package:tencent_cloud_chat_demo/src/provider/presence_provider.dart';
import 'package:tencent_cloud_chat_demo/src/provider/starred_friend_provider.dart';
import 'package:tencent_cloud_chat_demo/src/provider/theme.dart';
import 'package:tencent_cloud_chat_demo/src/provider/user_guide_provider.dart';
import 'package:tencent_cloud_chat_demo/utils/app_material_theme.dart';
import 'package:tencent_cloud_chat_demo/utils/theme.dart';
import 'package:tencent_cloud_chat_uikit/tencent_cloud_chat_uikit.dart';
import 'package:tencent_cloud_chat_uikit/theme/color.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/platform.dart';

void main(List<String> args) {
  runZonedGuarded<void>(
    () => _startApp(args),
    (error, stack) {
      if (_isKnownWebNoise(error, stack)) {
        return;
      }
      FlutterError.reportError(FlutterErrorDetails(
        exception: error,
        stack: stack,
      ));
    },
  );
}

Future<void> _warmWebBundledFonts() async {
  if (!kIsWeb) return;
  try {
    await Future.wait<Object?>([
      rootBundle.load('assets/fonts/NotoSansSC-Regular.ttf'),
      rootBundle.load('assets/fonts/NotoSansSC-SemiBold.ttf'),
      rootBundle.load('assets/fonts/NotoSansSC-Bold.ttf'),
      rootBundle.load('assets/fonts/NotoSansSC-Variable.ttf'),
    ]);
  } catch (_) {
    // 字体资源缺失时不阻塞启动。
  }
}

void _startApp(List<String> args) {
  if (kDebugMode) {
    debugPrint('args: $args');
  }
  if (runWebViewTitleBarWidget(args)) {
    return;
  }
  WidgetsFlutterBinding.ensureInitialized();
  if (!kIsWeb && (Platform.isIOS || Platform.isAndroid)) {
    unawaited(GroupLiveTencentLicence.ensureConfigured());
  }
  if (!kIsWeb && Platform.isAndroid) {
    final picker = ImagePickerPlatform.instance;
    if (picker is ImagePickerAndroid) {
      // Android 12 及以下也优先尝试系统 Photo Picker；不可用时插件会回退到
      // 系统文档选择器，聊天页仍保留自定义相册作为异常兜底。
      picker.useAndroidPhotoPicker = true;
    }
  }
  // 保留足够的头像/缩略图解码缓存，同时限制长时间媒体会话的位图上限；
  // 384MB 在锁屏恢复时容易与消息列表重建叠加造成内存压力和 GC 卡顿。
  void configureImageCache() {
    if (!kIsWeb && Platform.isAndroid) {
      final profile = AndroidPerformanceProfile.instance;
      PaintingBinding.instance.imageCache.maximumSize =
          profile.imageCacheMaximumSize;
      PaintingBinding.instance.imageCache.maximumSizeBytes =
          profile.imageCacheMaximumSizeBytes;
      return;
    }
    PaintingBinding.instance.imageCache.maximumSize = 1200;
    PaintingBinding.instance.imageCache.maximumSizeBytes = 192 << 20;
  }

  configureImageCache();
  if (kDebugMode) {
    final cache = PaintingBinding.instance.imageCache;
    // ignore: avoid_print
    print(
      '[CHAT_JITTER] event=image_cache_init '
      'platform=${kIsWeb ? 'web' : Platform.operatingSystem} '
      'maxCount=${cache.maximumSize} '
      'maxBytes=${cache.maximumSizeBytes}',
    );
  }
  _installWebErrorGuard();
  // 冷启动与原生闪屏对齐：沉浸式透明系统栏
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(LaunchSystemUi.overlayStyle);
  // 全局loading
  configLoading();
  // AutoSizeUtil.setStandard(375, isAutoTextSize: true);
  // Default to Simplified Chinese until the saved language is loaded.
  WidgetsFlutterBinding.ensureInitialized();
  LocaleSettings.setLocale(AppLocale.zhHans);

  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp])
      .then((_) async {
    ApiClient.onAuthExpired = SessionExpiryService.instance.handleExpired;
    // 节点选择须在首次 Dio 请求前恢复，否则会打到编译期默认域名。
    await ApiNodeService.instance.hydrate();
    await ApiClient.instance.bootstrap();
    if (!kIsWeb) {
      await SplashConfigService.instance.prepareForLaunch();
    }
    if (IMDemoConfig.selfHostedPushEnabled && PlatformUtils().isIOS) {
      await IosApnsPushService.instance.install(
        onVoipPush: NotificationSettingsService
            .instance.handleVoipPushPayloadForBootstrap,
      );
    }
    UikitPermissionBridge.install();
    DeviceSyncService.installPermissionHooks();
    UikitMediaUrlBridge.install();
    UikitAddFriendBridge.install();
    UikitSelfHostedFriendBridge.install();
    UikitC2cFriendMessageGuardBridge.install();
    UikitVoiceToTextBridge.install();
    UikitConversationLocalBridge.install();
    UikitConversationNotifyBridge.install();
    UikitSelfHostedGroupBridge.install();
    // 自建后端归档：IM SDK 漫游到底后回退拉取更早冷历史。
    MessageArchiveHistoryService.register();
    ConversationHistoryClearService.register();
    ConversationPeerReadSyncService.register();
    installForwardPickPages();
    final localSetting = LocalSetting(autoLoad: false);

    Future<void> finishDeferredBootstrap() async {
      if (kIsWeb) {
        unawaited(NetworkStatusService.instance.start());
      } else {
        await NetworkStatusService.instance.start();
      }
      unawaited(GroupNoticeUnreadService.instance.ensureLoaded());
      unawaited(GroupNoticeEntrySettingsService.instance.ensureLoaded());
      unawaited(
        GroupJoinApplicationService.instance.refresh(syncMembership: false),
      );
      await localSetting.loadSettingsFromLocal();
      InAppNotificationSound.soundIdResolver =
          () => localSetting.messageNotificationSoundId;
      NotificationSettingsService.instance.attach(localSetting);
      if (!kIsWeb) {
        await NotificationSettingsService.instance
            .ensureSelfHostedPushTapHandler();
      }
      final language = LocalSetting.normalizeLanguage(localSetting.language);
      localSetting.updateLanguageWithoutWriteLocal(language);
      LocaleSettings.setLocale(LanguageSwitchSheet.toAppLocale(language));
    }

    if (kIsWeb) {
      // Web：预热内置字体后再 runApp，避免首帧仍走 gstatic 回退。
      await _warmWebBundledFonts();
      runApp(
        TranslationProvider(
          child: MultiProvider(
            providers: [
              ChangeNotifierProvider(create: (_) => LoginUserInfo()),
              ChangeNotifierProvider(create: (_) => DefaultThemeData()),
              ChangeNotifierProvider(create: (_) => CustomStickerPackageData()),
              ChangeNotifierProvider.value(value: localSetting),
              ChangeNotifierProvider.value(value: LoginCoordinator.instance),
              ChangeNotifierProvider(create: (_) => UserGuideProvider()),
              ChangeNotifierProvider(create: (_) => PresenceProvider()),
              ChangeNotifierProvider.value(value: StarredFriendProvider.shared),
            ],
            child: const TUIKitDemoApp(),
          ),
        ),
      );
      unawaited(finishDeferredBootstrap());
      return;
    }

    await finishDeferredBootstrap();
    if (Platform.isAndroid) {
      await AndroidPerformanceProfile.instance.initialize();
      configureImageCache();
    }
    runApp(
      // runAutoApp(
      TranslationProvider(
        child: MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => LoginUserInfo()),
            ChangeNotifierProvider(create: (_) => DefaultThemeData()),
            ChangeNotifierProvider(create: (_) => CustomStickerPackageData()),
            ChangeNotifierProvider.value(value: localSetting),
            ChangeNotifierProvider.value(value: LoginCoordinator.instance),
            ChangeNotifierProvider(create: (_) => UserGuideProvider()),
            ChangeNotifierProvider(create: (_) => PresenceProvider()),
            ChangeNotifierProvider.value(value: StarredFriendProvider.shared),
          ],
          child: const TUIKitDemoApp(),
        ),
      ),
    );
    // 不阻塞冷启动：拉取/下载供下次 LaunchPage 使用（Web 无启动页，跳过）。
    if (!kIsWeb) {
      unawaited(SplashConfigService.instance.refreshInBackground());
    }
  });

  if (PlatformUtils().isDesktop) {
    doWhenWindowReady(() {
      const initialSize = Size(1300, 830);
      appWindow.minSize = const Size(1100, 630);
      appWindow.size = initialSize;
      appWindow.alignment = Alignment.center;
      appWindow.show();
    });
  }

  // );
}

class TUIKitDemoApp extends StatelessWidget {
  const TUIKitDemoApp({Key? key}) : super(key: key);
  @override
  Widget build(BuildContext context) {
    final themeModel = context.watch<DefaultThemeData>();
    return ValueListenableBuilder<bool>(
      valueListenable: LaunchSystemUi.startupPhaseListenable,
      builder: (context, _, __) {
        final systemOverlayStyle = LaunchSystemUi.overlayForApp(context);
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: systemOverlayStyle,
          child: AppPrivacyCover(
            child: MaterialApp(
              navigatorKey: AppNavigator.key,
              title: '99chat',
              debugShowCheckedModeBanner: false,
              locale: TranslationProvider.of(context).flutterLocale,
              supportedLocales: LocaleSettings.supportedLocales,
              localizationsDelegates: GlobalMaterialLocalizations.delegates,
              themeMode: themeModel.materialThemeMode,
              theme: buildAppMaterialTheme(DefTheme.blueTheme, isDark: false),
              darkTheme:
                  buildAppMaterialTheme(DefTheme.darkTheme, isDark: true),
              home: const TencentChatApp(),
              routes: {
                '/homePage': (_) => const TencentChatApp(),
                '/login': (_) => const TencentChatApp(),
              },
              builder: (context, child) =>
                  AnnotatedRegion<SystemUiOverlayStyle>(
                value: LaunchSystemUi.overlayForApp(context),
                child: AppMaterialAppBuilder(child: child),
              ),
              navigatorObservers: [
                appRouteObserver,
                AppRouteLifecycleObserver(),
              ],
            ),
          ),
        );
      },
    );
  }
}

void _installWebErrorGuard() {
  if (!kIsWeb) {
    return;
  }

  final oldFlutterError = FlutterError.onError;
  FlutterError.onError = (details) {
    if (_isKnownWebNoise(details.exception, details.stack)) {
      return;
    }
    oldFlutterError?.call(details);
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    if (_isKnownWebNoise(error, stack)) {
      return true;
    }
    return false;
  };
}

bool _isKnownWebNoise(Object error, StackTrace? stack) {
  if (!kIsWeb) {
    return false;
  }

  final message = error.toString();
  final trace = stack?.toString() ?? '';

  // dio 4.0.6 web XHR adapter double-completes when connectTimeout is set.
  if (trace.contains('browser_adapter.dart') ||
      trace.contains('dio_fixed_browser_adapter_web.dart')) {
    if (message.contains('Future already completed') ||
        message.contains('Bad state') ||
        message == 'Error' ||
        message.startsWith('Error:')) {
      return true;
    }
  }

  if (message.contains('Assertion failed') &&
      trace.contains('mouse_tracker.dart')) {
    return true;
  }

  return false;
}

void configLoading() {
  EasyLoading.instance
    ..displayDuration = const Duration(milliseconds: 2000)
    ..indicatorType = EasyLoadingIndicatorType.fadingCircle
    ..loadingStyle = EasyLoadingStyle.custom
    ..indicatorSize = 38.0
    ..radius = 18.0
    ..progressColor = const Color(0xFF2B72FF)
    ..backgroundColor = Colors.white
    ..indicatorColor = const Color(0xFF2B72FF)
    ..textColor = const Color(0xFF111111)
    ..maskColor = Colors.black.withOpacity(0.18)
    ..boxShadow = [
      BoxShadow(
        color: Colors.black.withOpacity(0.12),
        blurRadius: 28,
        offset: const Offset(0, 14),
      ),
    ]
    ..userInteractions = true
    ..dismissOnTap = false
    ..customAnimation = CustomAnimation();
}
