// ignore_for_file: prefer_typing_uninitialized_variables, avoid_print

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tencent_cloud_chat_demo/src/i18n/app_i18n.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import 'package:tencent_cloud_chat_demo/config.dart';
import 'package:tencent_cloud_chat_demo/src/contact.dart';
import 'package:tencent_cloud_chat_demo/src/conversation.dart';
import 'package:tencent_cloud_chat_demo/src/services/auth_bootstrap_service.dart';
import 'package:tencent_cloud_chat_demo/src/services/session_identity.dart';
import 'package:tencent_cloud_chat_demo/src/services/account_session_service.dart';
import 'package:tencent_cloud_chat_demo/src/services/app_update_service.dart';
import 'package:tencent_cloud_chat_demo/src/services/interaction_idle_scheduler.dart';
import 'package:tencent_cloud_chat_demo/src/create_group.dart';
import 'package:tencent_cloud_chat_demo/src/pages/wallet/wallet_screen.dart';
import 'package:tencent_cloud_chat_demo/src/pages/settings/notification_settings_page.dart';
import 'package:tencent_cloud_chat_demo/src/pages/settings/settings_page.dart';
import 'package:tencent_cloud_chat_demo/src/profile.dart';
import 'package:tencent_cloud_chat_demo/src/provider/local_setting.dart';
import 'package:tencent_cloud_chat_demo/src/provider/login_user_Info.dart';
import 'package:tencent_cloud_chat_demo/src/provider/theme.dart';
import 'package:tencent_cloud_chat_demo/src/theme/app_colors.dart';
import 'package:tencent_cloud_chat_demo/src/ui/app_responsive.dart';
import 'package:tencent_cloud_chat_demo/src/ui/app_tokens.dart';
import 'package:tencent_cloud_chat_demo/utils/theme.dart';
import 'package:tencent_cloud_chat_demo/src/utils/immersive_app_system_ui.dart';
import 'package:tencent_cloud_chat_demo/src/utils/launch_system_ui.dart';
import 'package:tencent_cloud_chat_demo/src/utils/qr_scanner_launcher.dart';
import 'package:tencent_cloud_chat_demo/utils/init_step.dart';
import 'package:tencent_cloud_chat_demo/src/search_add_page.dart';
import 'package:tencent_cloud_chat_demo/src/navigation/orphan_overlay_guard.dart';
import 'package:tencent_cloud_chat_demo/src/navigation/route_visibility.dart';
import 'package:tencent_cloud_chat_demo/src/tencent_page.dart';
import 'package:tencent_cloud_chat_demo/src/services/push_notification_router.dart';
import 'package:tencent_cloud_chat_demo/src/utils/notification_push_text.dart';
import 'package:tencent_cloud_chat_demo/src/services/notification_settings_service.dart';
import 'package:tencent_cloud_chat_demo/src/services/im_connect_status_service.dart';
import 'package:tencent_cloud_chat_demo/src/services/login_coordinator.dart';
import 'package:tencent_cloud_chat_demo/src/services/device_sync_service.dart';
import 'package:tencent_cloud_chat_demo/src/services/friend_request_notice_service.dart';
import 'package:tencent_cloud_chat_demo/src/services/network_status_service.dart';
import 'package:tencent_cloud_chat_demo/src/utils/connect_status_ui.dart';
import 'package:tencent_cloud_chat_demo/src/widgets/conversation_scope_unread_badge.dart';
import 'package:tencent_cloud_chat_demo/src/widgets/fading_arc_spinner.dart';
import 'package:tencent_cloud_chat_demo/src/widgets/friend_request_unread_badge.dart';
import 'package:tencent_cloud_chat_sdk/manager/v2_tim_manager.dart';
import 'package:tencent_cloud_chat_uikit/tencent_cloud_chat_uikit.dart';
import 'package:tencent_cloud_chat_uikit/theme/color.dart';
import 'package:tencent_cloud_chat_uikit/ui/controller/tim_uikit_conversation_controller.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/platform.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/screen_utils.dart';
import 'package:tencent_cloud_chat_demo/src/widgets/home_nav_plus_icon.dart';
import 'package:tencent_cloud_chat_demo/src/customer_service_icon.dart';
import 'package:tencent_cloud_chat_demo/src/navigation/app_page_transitions.dart';
import 'package:tencent_cloud_chat_demo/utils/customer_service_nav.dart';

/// 首页
class HomePage extends StatefulWidget {
  final int pageIndex;

  const HomePage({Key? key, this.pageIndex = 0}) : super(key: key);

  @override
  State<StatefulWidget> createState() => HomePageState();
}

class HomePageState extends State<HomePage> {
  bool hasInit = false;
  var subscription;
  bool hasInternet = true;
  int currentIndex = 0;
  final Set<int> _visitedTabs = <int>{};
  final GlobalKey _plusActionKey = GlobalKey();

  /// 加号图标旋转（圈数），每次 +0.25 为顺时针 90°。
  double _plusIconTurns = 0;
  final V2TIMManager _sdkInstance = TIMUIKitCore.getSDKInstance();
  final TIMUIKitConversationController _conversationController =
      TIMUIKitConversationController();
  final TIMUIKitConversationController _groupConversationController =
      TIMUIKitConversationController();
  Widget? _conversationPage;
  Widget? _groupConversationPage;
  Widget? _contactPage;
  Widget? _walletPage;
  Widget? _profilePage;
  final ValueNotifier<int> _activeTabIndex = ValueNotifier<int>(0);
  String pageName = "";
  bool isNeedMoveToConversation = false;
  Object? _navIconThemeToken;
  Locale? _navIconLocale;
  late Widget _navIconC2cSelected;
  late Widget _navIconC2cUnselected;
  late Widget _navIconGroupSelected;
  late Widget _navIconGroupUnselected;
  late Widget _navIconContactSelected;
  late Widget _navIconContactUnselected;
  late Widget _navIconWalletSelected;
  late Widget _navIconWalletUnselected;
  late Widget _navIconProfileSelected;
  late Widget _navIconProfileUnselected;

