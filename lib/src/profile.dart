import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import 'package:tencent_cloud_chat_demo/src/about.dart';
import 'package:tencent_cloud_chat_demo/src/i18n/app_i18n.dart';
import 'package:tencent_cloud_chat_demo/src/my_profile_detail.dart';
import 'package:tencent_cloud_chat_demo/src/pages/favorites/favorite_list_page.dart';
import 'package:tencent_cloud_chat_demo/src/pages/life_payment/life_payment_page.dart';
import 'package:tencent_cloud_chat_demo/src/pages/moments/moments_page.dart';
import 'package:tencent_cloud_chat_demo/src/services/moments/moments_settings_service.dart';
import 'package:tencent_cloud_chat_demo/src/pages/recent_calls_page.dart';
import 'package:tencent_cloud_chat_demo/src/pages/settings/notification_settings_page.dart';
import 'package:tencent_cloud_chat_demo/src/pages/settings/settings_page.dart';
import 'package:tencent_cloud_chat_demo/src/pages/share/share_app_sheet.dart';
import 'package:tencent_cloud_chat_demo/utils/navigation_routes.dart';
import 'package:tencent_cloud_chat_demo/src/provider/login_user_Info.dart';
import 'package:tencent_cloud_chat_demo/src/qr_code_page.dart';
import 'package:tencent_cloud_chat_demo/src/provider/theme.dart';
import 'package:tencent_cloud_chat_demo/utils/init_step.dart';
import 'package:tencent_cloud_chat_demo/utils/theme.dart';
import 'package:tencent_cloud_chat_demo/src/profile_menu_icons.dart';
import 'package:tencent_cloud_chat_demo/src/services/auth_bootstrap_service.dart';
import 'package:tencent_cloud_chat_demo/src/services/account_session_service.dart';
import 'package:tencent_cloud_chat_demo/utils/chat_id_format.dart';
import 'package:tencent_cloud_chat_demo/utils/toast.dart';
import 'package:tencent_cloud_chat_sdk/manager/v2_tim_manager.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_conversation.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_conversation.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_friend_info.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_friend_info.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_user_full_info.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_user_full_info.dart';
import 'package:tencent_cloud_chat_uikit/tencent_cloud_chat_uikit.dart';
import 'package:tencent_cloud_chat_demo/src/api/auth_api.dart';
import 'package:tencent_cloud_chat_demo/src/widgets/app_user_avatar.dart';
import 'package:tencent_cloud_chat_demo/src/theme/app_colors.dart';
import 'package:tencent_cloud_chat_demo/src/ui/app_tokens.dart';
import 'package:tencent_cloud_chat_demo/utils/user_avatar.dart';
import 'package:adaptive_action_sheet/adaptive_action_sheet.dart';
import 'package:tencent_cloud_chat_demo/src/navigation/app_page_transitions.dart';
import 'package:tencent_cloud_chat_demo/src/widgets/app_dialog.dart';

const String _profileEcoGameAsset = 'assets/img/ai.webp';
const String _profileEcoShopAsset = 'assets/img/shop.webp';
const String _profileEcoWalletAsset = 'assets/img/wallet.webp';
const String _profileEcoCommunityAsset = 'assets/img/community.webp';

class _HotEcoItem {
  const _HotEcoItem({
    required this.title,
    required this.asset,
    required this.action,
  });

  final String title;
  final String asset;
  final _HotEcoAction action;
}

enum _HotEcoAction {
  game,
  shop,
  wallet,
  community,
}

class _HotEcoTile extends StatefulWidget {
  const _HotEcoTile({
    required this.item,
    required this.onTap,
    required this.delay,
  });

  final _HotEcoItem item;
  final VoidCallback onTap;
  final Duration delay;

  @override
  State<_HotEcoTile> createState() => _HotEcoTileState();
}