  @override
  void dispose() {
    NotificationSettingsService.instance.markHomeRouteNotReady();
    AuthBootstrapService.instance.backgroundSyncing
        .removeListener(_handleBackgroundSyncChanged);
    _activeTabIndex.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> _contactTooltip(BuildContext context) => [
        {
          "id": "searchAdd",
          "icon": Icons.person_search_rounded,
          "label": AppI18n.of(context).t(
            zhHans: '搜索添加',
            zhHant: '搜尋添加',
            en: 'Search & Add',
            ja: '検索して追加',
            ko: '검색 및 추가',
          )
        },
        {
          "id": "createGroup",
          "asset": "assets/group_conv.png",
          "label": AppI18n.of(context).t(
            zhHans: '创建群聊',
            zhHant: '建立群聊',
            en: 'Create Group',
            ja: 'グループを作成',
            ko: '그룹 만들기',
          )
        },
        {
          "id": "scanQRCode",
          "icon": Icons.qr_code_scanner_rounded,
          "label": AppI18n.of(context).t(
            zhHans: '扫一扫',
            zhHant: '掃一掃',
            en: 'Scan',
            ja: 'スキャン',
            ko: '스캔',
          )
        }
      ];

  List<Map<String, dynamic>> _conversationTooltip(BuildContext context) => [
        {
          "id": "searchAdd",
          "icon": Icons.person_search_rounded,
          "label": AppI18n.of(context).t(
            zhHans: '搜索添加',
            zhHant: '搜尋添加',
            en: 'Search & Add',
            ja: '検索して追加',
            ko: '검색 및 추가',
          )
        },
        {
          "id": "createGroup",
          "asset": "assets/group_conv.png",
          "label": AppI18n.of(context).t(
            zhHans: '创建群聊',
            zhHant: '建立群聊',
            en: 'Create Group',
            ja: 'グループを作成',
            ko: '그룹 만들기',
          )
        },
        {
          "id": "scanQRCode",
          "icon": Icons.qr_code_scanner_rounded,
          "label": AppI18n.of(context).t(
            zhHans: '扫一扫',
            zhHant: '掃一掃',
            en: 'Scan',
            ja: 'スキャン',
            ko: '스캔',
          )
        },
      ];

  Future<void>? _loginUserInfoTask;

  Future<void> getLoginUserInfo() {
    return _loginUserInfoTask ??= _getLoginUserInfoOnce().whenComplete(() {
      _loginUserInfoTask = null;
    });
  }

  Future<void> _getLoginUserInfoOnce() async {
    if (PlatformUtils().isWeb || !mounted) {
      return;
    }
    final identity = SessionIdentityService.instance.capture();
    if (identity.ownerUserId.isEmpty) {
      return;
    }
    final res = await _sdkInstance.getLoginUser();
    if (!SessionIdentityService.instance.isCurrent(identity)) {
      return;
    }
    final userId = res.data?.trim() ?? '';
    if (res.code != 0 || userId.isEmpty) {
      return;
    }
    final result = await _sdkInstance.getUsersInfo(userIDList: [userId]);
    if (!mounted || !SessionIdentityService.instance.isCurrent(identity)) {
      return;
    }
    if (result.code == 0 && result.data != null && result.data!.isNotEmpty) {
      Provider.of<LoginUserInfo>(context, listen: false)
          .setLoginUserInfo(result.data![0]);
    }
  }

  void _handleBackgroundSyncChanged() {
    if (AuthBootstrapService.instance.backgroundSyncing.value) {
      return;
    }
    unawaited(getLoginUserInfo());
  }

  @override
  initState() {
    super.initState();
    currentIndex = widget.pageIndex;
    _activeTabIndex.value = currentIndex;
    // 只挂载当前消息 Tab；群/单聊另一侧首次点选再建，避免冷启双 Feed 全量装配 600+ 行。
    _visitedTabs.add(currentIndex);
    DeviceSyncService.instance.setHomeTabIndex(currentIndex);
    FriendRequestNoticeService.instance.onHomeTabChanged(currentIndex);
    AuthBootstrapService.instance.backgroundSyncing
        .addListener(_handleBackgroundSyncChanged);
    if (kIsWeb) {
      unawaited(_initNotifications());
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        LaunchSystemUi.completeStartup(context);
        NotificationSettingsService.instance.markHomeRouteReady();
        if (!ImConnectStatusService.isSocketReady ||
            ImConnectStatusService.isHandshakePending) {
          ImConnectStatusService.beginSocketHandshake(context: context);
        }
        Future<void>.delayed(const Duration(milliseconds: 600), () {
          if (!mounted) {
            return;
          }
          ImConnectStatusService.syncToLocalSetting(context);
          unawaited(getLoginUserInfo());
        });
        Future<void>.delayed(const Duration(seconds: 3), () {
          if (mounted) {
            unawaited(AppUpdateService.instance.check(context, manual: false));
          }
        });
      });
      return;
    }
    _initNotifications();
    getLoginUserInfo();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      LaunchSystemUi.completeStartup(context);
      NotificationSettingsService.instance.markHomeRouteReady();
      if (!ImConnectStatusService.isSocketReady ||
          ImConnectStatusService.isHandshakePending) {
        ImConnectStatusService.beginSocketHandshake(context: context);
      }
      ImConnectStatusService.syncToLocalSetting(context);
      unawaited(getLoginUserInfo());
      InteractionIdleScheduler.instance.schedule(
        'home_post_startup',
        delay: const Duration(seconds: 2),
        task: () {
          if (mounted) {
            unawaited(AppUpdateService.instance.check(context, manual: false));
            unawaited(_precacheWalletPromoImages());
          }
        },
      );
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final theme = Provider.of<DefaultThemeData>(context).theme;
    final locale = Localizations.localeOf(context);
    if (!identical(_navIconThemeToken, theme) || _navIconLocale != locale) {
      _navIconThemeToken = theme;
      _navIconLocale = locale;
      _rebuildBottomNavIcons(theme);
    }
  }

  Future<void> _precacheWalletPromoImages() async {
    if (!mounted) {
      return;
    }
    try {
      final media = MediaQuery.of(context);
      final logicalWidth = math.max(1.0, media.size.width - 32.0);
      final decodeDpr = walletPromoDecodePixelRatio(media.devicePixelRatio);
      final dark = Provider.of<DefaultThemeData>(context, listen: false)
              .currentThemeType ==
          ThemeType.dark;
      final headerAsset =
          dark ? 'assets/img/card2.webp' : 'assets/img/card.webp';
      final inviteAsset =
          dark ? 'assets/img/invite2.webp' : 'assets/img/invite.webp';
      final headerSourceWidth = 1024;
      final inviteSourceWidth = dark ? 1829 : 1024;

      ImageProvider resizedAsset(String asset, int sourceWidth) {
        final cacheWidth = walletPromoCacheWidth(
          logicalWidth: logicalWidth,
          devicePixelRatio: decodeDpr,
          sourcePx: sourceWidth,
        );
        return ResizeImage.resizeIfNeeded(
          cacheWidth,
          null,
          AssetImage(asset),
        );
      }

      await Future.wait<void>([
        precacheImage(resizedAsset(headerAsset, headerSourceWidth), context),
        precacheImage(resizedAsset(inviteAsset, inviteSourceWidth), context),
      ]);
    } catch (_) {}
  }

  void _rebuildBottomNavIcons(theme) {
    final selectedColor = theme.primaryColor ?? CommonColor.primaryColor;
    final inactiveColor = _inactiveNavColor(theme);
    _navIconC2cSelected = Stack(
      clipBehavior: Clip.none,
      children: [
        ColorFiltered(
          child: Image.asset(
            "assets/chat_active.png",
            width: 24,
            height: 24,
          ),
          colorFilter: ColorFilter.mode(selectedColor, BlendMode.srcATop),
        ),
        Positioned(
          top: -5,
          left: 12,
          child: UnconstrainedBox(
            child: _buildConversationUnreadBadge(ConversationListScope.c2c),
          ),
        )
      ],
    );
    _navIconC2cUnselected = Stack(
      clipBehavior: Clip.none,
      children: [
        ColorFiltered(
          colorFilter: ColorFilter.mode(inactiveColor, BlendMode.srcATop),
          child: Image.asset(
            "assets/chat.png",
            width: 24,
            height: 24,
          ),
        ),
        Positioned(
          top: -5,
          left: 12,
          child: UnconstrainedBox(
            child: _buildConversationUnreadBadge(ConversationListScope.c2c),
          ),
        )
      ],
    );
    _navIconGroupSelected = Stack(
      clipBehavior: Clip.none,
      children: [
        ColorFiltered(
          child: Image.asset(
            "assets/group_conv.png",
            width: 24,
            height: 24,
          ),
          colorFilter: ColorFilter.mode(selectedColor, BlendMode.srcATop),
        ),
        Positioned(
          top: -5,
          left: 12,
          child: UnconstrainedBox(
            child: _buildConversationUnreadBadge(ConversationListScope.group),
          ),
        )
      ],
    );
    _navIconGroupUnselected = Stack(
      clipBehavior: Clip.none,
      children: [
        ColorFiltered(
          colorFilter: ColorFilter.mode(inactiveColor, BlendMode.srcATop),
          child: Image.asset(
            "assets/group_conv.png",
            width: 24,
            height: 24,
          ),
        ),
        Positioned(
          top: -5,
          left: 12,
          child: UnconstrainedBox(
            child: _buildConversationUnreadBadge(ConversationListScope.group),
          ),
        )
      ],
    );
    _navIconContactSelected = Stack(
      clipBehavior: Clip.none,
      children: [
        ColorFiltered(
          child: Image.asset(
            "assets/contact_active.png",
            width: 24,
            height: 24,
          ),
          colorFilter: ColorFilter.mode(selectedColor, BlendMode.srcATop),
        ),
        const Positioned(
          top: -5,
          left: 12,
          child: UnconstrainedBox(
            child: ContactUnreadBadge(
              width: 16,
              height: 16,
            ),
          ),
        )
      ],
    );
    _navIconContactUnselected = Stack(
      clipBehavior: Clip.none,
      children: [
        ColorFiltered(
          colorFilter: ColorFilter.mode(inactiveColor, BlendMode.srcATop),
          child: Image.asset(
            "assets/contact.png",
            width: 24,
            height: 24,
          ),
        ),
        const Positioned(
          top: -5,
          left: 12,
          child: UnconstrainedBox(
            child: ContactUnreadBadge(
              width: 16,
              height: 16,
            ),
          ),
        )
      ],
    );
    _navIconWalletSelected = ColorFiltered(
      colorFilter: ColorFilter.mode(selectedColor, BlendMode.srcATop),
      child: Image.asset(
        'assets/wallet.png',
        width: 24,
        height: 24,
      ),
    );
    _navIconWalletUnselected = ColorFiltered(
      colorFilter: ColorFilter.mode(inactiveColor, BlendMode.srcATop),
      child: Image.asset(
        'assets/wallet.png',
        width: 24,
        height: 24,
      ),
    );
    _navIconProfileSelected = ColorFiltered(
      child: Image.asset(
        "assets/profile_active.png",
        width: 24,
        height: 24,
      ),
      colorFilter: ColorFilter.mode(selectedColor, BlendMode.srcATop),
    );
    _navIconProfileUnselected = ColorFiltered(
      colorFilter: ColorFilter.mode(inactiveColor, BlendMode.srcATop),
      child: Image.asset(
        "assets/profile.png",
        width: 24,
        height: 24,
      ),
    );
  }

  Widget _getConversationPage() {
    return _conversationPage ??= Conversation(
      conversationController: _conversationController,
      listScope: ConversationListScope.c2c,
    );
  }

  Widget _getGroupConversationPage() {
    return _groupConversationPage ??= Conversation(
      conversationController: _groupConversationController,
      listScope: ConversationListScope.group,
    );
  }

  Widget _getContactPage() {
    return _contactPage ??= const Contact();
  }

  Widget _getWalletPage() {
    return _walletPage ??= WalletScreen(
      key: const ValueKey('wallet-main-tab'),
      embeddedInMainTab: true,
      activeTabIndexListenable: _activeTabIndex,
      mainTabIndex: 3,
    );
  }

  Widget _getProfilePage() {
    return _profilePage ??= MyProfile(
      onOpenWalletTab: () => _changePage(3, context),
    );
  }

  Future<void> _initNotifications() async {
    NotificationSettingsService.instance.endColdStartBannerSuppression();
    NotificationSettingsService.instance.setNotificationClickHandler(
      _handleClickNotification,
    );
    await NotificationSettingsService.instance.applyFromSettings();
  }

  void _handleClickNotification(
      {required String ext, String? groupID, String? userID}) async {
    if (NotificationPushText.isCallPush(ext: ext)) {
      return;
    }
    final payload = <String, dynamic>{
      if (ext.trim().isNotEmpty) 'ext': ext,
      if (groupID != null) 'groupID': groupID,
      if (userID != null) 'userID': userID,
    };
    await PushNotificationRouter.handleTap(
      rawData: payload,
      source: 'legacy_notification_click',
      openConversation: ({
        ext,
        conversationID,
        groupID,
        userID,
        required String source,
      }) {
        return NotificationSettingsService.instance
            .openConversationFromPushClick(
          ext: ext ?? '',
          conversationID: conversationID,
          groupID: groupID,
          userID: userID,
          source: source,
        );
      },
    );
  }

  Map<int, String> pageTitle(LocalSetting localSetting) {
    final i18n = AppI18n.of(context);
    return {
      0: ConnectStatusUi.formatConversationTabTitle(
        i18n: i18n,
        baseTitle: i18n.t(
          zhHans: '消息',
          zhHant: '訊息',
          en: 'Messages',
          ja: 'メッセージ',
          ko: '메시지',
        ),
        localSetting: localSetting,
      ),
      1: ConnectStatusUi.formatConversationTabTitle(
        i18n: i18n,
        baseTitle: i18n.t(
          zhHans: '群聊',
          zhHant: '群聊',
          en: 'Groups',
          ja: 'グループ',
          ko: '그룹',
        ),
        localSetting: localSetting,
      ),
      2: AppI18n.of(context).t(
        zhHans: '通讯录',
        zhHant: '通訊錄',
        en: 'Contacts',
        ja: '連絡先',
        ko: '연락처',
      ),
      3: AppI18n.of(context).t(
        zhHans: '钱包',
        zhHant: '錢包',
        en: 'Wallet',
        ja: 'ウォレット',
        ko: '지갑',
      ),
      4: AppI18n.of(context).t(
        zhHans: '我的',
        zhHant: '我的',
        en: 'Me',
        ja: 'マイページ',
        ko: '내 정보',
      ),
    };
  }

  Color _inactiveNavColor(theme) {
    return theme.weakTextColor ?? Colors.grey;
  }

  ConversationListScope? _conversationScopeForTab(int index) {
    if (index == 0) {
      return ConversationListScope.c2c;
    }
    if (index == 1) {
      return ConversationListScope.group;
    }
    return null;
  }

  Widget _buildConversationUnreadBadge(ConversationListScope scope) {
    return ConversationScopeUnreadBadge(scope: scope);
  }

  List<NavigationBarData> getBottomNavigatorList(BuildContext context, theme) {
    final List<NavigationBarData> bottomNavigatorList = [
      NavigationBarData(
        pageBuilder: () => _getConversationPage(),
        title: AppI18n.of(context).t(
          zhHans: '消息',
          zhHant: '訊息',
          en: 'Messages',
          ja: 'メッセージ',
          ko: '메시지',
        ),
        selectedIcon: _navIconC2cSelected,
        unselectedIcon: _navIconC2cUnselected,
      ),
      NavigationBarData(
        pageBuilder: () => _getGroupConversationPage(),
        title: AppI18n.of(context).t(
          zhHans: '群聊',
          zhHant: '群聊',
          en: 'Groups',
          ja: 'グループ',
          ko: '그룹',
        ),
        selectedIcon: _navIconGroupSelected,
        unselectedIcon: _navIconGroupUnselected,
      ),
      NavigationBarData(
        pageBuilder: () => _getContactPage(),
        title: AppI18n.of(context).t(
          zhHans: '通讯录',
          zhHant: '通訊錄',
          en: 'Contacts',
          ja: '連絡先',
          ko: '연락처',
        ),
        selectedIcon: _navIconContactSelected,
        unselectedIcon: _navIconContactUnselected,
      ),
      NavigationBarData(
        pageBuilder: () => _getWalletPage(),
        title: AppI18n.of(context).t(
          zhHans: '钱包',
          zhHant: '錢包',
          en: 'Wallet',
          ja: 'ウォレット',
          ko: '지갑',
        ),
        selectedIcon: _navIconWalletSelected,
        unselectedIcon: _navIconWalletUnselected,
      ),
      NavigationBarData(
        pageBuilder: () => _getProfilePage(),
        title: AppI18n.of(context).t(
          zhHans: '我的',
          zhHant: '我的',
          en: 'Me',
          ja: 'マイページ',
          ko: '내 정보',
        ),
        selectedIcon: _navIconProfileSelected,
        unselectedIcon: _navIconProfileUnselected,
      ),
    ];

    return bottomNavigatorList;
  }

  List<NavigationBarData> bottomNavigatorList(theme) {
    return getBottomNavigatorList(context, theme);
  }

  ///关闭
  close() {
    Navigator.of(context).pop();
  }

  Widget _buildAppBarTitleText(
    LocalSetting localSetting,
    theme, {
    required bool isDesktop,
  }) {
    final titleColor = theme.appbarTextColor ??
        theme.darkTextColor ??
        AppTokens.textPrimaryLight;
    final isMainTab = currentIndex >= 0 && currentIndex <= 4;
    final titleFontSize = isMainTab
        ? (isDesktop
            ? IMDemoConfig.mainTabAppBarTitleFontSizeDesktop
            : IMDemoConfig.mainTabAppBarTitleFontSize)
        : IMDemoConfig.appBarTitleFontSize;
    final titleStyle = TextStyle(
      color: titleColor,
      fontSize: titleFontSize,
      fontWeight: isMainTab ? FontWeight.w700 : FontWeight.w600,
      height: 1.0,
    );

    if (isMainTab) {
      final indicator =
          ConnectStatusUi.conversationTabConnectIndicator(localSetting);
      // 未就绪：五个主 Tab 标题都显示「正在连接」+ 转圈；失败：错误图标。
      if (indicator != ConversationTabConnectIndicator.ready) {
        final adornmentSize = titleFontSize * 0.72;
        if (indicator == ConversationTabConnectIndicator.failed) {
          return Icon(
            Icons.error_outline_rounded,
            size: adornmentSize,
            color: titleColor.withValues(alpha: 0.72),
          );
        }
        final i18n = AppI18n.of(context);
        final connectingLabel = i18n.t(
          zhHans: '正在连接',
          zhHant: '正在連線',
          en: 'Connecting',
          ja: '接続中',
          ko: '연결 중',
        );
        final spinnerColor = theme.primaryColor ?? AppTokens.accent;
        return Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(connectingLabel, style: titleStyle),
            const SizedBox(width: 8),
            FadingArcSpinner(
              size: adornmentSize,
              color: spinnerColor,
              strokeWidth: math.max(2.2, adornmentSize * 0.12),
            ),
          ],
        );
      }
    }

    return Text(
      pageTitle(localSetting)[currentIndex]!,
      style: titleStyle,
    );
  }

  Widget? getTitle(LocalSetting localSetting, theme) {
    final isDesktop =
        TUIKitScreenUtils.getFormFactor(context) == DeviceType.Desktop;
    final accentColor = theme.primaryColor ?? AppTokens.accent;
    final indicatorWidth = isDesktop ? 36.0 : 32.0;
    final indicatorHeight = 4.0;
    final indicatorDotSize = 8.0;
    const titleGap = 2.0;
    final showTitleDecoration =
        ConnectStatusUi.conversationTabConnectIndicator(localSetting) ==
            ConversationTabConnectIndicator.ready;
    final titleWidget = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildAppBarTitleText(localSetting, theme, isDesktop: isDesktop),
        if (showTitleDecoration) ...[
          SizedBox(height: titleGap),
          Transform.translate(
            offset: const Offset(0, -2),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: indicatorWidth,
                  height: indicatorHeight,
                  decoration: BoxDecoration(
                    color: accentColor,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  width: indicatorDotSize,
                  height: indicatorDotSize,
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.78),
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
    final tapTarget = Padding(
      padding: const EdgeInsets.only(top: 4),
      child: titleWidget,
    );
    final scope = _conversationScopeForTab(currentIndex);
    if (scope == null) {
      return tapTarget;
    }
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onDoubleTap: () {
        conversationScrollToTopActions[scope]?.call();
      },
      child: tapTarget,
    );
  }

  Widget _buildHeaderIconButton({
    IconData? icon,
    Widget? customIcon,
    required VoidCallback onPressed,
    required Color color,
    bool showDot = false,
  }) {
    final tapSize =
        AppResponsive.controlHeight(context, mobile: 48, desktop: 44);
    final iconSize = context.isDesktopFormFactor ? 22.0 : 24.0;
    final dotSize = 8.0;
    return IconButton(
      onPressed: onPressed,
      padding: EdgeInsets.zero,
      constraints: BoxConstraints(minWidth: tapSize, minHeight: tapSize),
      icon: Stack(
        clipBehavior: Clip.none,
        children: [
          customIcon ??
              Icon(
                icon,
                size: iconSize,
                color: color,
              ),
          if (showDot)
            Positioned(
              right: 2,
              top: -2,
              child: DecoratedBox(
                decoration: const BoxDecoration(
                  color: Color(0xFFFF4D5D),
                  shape: BoxShape.circle,
                ),
                child: SizedBox(width: dotSize, height: dotSize),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDecorativeBackground({required bool isDark}) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: isDark ? Alignment.topLeft : Alignment.topCenter,
          end: isDark ? Alignment.bottomRight : Alignment.bottomCenter,
          colors: isDark
              ? kDecorativePageGradientColorsDark
              : kDecorativePageGradientColorsLight,
          stops: isDark ? kDecorativePageGradientStopsDark : null,
        ),
      ),
    );
  }

  Widget _buildTopSparkles({required bool isDark}) {
    return IgnorePointer(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final height = constraints.maxHeight;
          return Stack(
            children: [
              Positioned(
                left: width * 0.19,
                top: height * 0.30,
                child: _DecorativeSparkle(
                  size: width * 0.022,
                  opacity: isDark ? 0.42 : 0.58,
                  isDark: isDark,
                ),
              ),
              Positioned(
                left: width * 0.33,
                top: height * 0.52,
                child: _DecorativeSparkle(
                  size: width * 0.034,
                  opacity: isDark ? 0.48 : 0.62,
                  isDark: isDark,
                ),
              ),
              Positioned(
                right: width * 0.18,
                top: height * 0.36,
                child: _DecorativeSparkle(
                  size: width * 0.024,
                  opacity: isDark ? 0.38 : 0.52,
                  isDark: isDark,
                ),
              ),
              Positioned(
                right: width * 0.34,
                top: height * 0.70,
                child: _DecorativeSparkle(
                  size: width * 0.014,
                  opacity: isDark ? 0.32 : 0.42,
                  isDark: isDark,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _handleHomeSettingsLogout() async {
    await AccountSessionService.instance.clearForLogout(
      reason: 'home_settings_logout',
    );
    if (mounted) {
      InitStep.directToLogin(context);
    }
  }

  _handleTapTooltipItem(String id) {
    switch (id) {
      case "searchAdd":
        Navigator.of(context).push(
          AppMaterialPageRoute(
            builder: (context) => const SearchAddPage(),
          ),
        );
        break;
      case "addFriend":
        Navigator.of(context).push(
          AppMaterialPageRoute(
            builder: (context) => const SearchAddPage(),
          ),
        );
        break;
      case "addGroup":
        Navigator.of(context).push(
          AppMaterialPageRoute(
            builder: (context) => const SearchAddPage(),
          ),
        );
        break;
      case "createGroup":
        Navigator.of(context).push(
          AppMaterialPageRoute(
            builder: (context) => const CreateGroup(
              convType: GroupTypeForUIKit.community,
            ),
          ),
        );
        break;
      case "scanQRCode":
        QRScannerLauncher.open(context);
        break;
    }
  }

  Widget _buildTooltipIcon(Map e, theme) {
    final icon = e["icon"];
    if (icon is IconData) {
      return Icon(
        icon,
        size: 21,
        color: theme.primaryColor ?? AppTokens.accent,
      );
    }
    return ColorFiltered(
      colorFilter: ColorFilter.mode(
        theme.primaryColor ?? AppTokens.accent,
        BlendMode.srcATop,
      ),
      child: Image.asset(
        e["asset"]!,
        width: 21,
        height: 21,
      ),
    );
  }

  List<PopupMenuEntry<String>> _getTooltipMenus(BuildContext context, theme) {
    List toolTipList = currentIndex == 2
        ? _contactTooltip(context)
        : _conversationTooltip(context);

    return toolTipList.map((e) {
      return PopupMenuItem<String>(
        value: e["id"]!,
        child: Row(
          children: [
            _buildTooltipIcon(e, theme),
            const SizedBox(width: 12),
            Text(
              e['label']!,
              style: TextStyle(color: theme.darkTextColor),
            ),
          ],
        ),
      );
    }).toList();
  }

  void _rotatePlusIconClockwise() {
    if (!mounted) return;
    setState(() => _plusIconTurns += 0.25);
  }

  Widget _buildPlusMenuIconButton(VoidCallback onPressed) {
    return IconButton(
      key: _plusActionKey,
      onPressed: onPressed,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
      icon: HomeNavPlusIcon(turns: _plusIconTurns),
    );
  }

  Future<void> _showTooltip(BuildContext context) async {
    _rotatePlusIconClockwise();
    final theme = Provider.of<DefaultThemeData>(context, listen: false).theme;
    final menuIsDark = ThemeData.estimateBrightnessForColor(
          theme.selectPanelBgColor ??
              theme.conversationItemBgColor ??
              AppColors.card(dark: false),
        ) ==
        Brightness.dark;
    final RenderBox button =
        _plusActionKey.currentContext!.findRenderObject() as RenderBox;
    final RenderBox overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox;
    final Offset offset = button.localToGlobal(Offset.zero, ancestor: overlay);
    final selected = await showMenu<String>(
      context: context,
      color: theme.selectPanelBgColor ??
          theme.conversationItemBgColor ??
          theme.appbarBgColor ??
          AppColors.card(dark: menuIsDark),
      shadowColor: Colors.black.withValues(alpha: 0.16),
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTokens.rLg),
        side: BorderSide(
          color: theme.weakDividerColor ?? AppColors.line(dark: menuIsDark),
        ),
      ),
      position: RelativeRect.fromLTRB(
        offset.dx,
        offset.dy + button.size.height + 6,
        overlay.size.width - offset.dx - button.size.width,
        0,
      ),
      items: _getTooltipMenus(context, theme),
    );
    if (!mounted) return;
    _rotatePlusIconClockwise();
    if (selected != null) {
      _handleTapTooltipItem(selected);
    }
  }

  Widget _buildCustomerServiceAction(theme) {
    return ValueListenableBuilder<bool>(
      valueListenable: conversationEditingNotifier,
      builder: (context, isEditing, child) {
        if (isEditing) {
          return const SizedBox.shrink();
        }
        return IconButton(
          onPressed: () => CustomerServiceNav.open(context),
          tooltip: AppI18n.of(context).t(
            zhHans: '在线客服',
            zhHant: '線上客服',
            en: 'Customer Service',
            ja: 'オンラインサポート',
            ko: '고객센터',
          ),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
          icon: SvgPicture.string(
            customerServiceIconSvg,
            width: 26,
            height: 26,
            fit: BoxFit.contain,
            colorFilter: ColorFilter.mode(
              theme.primaryColor ?? AppTokens.accent,
              BlendMode.srcIn,
            ),
          ),
        );
      },
    );
  }

  List<Widget> _buildAppBarActions(theme, {required bool isDark}) {
    final actionIconColor =
        theme.appbarTextColor ?? AppColors.text(dark: isDark);
    final conversationScope = _conversationScopeForTab(currentIndex);
    if (conversationScope != null) {
      return [
        _buildCustomerServiceAction(theme),
        ValueListenableBuilder<bool>(
          valueListenable: conversationEditingNotifier,
          builder: (context, isEditing, child) {
            if (!isEditing) {
              return IconButton(
                onPressed: () {
                  conversationToggleEditModeActions[conversationScope]?.call();
                },
                icon: SvgPicture.string(
                  archivedEditIconSvg,
                  width: 24,
                  height: 24,
                ),
              );
            }
            // 编辑态只允许手动勾选，不再提供「全选」。
            return const SizedBox.shrink();
          },
        ),
        ValueListenableBuilder<bool>(
          valueListenable: conversationEditingNotifier,
          builder: (context, isEditing, child) {
            if (isEditing) {
              return TextButton(
                onPressed: () {
                  conversationToggleEditModeActions[conversationScope]?.call();
                },
                child: Text(
                  AppI18n.of(context).t(
                    zhHans: '完成',
                    zhHant: '完成',
                    en: 'Done',
                    ja: '完了',
                    ko: '완료',
                  ),
                  style: TextStyle(
                    color: theme.primaryColor ?? AppTokens.accent,
                  ),
                ),
              );
            }
            return Builder(builder: (BuildContext c) {
              return _buildPlusMenuIconButton(() => _showTooltip(c));
            });
          },
        ),
      ];
    }
    if (currentIndex == 2) {
      return [
        Builder(builder: (BuildContext c) {
          return _buildPlusMenuIconButton(() => _showTooltip(c));
        }),
      ];
    }
    if (currentIndex == 3) {
      final screenWidth = MediaQuery.sizeOf(context).width;
      return [
        _buildHeaderIconButton(
          color: actionIconColor,
          customIcon: _WalletScanIcon(
            size: screenWidth * 0.058,
            color: actionIconColor,
          ),
          onPressed: () => QRScannerLauncher.open(context),
        ),
        _buildHeaderIconButton(
          color: actionIconColor,
          icon: Icons.notifications_none_rounded,
          onPressed: () {
            Navigator.push(
              context,
              AppMaterialPageRoute(
                builder: (context) => const NotificationSettingsPage(),
              ),
            );
          },
        ),
        SizedBox(width: screenWidth * 0.020),
      ];
    }
    if (currentIndex == 4) {
      final screenWidth = MediaQuery.sizeOf(context).width;
      return [
        _buildHeaderIconButton(
          color: actionIconColor,
          icon: Icons.settings_outlined,
          onPressed: () {
            Navigator.push(
              context,
              AppMaterialPageRoute(
                builder: (context) => SettingsPage(
                  onLogout: _handleHomeSettingsLogout,
                ),
              ),
            );
          },
        ),
        SizedBox(width: screenWidth * 0.030),
      ];
    }
    return const [];
  }

  //如果点击的导航页不是当前项，切换
  void _changePage(int index, BuildContext context) {
    if (index != currentIndex) {
      if (index == 4) {
        unawaited(getLoginUserInfo());
      }
      unawaited(_switchHomeTab(index));
    }
  }

  Future<void> _switchHomeTab(int index) async {
    OrphanOverlayGuard.scheduleCleanup(
      reason: 'home_tab_switch',
      dismissInAppBanner: true,
    );
    DeviceSyncService.instance.setHomeTabIndex(index);
    _activeTabIndex.value = index;
    if (index == _contactTabIndex) {
      // Paint Tab immediately; sync joins single-flight with list widget enter.
      FriendRequestNoticeService.instance.onHomeTabChanged(
        index,
        skipDataSourceEnter: true,
      );
      unawaited(
        FriendRequestNoticeService.instance.enterContactDataSource(
          reason: 'contact_tab',
        ),
      );
    } else {
      FriendRequestNoticeService.instance.onHomeTabChanged(index);
    }
    if (!mounted) {
      return;
    }
    setState(() {
      currentIndex = index;
      _visitedTabs.add(index);
      if (index == 2) {
        pageName = 'concat';
      }
      if (index == 3) {
        pageName = 'wallet';
      }
      if (index == 4) {
        pageName = 'userProfile';
      }
    });
  }

  static const int _contactTabIndex = 2;

  Widget _buildTabStack(List<NavigationBarData> navItems) {
    return IndexedStack(
      index: currentIndex,
      children: List.generate(navItems.length, (index) {
        final shouldBuild =
            _visitedTabs.contains(index) || index == currentIndex;
        return TickerMode(
          enabled: currentIndex == index,
          child: IgnorePointer(
            ignoring: currentIndex != index,
            child: RepaintBoundary(
              child: shouldBuild
                  ? (navItems[index].pageBuilder?.call() ??
                      const SizedBox.shrink())
                  : const SizedBox.shrink(),
            ),
          ),
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final LocalSetting localSetting = Provider.of<LocalSetting>(context);
    final themeModel = Provider.of<DefaultThemeData>(context);
    final theme = themeModel.theme;
    final navItems = bottomNavigatorList(theme);
    final routeVisible = RouteVisibility.isRouteVisible(context);
    final useDecorativeBackground = currentIndex == 3 || currentIndex == 4;
    final isDarkBackground = themeModel.currentThemeType == ThemeType.dark;
    final pageBackgroundColor = useDecorativeBackground
        ? AppColors.background(dark: isDarkBackground)
        : (theme.weakBackgroundColor ??
            AppColors.background(dark: isDarkBackground));
    final appBarBackgroundColor = useDecorativeBackground
        ? Colors.transparent
        : (theme.appbarBgColor ?? AppColors.card(dark: isDarkBackground));
    final appBarTextColor =
        theme.appbarTextColor ?? AppColors.text(dark: isDarkBackground);
    final overlayStyle = useDecorativeBackground
        ? decorativeMainTabOverlayStyle(
            dark: isDarkBackground,
            navigationBarBackground: pageBackgroundColor,
          )
        : immersiveOverlayForColors(
            statusBarBackground: appBarBackgroundColor,
            navigationBarBackground: pageBackgroundColor,
          );
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: overlayStyle,
      child: TencentPage(
          child: Scaffold(
              extendBody: false,
              extendBodyBehindAppBar: false,
              backgroundColor: pageBackgroundColor,
              appBar: AppBar(
                backgroundColor: appBarBackgroundColor,
                surfaceTintColor: Colors.transparent,
                iconTheme: IconThemeData(
                  color: appBarTextColor,
                ),
                shadowColor: Colors.transparent,
                elevation: 0,
                scrolledUnderElevation: 0,
                systemOverlayStyle: overlayStyle,
                automaticallyImplyLeading: false,
                leading: null,
                title: AnimatedBuilder(
                  animation: Listenable.merge([
                    LoginCoordinator.instance,
                    AuthBootstrapService.instance.backgroundSyncing,
                    localSetting,
                    NetworkStatusService.instance.status,
                    ImConnectStatusService.instance,
                  ]),
                  builder: (context, _) =>
                      getTitle(localSetting, theme) ?? const SizedBox.shrink(),
                ),
                centerTitle: false,
                flexibleSpace: useDecorativeBackground
                    ? _buildTopSparkles(isDark: isDarkBackground)
                    : Container(
                        color: theme.appbarBgColor ??
                            AppColors.card(dark: isDarkBackground),
                      ),
                actions: _buildAppBarActions(
                  theme,
                  isDark: isDarkBackground,
                ),
              ),
              body: Stack(
                fit: StackFit.expand,
                children: [
                  if (useDecorativeBackground)
                    Align(
                      alignment: Alignment.topCenter,
                      child: FractionallySizedBox(
                        widthFactor: 1,
                        heightFactor: 1,
                        alignment: Alignment.topCenter,
                        child: _buildDecorativeBackground(
                          isDark: isDarkBackground,
                        ),
                      ),
                    ),
                  Column(
                    children: [
                      Expanded(
                        child: Listener(
                          behavior: HitTestBehavior.translucent,
                          onPointerDown: (_) {
                            DeviceSyncService.instance.markUserActive();
                          },
                          child: TickerMode(
                            enabled: routeVisible,
                            child: _buildTabStack(navItems),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              bottomNavigationBar: ValueListenableBuilder<bool>(
                valueListenable: conversationEditingNotifier,
                builder: (context, isEditing, child) {
                  if (isEditing) {
                    return const SizedBox.shrink();
                  }
                  // Content row 48 (+ device safe-bottom). Labels stay 11pt.
                  const tabContentHeight = 48.0;
                  final safeBottom = MediaQuery.paddingOf(context).bottom;
                  final barBg = theme.conversationItemBgColor ??
                      theme.weakBackgroundColor;
                  return PreferredSize(
                    preferredSize:
                        Size.fromHeight(tabContentHeight + safeBottom),
                    child: ColoredBox(
                      color: barBg ?? Theme.of(context).scaffoldBackgroundColor,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            height: tabContentHeight,
                            child: MediaQuery.removePadding(
                              context: context,
                              removeBottom: true,
                              child: Theme(
                                data: Theme.of(context).copyWith(
                                  splashFactory: NoSplash.splashFactory,
                                  highlightColor: Colors.transparent,
                                  splashColor: Colors.transparent,
                                  hoverColor: Colors.transparent,
                                ),
                                child: BottomNavigationBar(
                                  items: List.generate(
                                    navItems.length,
                                    (index) => BottomNavigationBarItem(
                                      icon: index == currentIndex
                                          ? navItems[index].selectedIcon
                                          : navItems[index].unselectedIcon,
                                      label: navItems[index].title,
                                    ),
                                  ),
                                  currentIndex: currentIndex,
                                  type: BottomNavigationBarType.fixed,
                                  selectedFontSize: 11,
                                  unselectedFontSize: 11,
                                  onTap: (index) {
                                    _changePage(index, context);
                                    if (isNeedMoveToConversation) {
                                      final scope =
                                          _conversationScopeForTab(index);
                                      if (scope != null &&
                                          currentIndex == index) {
                                        conversationScrollNextUnreadActions[
                                                scope]
                                            ?.call();
                                      }
                                    }
                                    isNeedMoveToConversation = true;
                                    Future.delayed(
                                        const Duration(milliseconds: 300), () {
                                      isNeedMoveToConversation = false;
                                    });
                                  },
                                  selectedItemColor: theme.primaryColor,
                                  unselectedItemColor:
                                      theme.weakTextColor ?? Colors.grey,
                                  backgroundColor: barBg,
                                  elevation: 0,
                                ),
                              ),
                            ),
                          ),
                          SizedBox(height: safeBottom),
                        ],
                      ),
                    ),
                  );
                },
              )),
          name: pageName),
    );
  }
}

/// 底部导航栏数据对象
class _DecorativeSparkle extends StatelessWidget {
  const _DecorativeSparkle({
    required this.size,
    required this.opacity,
    required this.isDark,
  });

  final double size;
  final double opacity;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: opacity,
      child: Transform.rotate(
        angle: 0.78,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: isDark
                ? const Color(0xFF8EBBFF).withValues(alpha: 0.55)
                : Colors.white,
            borderRadius: BorderRadius.circular(size * 0.18),
            boxShadow: defaultTargetPlatform == TargetPlatform.android
                ? const <BoxShadow>[]
                : [
                    BoxShadow(
                      color: const Color(0xFF8EBBFF)
                          .withValues(alpha: isDark ? 0.28 : 0.20),
                      blurRadius: size,
                    ),
                  ],
          ),
          child: SizedBox(
            width: size,
            height: size,
          ),
        ),
      ),
    );
  }
}

class _WalletScanIcon extends StatelessWidget {
  const _WalletScanIcon({
    required this.size,
    required this.color,
  });

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.square(size),
      painter: _WalletScanIconPainter(color: color),
    );
  }
}

class _WalletScanIconPainter extends CustomPainter {
  _WalletScanIconPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.078
      ..strokeCap = StrokeCap.round;
    final w = size.width;
    final h = size.height;
    final corner = w * 0.29;
    final inset = w * 0.12;

    canvas.drawLine(Offset(inset, corner), Offset(inset, inset), stroke);
    canvas.drawLine(Offset(inset, inset), Offset(corner, inset), stroke);
    canvas.drawLine(
        Offset(w - corner, inset), Offset(w - inset, inset), stroke);
    canvas.drawLine(
        Offset(w - inset, inset), Offset(w - inset, corner), stroke);
    canvas.drawLine(
        Offset(w - inset, h - corner), Offset(w - inset, h - inset), stroke);
    canvas.drawLine(
        Offset(w - inset, h - inset), Offset(w - corner, h - inset), stroke);
    canvas.drawLine(
        Offset(corner, h - inset), Offset(inset, h - inset), stroke);
    canvas.drawLine(
        Offset(inset, h - inset), Offset(inset, h - corner), stroke);
    canvas.drawLine(
      Offset(w * 0.36, h * 0.50),
      Offset(w * 0.64, h * 0.50),
      stroke,
    );
  }

  @override
  bool shouldRepaint(covariant _WalletScanIconPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

class NavigationBarData {
  /// 未选择时候的图标
  final Widget unselectedIcon;

  /// 选择后的图标
  final Widget selectedIcon;

  /// 标题内容
  final String title;

  /// 页面构建器
  final Widget Function()? pageBuilder;

  final ValueChanged<int>? onTap;

  final int? index;

  NavigationBarData(
      {required this.unselectedIcon,
      required this.selectedIcon,
      required this.title,
      this.pageBuilder,
      this.onTap,
      this.index});
}