class _HotEcoTileState extends State<_HotEcoTile>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _sweep;
  Timer? _delayTimer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2100),
    );
    _sweep = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOutCubic,
    );
    _delayTimer = Timer(widget.delay, () {
      if (!mounted) return;
      _controller.repeat(period: const Duration(milliseconds: 3600));
    });
  }

  @override
  void dispose() {
    _delayTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 0.78,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final tileWidth = constraints.maxWidth;
          final radius = tileWidth * 0.12;
          return Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(radius),
              onTap: widget.onTap,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(radius),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final tileWidth = constraints.maxWidth;
                    // 窄屏四列时标题易被裁切：收紧箭头/边距，并用 FittedBox 兜底。
                    final edgeInset = tileWidth * 0.06;
                    final arrowSize = tileWidth * 0.16;
                    final arrowBottom = tileWidth * 0.10;
                    final titleFontSize = tileWidth * 0.11;
                    final labelGap = tileWidth * 0.03;

                    return Stack(
                      fit: StackFit.expand,
                      children: [
                        Transform.scale(
                          scale: 1.34,
                          child: Image.asset(
                            widget.item.asset,
                            fit: BoxFit.cover,
                            alignment: Alignment.center,
                          ),
                        ),
                        _HotEcoLightSweep(animation: _sweep),
                        Positioned(
                          left: edgeInset,
                          bottom: arrowBottom,
                          right: edgeInset,
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Container(
                                width: arrowSize,
                                height: arrowSize,
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.35),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.75),
                                    width: arrowSize * 0.06,
                                  ),
                                ),
                                child: Icon(
                                  Icons.arrow_forward_rounded,
                                  color: Colors.white,
                                  size: arrowSize * 0.68,
                                ),
                              ),
                              SizedBox(width: labelGap),
                              Expanded(
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    widget.item.title,
                                    maxLines: 1,
                                    softWrap: false,
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: titleFontSize,
                                      fontWeight: FontWeight.w700,
                                      height: 1.1,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _HotEcoLightSweep extends StatelessWidget {
  const _HotEcoLightSweep({required this.animation});

  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: animation,
        builder: (context, child) {
          final dx = -1.35 + animation.value * 2.7;
          return FractionalTranslation(
            translation: Offset(dx, 0),
            child: Transform.rotate(
              angle: -0.32,
              child: Align(
                alignment: Alignment.center,
                child: FractionallySizedBox(
                  widthFactor: 0.42,
                  heightFactor: 1.45,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: [
                          Colors.white.withValues(alpha: 0),
                          Colors.white.withValues(alpha: 0.10),
                          Colors.white.withValues(alpha: 0.34),
                          Colors.white.withValues(alpha: 0.10),
                          Colors.white.withValues(alpha: 0),
                        ],
                        stops: const [0, 0.28, 0.5, 0.72, 1],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class MyProfile extends StatefulWidget {
  const MyProfile({
    Key? key,
    required this.onOpenWalletTab,
  }) : super(key: key);

  final VoidCallback onOpenWalletTab;

  @override
  State<StatefulWidget> createState() => _ProfileState();
}

class _ProfileState extends State<MyProfile> {
  final V2TIMManager sdkInstance = TIMUIKitCore.getSDKInstance();
  final TIMUIKitProfileController _timuiKitProfileController =
      TIMUIKitProfileController();
  String _backendAvatarUrl = '';
  String _backendUserId = '';

  @override
  void initState() {
    super.initState();
    AuthBootstrapService.instance.backgroundSyncing
        .addListener(_handleBackgroundSyncChanged);
    _loadBackendAvatar();
    unawaited(_refreshLoginUserInfoFromIm());
  }

  Future<void> _loadBackendAvatar() async {
    try {
      final me = await AuthApi.instance.fetchMe();
      if (!mounted) return;
      setState(() {
        _backendAvatarUrl = me.avatarUrl?.trim() ?? '';
        _backendUserId = me.userId.trim();
      });
    } catch (_) {}
  }

  @override
  void dispose() {
    AuthBootstrapService.instance.backgroundSyncing
        .removeListener(_handleBackgroundSyncChanged);
    super.dispose();
  }

  void _handleBackgroundSyncChanged() {
    if (AuthBootstrapService.instance.backgroundSyncing.value) {
      return;
    }
    unawaited(_refreshLoginUserInfoFromIm());
  }

  Future<void> _refreshLoginUserInfoFromIm() async {
    if (!mounted || kIsWeb) {
      return;
    }
    try {
      final res = await sdkInstance.getLoginUser();
      final userId = res.data?.trim() ?? '';
      if (res.code != 0 || userId.isEmpty) {
        return;
      }
      final result = await sdkInstance.getUsersInfo(userIDList: [userId]);
      if (!mounted) return;
      if (result.code == 0 && result.data != null && result.data!.isNotEmpty) {
        final loginUserInfoModel =
            Provider.of<LoginUserInfo>(context, listen: false);
        final fetched = result.data![0];
        _mergeLoginUserInfo(loginUserInfoModel.loginUserInfo, fetched);
        loginUserInfoModel.setLoginUserInfo(fetched);
      }
    } catch (_) {}
  }

  void _mergeLoginUserInfo(
    V2TimUserFullInfo current,
    V2TimUserFullInfo fetched,
  ) {
    final currentNick = current.nickName?.trim() ?? '';
    if (currentNick.isNotEmpty) {
      fetched.nickName = current.nickName;
    }
  }

  String _resolveDisplayNickname(
    V2TimUserFullInfo? userProfile,
    V2TimUserFullInfo loginUserInfo,
  ) {
    if (TencentUtils.isTextNotEmpty(loginUserInfo.nickName)) {
      return loginUserInfo.nickName!;
    }
    if (TencentUtils.isTextNotEmpty(userProfile?.nickName)) {
      return userProfile!.nickName!;
    }
    return AppI18n.of(context).t(
      zhHans: '未填写昵称',
      zhHant: '未填寫暱稱',
      en: 'No nickname',
      ja: 'ニックネーム未設定',
      ko: '닉네임 없음',
    );
  }

  String _resolveProfileUserId(V2TimUserFullInfo loginUserInfo) {
    final imUserId = loginUserInfo.userID?.trim() ?? '';
    if (imUserId.isNotEmpty) {
      return imUserId;
    }
    return _backendUserId;
  }

  String _displayAvatarUrl(
    V2TimUserFullInfo? userProfile,
    V2TimUserFullInfo loginUserInfo,
  ) {
    final imFaceUrl = TencentUtils.isTextNotEmpty(loginUserInfo.faceUrl)
        ? loginUserInfo.faceUrl
        : userProfile?.faceUrl;
    return UserAvatarHelper.pickBestPreferBackend(
      imFaceUrl: imFaceUrl,
      backendAvatarUrl: _backendAvatarUrl,
    );
  }

  String _getAllowText(int? allowType) {
    if (allowType == 0) {
      return AppI18n.of(context).t(
        zhHans: '允许任何人',
        zhHant: '允許任何人',
        en: 'Allow Anyone',
        ja: '誰でも追加可能',
        ko: '누구나 추가 가능',
      );
    }
    if (allowType == 1) {
      return AppI18n.of(context).t(
        zhHans: '需要验证信息',
        zhHant: '需要驗證資訊',
        en: 'Require Verification',
        ja: '承認が必要',
        ko: '인증 필요',
      );
    }
    if (allowType == 2) {
      return AppI18n.of(context).t(
        zhHans: '需要验证信息',
        zhHant: '需要驗證資訊',
        en: 'Require Verification',
        ja: '承認が必要',
        ko: '인증 필요',
      );
    }
    return AppI18n.of(context).t(
      zhHans: '未指定',
      zhHant: '未指定',
      en: 'Not Specified',
      ja: '未指定',
      ko: '지정 안 됨',
    );
  }

  Future<void> _handleLogout() async {
    await AccountSessionService.instance
        .clearForLogout(reason: 'profile_logout');
    if (mounted) {
      InitStep.directToLogin(context);
    }
  }

  void changeFriendVerificationMethod(int allowType) {
    _timuiKitProfileController.changeFriendVerificationMethod(allowType);
  }

  Future<void> showApplicationTypeSheet(Color textColor) async {
    const allowAny = 0;
    const needConfirm = 1;
    showAdaptiveActionSheet(
      context: context,
      actions: <BottomSheetAction>[
        BottomSheetAction(
          title: Text(
            AppI18n.of(context).t(
              zhHans: '允许任何人',
              zhHant: '允許任何人',
              en: 'Allow Anyone',
              ja: '誰でも追加可能',
              ko: '누구나 추가 가능',
            ),
            style: TextStyle(color: textColor, fontSize: 18),
          ),
          onPressed: (_) {
            changeFriendVerificationMethod(allowAny);
            Navigator.of(context, rootNavigator: true).pop();
          },
        ),
        BottomSheetAction(
          title: Text(
            AppI18n.of(context).t(
              zhHans: '需要验证信息',
              zhHant: '需要驗證資訊',
              en: 'Require Verification',
              ja: '承認が必要',
              ko: '인증 필요',
            ),
            style: TextStyle(color: textColor, fontSize: 18),
          ),
          onPressed: (_) {
            changeFriendVerificationMethod(needConfirm);
            Navigator.of(context, rootNavigator: true).pop();
          },
        ),
      ],
      cancelAction: CancelAction(
        title: Text(
          AppI18n.of(context).t(
            zhHans: '取消',
            zhHant: '取消',
            en: 'Cancel',
            ja: 'キャンセル',
            ko: '취소',
          ),
          style: const TextStyle(fontSize: 18),
        ),
      ),
    );
  }

  Future<void> _showToggleSheet({
    required String title,
    required bool currentValue,
    required ValueChanged<bool> onChanged,
  }) async {
    showAdaptiveActionSheet(
      context: context,
      title: Text(title),
      actions: <BottomSheetAction>[
        BottomSheetAction(
          title: Text(
            AppI18n.of(context).t(
              zhHans: '开启',
              zhHant: '開啟',
              en: 'On',
              ja: 'オン',
              ko: '켜기',
            ),
            style: const TextStyle(fontSize: 18),
          ),
          onPressed: (_) {
            onChanged(true);
            Navigator.of(context, rootNavigator: true).pop();
          },
        ),
        BottomSheetAction(
          title: Text(
            AppI18n.of(context).t(
              zhHans: '关闭',
              zhHant: '關閉',
              en: 'Off',
              ja: 'オフ',
              ko: '끄기',
            ),
            style: const TextStyle(fontSize: 18),
          ),
          onPressed: (_) {
            onChanged(false);
            Navigator.of(context, rootNavigator: true).pop();
          },
        ),
      ],
      cancelAction: CancelAction(
        title: Text(
          currentValue
              ? AppI18n.of(context).t(
                  zhHans: '当前: 开启',
                  zhHant: '目前: 開啟',
                  en: 'Current: On',
                  ja: '現在: オン',
                  ko: '현재: 켜짐',
                )
              : AppI18n.of(context).t(
                  zhHans: '当前: 关闭',
                  zhHant: '目前: 關閉',
                  en: 'Current: Off',
                  ja: '現在: オフ',
                  ko: '현재: 꺼짐',
                ),
          style: const TextStyle(fontSize: 16),
        ),
      ),
    );
  }

  Future<void> _showSettingsSheet() async {
    showAdaptiveActionSheet(
      context: context,
      actions: <BottomSheetAction>[
        BottomSheetAction(
          title: Text(
            AppI18n.of(context).t(
              zhHans: '关于腾讯云 · IM',
              zhHant: '關於騰訊雲 · IM',
              en: 'About Tencent Cloud · IM',
              ja: 'Tencent Cloud · IM について',
              ko: 'Tencent Cloud · IM 정보',
            ),
            style: const TextStyle(fontSize: 18),
          ),
          onPressed: (_) {
            Navigator.of(context, rootNavigator: true).pop();
            Navigator.push(
              context,
              AppMaterialPageRoute(
                builder: (context) => const About(),
              ),
            );
          },
        ),
        BottomSheetAction(
          title: Text(
            AppI18n.of(context).t(
              zhHans: '退出登录',
              zhHant: '登出',
              en: 'Log Out',
              ja: 'ログアウト',
              ko: '로그아웃',
            ),
            style: const TextStyle(
              fontSize: 18,
              color: AppTokens.danger,
            ),
          ),
          onPressed: (_) {
            Navigator.of(context, rootNavigator: true).pop();
            _handleLogout();
          },
        ),
      ],
      cancelAction: CancelAction(
        title: Text(
          AppI18n.of(context).t(
            zhHans: '取消',
            zhHant: '取消',
            en: 'Cancel',
            ja: 'キャンセル',
            ko: '취소',
          ),
          style: const TextStyle(fontSize: 18),
        ),
      ),
    );
  }

  Widget _buildSectionCard({
    required Color cardColor,
    required bool isDark,
    required List<Widget> children,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      color: cardColor.withValues(alpha: isDark ? 0.94 : 0.72),
      child: Column(children: children),
    );
  }

  Widget _buildCell({
    required Color dividerColor,
    required Color primaryTextColor,
    required Color secondaryTextColor,
    required Color arrowColor,
    required IconData icon,
    required Color iconColor,
    required String title,
    String? value,
    bool showDivider = true,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 56),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          border: showDivider
              ? Border(bottom: BorderSide(color: dividerColor))
              : null,
        ),
        child: Row(
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: iconColor,
                borderRadius: BorderRadius.circular(5),
              ),
              child: Icon(
                icon,
                color: Colors.white,
                size: 15,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 17,
                  color: primaryTextColor,
                ),
              ),
            ),
            if (value != null) ...[
              const SizedBox(width: 12),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 150),
                child: Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.end,
                  style: TextStyle(
                    fontSize: 15,
                    color: secondaryTextColor,
                  ),
                ),
              ),
            ],
            const SizedBox(width: 6),
            Icon(
              Icons.chevron_right_rounded,
              size: 24,
              color: arrowColor,
            ),
          ],
        ),
      ),
    );
  }

  Widget _profileMenuIcon(String assetPath) {
    return SvgPicture.asset(
      assetPath,
      width: 28,
      height: 28,
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) {
        assert(() {
          debugPrint('Profile menu SVG failed: $assetPath $error');
          return true;
        }());
        return Icon(
          Icons.image_not_supported_outlined,
          size: 28,
          color: Theme.of(context).colorScheme.outline,
        );
      },
    );
  }

  Widget _buildPlainCell({
    required Color dividerColor,
    required Color primaryTextColor,
    required Color secondaryTextColor,
    required Color arrowColor,
    IconData? icon,
    Color? iconColor,
    String? iconAsset,
    required String title,
    String? value,
    bool showDivider = true,
    VoidCallback? onTap,
  }) {
    assert(icon != null || iconAsset != null);
    final leading = iconAsset != null
        ? _profileMenuIcon(iconAsset)
        : Icon(
            icon,
            size: 28,
            color: iconColor,
          );
    return InkWell(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 56),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          border: showDivider
              ? Border(bottom: BorderSide(color: dividerColor))
              : null,
        ),
        child: Row(
          children: [
            leading,
            const SizedBox(width: 18),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 17,
                  color: primaryTextColor,
                ),
              ),
            ),
            if (value != null) ...[
              const SizedBox(width: 12),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 150),
                child: Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.end,
                  style: TextStyle(
                    fontSize: 15,
                    color: secondaryTextColor,
                  ),
                ),
              ),
            ],
            const SizedBox(width: 6),
            Icon(
              Icons.chevron_right_rounded,
              size: 24,
              color: arrowColor,
            ),
          ],
        ),
      ),
    );
  }

  Color _iconTone({
    required bool dark,
    required Color light,
    required Color darkColor,
  }) {
    return dark ? darkColor : light;
  }

  void _showFeaturePlaceholder(String title) {
    final i18n = AppI18n.of(context);
    ToastUtils.toast(i18n.format(
      zhHans: '{title} 功能开发中',
      zhHant: '{title} 功能開發中',
      en: '{title} is coming soon.',
      ja: '{title} は開発中です。',
      ko: '{title} 기능은 준비 중입니다.',
      vars: {'title': title},
    ));
  }

  void _openHotEcoItem(_HotEcoItem item) {
    switch (item.action) {
      case _HotEcoAction.wallet:
        widget.onOpenWalletTab();
        return;
      case _HotEcoAction.community:
        unawaited(MomentsSettingsService.instance.hydrateFromLocal());
        Navigator.push(
          context,
          AppMaterialPageRoute(
            builder: (context) => const MomentsPage(),
          ),
        );
        return;
      case _HotEcoAction.game:
        AppDialog.alert(
          title: '温馨提示',
          message: '该功能即将放出',
          buttonText: '确认',
        );
        return;
      case _HotEcoAction.shop:
        Navigator.push(
          context,
          AppMaterialPageRoute(
            builder: (context) => const LifePaymentPage(),
          ),
        );
        return;
    }
  }

  Widget _buildHotEcoSection({
    required Color cardColor,
    required Color primaryTextColor,
    required Color secondaryTextColor,
    required Color arrowColor,
    required bool isDark,
  }) {
    final items = const [
      _HotEcoItem(
        title: 'AI助手',
        asset: _profileEcoGameAsset,
        action: _HotEcoAction.game,
      ),
      _HotEcoItem(
        title: '生活缴费',
        asset: _profileEcoShopAsset,
        action: _HotEcoAction.shop,
      ),
      _HotEcoItem(
        title: '数字资产',
        asset: _profileEcoWalletAsset,
        action: _HotEcoAction.wallet,
      ),
      _HotEcoItem(
        title: '社区广场',
        asset: _profileEcoCommunityAsset,
        action: _HotEcoAction.community,
      ),
    ];

    return LayoutBuilder(
      builder: (context, outerConstraints) {
        final sectionWidth = outerConstraints.maxWidth;
        final horizontalPadding = sectionWidth * 0.045;
        final tileGap = sectionWidth * 0.018;

        return Container(
          color: Colors.transparent,
          padding: EdgeInsets.fromLTRB(
            horizontalPadding,
            0,
            horizontalPadding,
            sectionWidth * 0.045,
          ),
          child: Column(
            children: [
              SizedBox(
                height: sectionWidth * 0.11,
                child: Row(
                  children: [
                    Text(
                      '🔥',
                      style: TextStyle(fontSize: sectionWidth * 0.046),
                    ),
                    SizedBox(width: sectionWidth * 0.018),
                    Expanded(
                      child: Text(
                        '热门生态',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: primaryTextColor,
                          fontSize: sectionWidth * 0.043,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    InkWell(
                      borderRadius: BorderRadius.circular(sectionWidth * 0.04),
                      onTap: () => _showFeaturePlaceholder('热门生态'),
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: sectionWidth * 0.01,
                          vertical: sectionWidth * 0.014,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '查看更多',
                              style: TextStyle(
                                color: secondaryTextColor,
                                fontSize: sectionWidth * 0.036,
                              ),
                            ),
                            SizedBox(width: sectionWidth * 0.004),
                            Icon(
                              Icons.chevron_right_rounded,
                              color: arrowColor,
                              size: sectionWidth * 0.052,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                children: [
                  for (var i = 0; i < items.length; i++) ...[
                    if (i > 0) SizedBox(width: tileGap),
                    Expanded(
                      child: _HotEcoTile(
                        item: items[i],
                        onTap: () => _openHotEcoItem(items[i]),
                        delay: Duration(milliseconds: i * 260),
                      ),
                    ),
                  ],
                ],
              ),
              SizedBox(height: sectionWidth * 0.010),
              Container(
                height: sectionWidth * 0.016,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      (isDark
                              ? const Color(0xFF6B4A9A)
                              : const Color(0xFFF2DFFF))
                          .withValues(alpha: isDark ? 0.18 : 0.10),
                      (isDark
                              ? const Color(0xFF6B4A9A)
                              : const Color(0xFFF2DFFF))
                          .withValues(alpha: 0),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeaderCard({
    required Color cardColor,
    required Color primaryTextColor,
    required Color secondaryTextColor,
    required Color arrowColor,
    required bool isDark,
    required V2TimUserFullInfo? userProfile,
    required V2TimUserFullInfo loginUserInfo,
    required VoidCallback onTap,
    required VoidCallback onQrTap,
  }) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final signatureMaxWidth = screenWidth * 0.56;
    final signatureHPadding = screenWidth * 0.028;
    final signatureVPadding = screenWidth * 0.010;
    final signatureIconSize = screenWidth * 0.034;
    final signatureGap = screenWidth * 0.012;
    final signatureFontSize = screenWidth * 0.034;
    final nickname = _resolveDisplayNickname(userProfile, loginUserInfo);
    final signature = TencentUtils.isTextNotEmpty(userProfile?.selfSignature)
        ? userProfile!.selfSignature!
        : (TencentUtils.isTextNotEmpty(loginUserInfo.selfSignature)
            ? loginUserInfo.selfSignature!
            : AppI18n.of(context).t(
                zhHans: '暂无',
                zhHant: '暫無',
                en: 'None',
                ja: 'なし',
                ko: '없음',
              ));
    final displayUserId = ChatIdFormat.display(
      TencentUtils.isTextNotEmpty(userProfile?.userID)
          ? userProfile!.userID
          : _resolveProfileUserId(loginUserInfo),
    );
    return InkWell(
      onTap: onTap,
      child: Container(
        color: Colors.transparent,
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
        child: Row(
          children: [
            AppUserAvatar(
              faceUrl: _displayAvatarUrl(userProfile, loginUserInfo),
              showName: nickname,
              size: 72,
            ),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    nickname,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w600,
                      color: primaryTextColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "${AppI18n.of(context).t(
                      zhHans: '99号ID',
                      zhHant: '99號ID',
                      en: '99 ID',
                      ja: '99 ID',
                      ko: '99 ID',
                    )}: $displayUserId",
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 15,
                      color: secondaryTextColor.withValues(alpha: 0.92),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      constraints: BoxConstraints(maxWidth: signatureMaxWidth),
                      padding: EdgeInsets.symmetric(
                        horizontal: signatureHPadding,
                        vertical: signatureVPadding,
                      ),
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF5D74F2).withValues(alpha: 0.20)
                            : const Color(0xFFEDEBFF).withValues(alpha: 0.78),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.edit_rounded,
                            size: signatureIconSize,
                            color: isDark
                                ? const Color(0xFFA8B4FF)
                                : const Color(0xFF5D74F2),
                          ),
                          SizedBox(width: signatureGap),
                          Flexible(
                            child: Text(
                              "${AppI18n.of(context).t(
                                zhHans: '个性签名',
                                zhHant: '個性簽名',
                                en: 'Bio',
                                ja: '自己紹介',
                                ko: '상태 메시지',
                              )}: $signature",
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: signatureFontSize,
                                color: isDark
                                    ? const Color(0xFFA8B4FF)
                                    : const Color(0xFF5D74F2),
                                fontWeight: FontWeight.w500,
                                height: 1.16,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            InkWell(
              onTap: onQrTap,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Icon(
                  Icons.qr_code_2_rounded,
                  size: 20,
                  color: AppTokens.accent,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Icon(
              Icons.chevron_right_rounded,
              size: 24,
              color: arrowColor,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSkeletonBar({
    required double width,
    required double height,
    required Color color,
  }) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(height / 2),
      ),
    );
  }

  Widget _buildProfilePlaceholderPage({
    required Color pageBackgroundColor,
    required Color cardColor,
    required Color primaryTextColor,
    required Color secondaryTextColor,
    required Color dividerColor,
    required Color arrowColor,
    required bool isDark,
    required V2TimUserFullInfo loginUserInfo,
    required bool showSyncHint,
  }) {
    final placeholderColor = dividerColor.withValues(alpha: 0.9);
    return Container(
      color: Colors.transparent,
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(0, 0, 0, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeaderCard(
                cardColor: cardColor,
                primaryTextColor: primaryTextColor,
                secondaryTextColor: secondaryTextColor,
                arrowColor: arrowColor,
                isDark: isDark,
                userProfile: null,
                loginUserInfo: loginUserInfo,
                onTap: () {},
                onQrTap: () {},
              ),
              if (showSyncHint)
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.fromLTRB(0, 10, 0, 14),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  color: isDark
                      ? AppTokens.warningSurfaceDark
                      : AppTokens.warningSurfaceLight,
                  child: Text(
                    AppI18n.of(context).t(
                      zhHans: '正在同步我的资料',
                      zhHant: '正在同步我的資料',
                      en: 'Syncing your profile',
                      ja: 'プロフィールを同期中',
                      ko: '내 프로필을 동기화하는 중',
                    ),
                    style: TextStyle(
                      color: isDark
                          ? const Color(0xFFE8C46A)
                          : AppTokens.warning,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                )
              else
                const SizedBox(height: 14),
              _buildSectionCard(
                cardColor: cardColor,
                isDark: isDark,
                children: [
                  for (var i = 0; i < 5; i++)
                    Container(
                      constraints: const BoxConstraints(minHeight: 56),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        border: i < 4
                            ? Border(bottom: BorderSide(color: dividerColor))
                            : null,
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: placeholderColor,
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          const SizedBox(width: 18),
                          Expanded(
                            child: _buildSkeletonBar(
                              width: i.isEven ? 96 : 112,
                              height: 14,
                              color: placeholderColor,
                            ),
                          ),
                          const SizedBox(width: 12),
                          _buildSkeletonBar(
                            width: i == 0 ? 56 : 44,
                            height: 12,
                            color: placeholderColor.withValues(alpha: 0.72),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              _buildSectionCard(
                cardColor: cardColor,
                isDark: isDark,
                children: [
                  Container(
                    constraints: const BoxConstraints(minHeight: 56),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: placeholderColor,
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        const SizedBox(width: 18),
                        Expanded(
                          child: _buildSkeletonBar(
                            width: 84,
                            height: 14,
                            color: placeholderColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeModel = Provider.of<DefaultThemeData>(context);
    final theme = themeModel.theme;
    final loginUserInfoModel = Provider.of<LoginUserInfo>(context);
    final loginUserInfo = loginUserInfoModel.loginUserInfo;
    final effectiveUserId = _resolveProfileUserId(loginUserInfo);
    final isDarkBackground = themeModel.currentThemeType == ThemeType.dark;
    final pageBackgroundColor = AppColors.background(dark: isDarkBackground);
    final cardColor =
        theme.conversationItemBgColor ?? AppColors.card(dark: isDarkBackground);
    final primaryTextColor =
        theme.darkTextColor ?? AppColors.text(dark: isDarkBackground);
    final secondaryTextColor =
        theme.weakTextColor ?? AppColors.subText(dark: isDarkBackground);
    final dividerColor =
        theme.weakDividerColor ?? AppColors.line(dark: isDarkBackground);
    final profileListDividerColor = dividerColor.withValues(alpha: 0.42);
    final arrowColor =
        theme.weakTextColor ?? AppColors.subText(dark: isDarkBackground);
    return ValueListenableBuilder<bool>(
      valueListenable: AuthBootstrapService.instance.backgroundSyncing,
      builder: (context, isSyncing, _) {
        final imReady = AuthBootstrapService.instance.isCoreServicesUserReady();
        final canRenderProfile = effectiveUserId.isNotEmpty && imReady;
        if (!canRenderProfile) {
          return _buildProfilePlaceholderPage(
            pageBackgroundColor: pageBackgroundColor,
            cardColor: cardColor,
            primaryTextColor: primaryTextColor,
            secondaryTextColor: secondaryTextColor,
            dividerColor: dividerColor,
            arrowColor: arrowColor,
            isDark: isDarkBackground,
            loginUserInfo: loginUserInfo,
            showSyncHint: isSyncing || effectiveUserId.isEmpty || !imReady,
          );
        }
        return Container(
          color: Colors.transparent,
          child: TIMUIKitProfile(
            key: ValueKey('profile:$effectiveUserId'),
            isSelf: true,
            userID: effectiveUserId,
            controller: _timuiKitProfileController,
            builder: (BuildContext context, V2TimFriendInfo userInfo,
                V2TimConversation conversation, int friendType, bool isMute) {
              final userProfile = userInfo.userProfile;
              final displayName =
                  _resolveDisplayNickname(userProfile, loginUserInfo);

              return SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(0, 0, 0, 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeaderCard(
                        cardColor: cardColor,
                        primaryTextColor: primaryTextColor,
                        secondaryTextColor: secondaryTextColor,
                        arrowColor: arrowColor,
                        isDark: isDarkBackground,
                        userProfile: userProfile,
                        loginUserInfo: loginUserInfo,
                        onQrTap: () {
                          Navigator.push(
                            context,
                            AppMaterialPageRoute(
                              builder: (context) => QRCodePage(
                                type: QRCodePageType.user,
                                title: AppI18n.of(context).t(
                                  zhHans: '我的二维码',
                                  zhHant: '我的 QR 碼',
                                  en: 'My QR Code',
                                  ja: 'マイQRコード',
                                  ko: '내 QR 코드',
                                ),
                                displayName: displayName,
                                aliasLabel: AppI18n.of(context).t(
                                  zhHans: '99号ID',
                                  zhHant: '99號ID',
                                  en: '99 ID',
                                  ja: '99 ID',
                                  ko: '99 ID',
                                ),
                                aliasValue:
                                    ChatIdFormat.display(userProfile?.userID),
                                faceUrl: _displayAvatarUrl(
                                    userProfile, loginUserInfo),
                                shareText: "${AppI18n.of(context).t(
                                  zhHans: '我的二维码',
                                  zhHant: '我的 QR 碼',
                                  en: 'My QR Code',
                                  ja: 'マイQRコード',
                                  ko: '내 QR 코드',
                                )} ${userProfile?.userID ?? ""}",
                              ),
                            ),
                          );
                        },
                        onTap: () async {
                          await Navigator.push(
                            context,
                            AppMaterialPageRoute(
                              builder: (context) => MyProfileDetail(
                                userProfile: userProfile,
                                controller: _timuiKitProfileController,
                              ),
                            ),
                          );
                          if (!mounted) return;
                          if (effectiveUserId.isNotEmpty) {
                            _timuiKitProfileController
                                .loadData(effectiveUserId);
                          }
                          unawaited(_refreshLoginUserInfoFromIm());
                          _loadBackendAvatar();
                        },
                      ),
                      _buildHotEcoSection(
                        cardColor: cardColor,
                        primaryTextColor: primaryTextColor,
                        secondaryTextColor: secondaryTextColor,
                        arrowColor: arrowColor,
                        isDark: isDarkBackground,
                      ),
                      const SizedBox(height: 14),
                      _buildSectionCard(
                        cardColor: cardColor,
                        isDark: isDarkBackground,
                        children: [
                        _buildPlainCell(
                          dividerColor: profileListDividerColor,
                          primaryTextColor: primaryTextColor,
                          secondaryTextColor: secondaryTextColor,
                          arrowColor: arrowColor,
                          iconAsset: ProfileMenuIcons.favorites,
                          title: AppI18n.of(context).t(
                            zhHans: '收藏',
                            zhHant: '收藏',
                            en: 'Favorites',
                            ja: 'お気に入り',
                            ko: '즐겨찾기',
                          ),
                          onTap: () {
                            Navigator.push(
                              context,
                              AppMaterialPageRoute(
                                builder: (context) => const FavoriteListPage(),
                              ),
                            );
                          },
                        ),
                        _buildPlainCell(
                          dividerColor: profileListDividerColor,
                          primaryTextColor: primaryTextColor,
                          secondaryTextColor: secondaryTextColor,
                          arrowColor: arrowColor,
                          iconAsset: ProfileMenuIcons.call,
                          title: AppI18n.of(context).t(
                            zhHans: '通话',
                            zhHant: '通話',
                            en: 'Calls',
                            ja: '通話',
                            ko: '통화',
                          ),
                          onTap: () {
                            Navigator.push(
                              context,
                              AppMaterialPageRoute(
                                builder: (context) => const RecentCallsPage(),
                              ),
                            );
                          },
                        ),
                        _buildPlainCell(
                          dividerColor: profileListDividerColor,
                          primaryTextColor: primaryTextColor,
                          secondaryTextColor: secondaryTextColor,
                          arrowColor: arrowColor,
                          iconAsset: ProfileMenuIcons.notification,
                          title: AppI18n.of(context).t(
                            zhHans: '消息通知',
                            zhHant: '訊息通知',
                            en: 'Notifications',
                            ja: '通知',
                            ko: '알림',
                          ),
                          onTap: () {
                            Navigator.push(
                              context,
                              NavigationRoutes.cupertino(
                                builder: (_) =>
                                    const NotificationSettingsPage(),
                              ),
                            );
                          },
                        ),
                        _buildPlainCell(
                          dividerColor: profileListDividerColor,
                          primaryTextColor: primaryTextColor,
                          secondaryTextColor: secondaryTextColor,
                          arrowColor: arrowColor,
                          iconAsset: ProfileMenuIcons.shareApp,
                          title: AppI18n.of(context).t(
                            zhHans: '分享应用',
                            zhHant: '分享應用',
                            en: 'Share App',
                            ja: 'アプリを共有',
                            ko: '앱 공유',
                          ),
                          showDivider: false,
                          onTap: () => ShareAppSheet.show(context),
                        ),
                      ],
                      ),
                      _buildSectionCard(
                        cardColor: cardColor,
                        isDark: isDarkBackground,
                        children: [
                        _buildPlainCell(
                          dividerColor: profileListDividerColor,
                          primaryTextColor: primaryTextColor,
                          secondaryTextColor: secondaryTextColor,
                          arrowColor: arrowColor,
                          iconAsset: ProfileMenuIcons.settings,
                          title: AppI18n.of(context).t(
                            zhHans: '设置',
                            zhHant: '設定',
                            en: 'Settings',
                            ja: '設定',
                            ko: '설정',
                          ),
                          showDivider: false,
                          onTap: () {
                            Navigator.push(
                              context,
                              AppMaterialPageRoute(
                                builder: (context) => SettingsPage(
                                  onLogout: _handleLogout,
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}
