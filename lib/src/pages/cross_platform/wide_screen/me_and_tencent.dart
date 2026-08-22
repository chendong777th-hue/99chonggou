import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tencent_cloud_chat_demo/src/i18n/app_i18n.dart';
import 'package:tencent_cloud_chat_demo/src/my_profile_detail.dart';
import 'package:tencent_cloud_chat_demo/src/pages/settings/about_us_page.dart';
import 'package:tencent_cloud_chat_demo/src/pages/settings/feedback_page.dart';
import 'package:tencent_cloud_chat_demo/src/pages/settings/settings_page.dart';
import 'package:tencent_cloud_chat_demo/src/provider/login_user_Info.dart';
import 'package:tencent_cloud_chat_demo/src/provider/theme.dart';
import 'package:tencent_cloud_chat_demo/src/services/account_session_service.dart';
import 'package:tencent_cloud_chat_demo/utils/init_step.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_conversation.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_conversation.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_friend_info.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_friend_info.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_user_full_info.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_user_full_info.dart';
import 'package:tencent_cloud_chat_uikit/tencent_cloud_chat_uikit.dart';
import 'package:tencent_cloud_chat_uikit/theme/tui_theme.dart';
import 'package:tencent_cloud_chat_uikit/ui/widgets/avatar.dart';

enum _MePane { profile, settings, feedback, about }

/// Web / 桌面「我的」：左侧菜单宽度对齐消息/通讯录列表，右侧展示对应内容。
class MeAndTencent extends StatefulWidget {
  const MeAndTencent({Key? key}) : super(key: key);

  @override
  State<MeAndTencent> createState() => _MeAndTencentState();
}

class _MeAndTencentState extends State<MeAndTencent> {
  final TIMUIKitProfileController _timuiKitProfileController =
      TIMUIKitProfileController();
  _MePane _pane = _MePane.profile;

  Future<void> _handleLogout() async {
    await AccountSessionService.instance.clearForLogout(
      reason: 'me_shell_logout',
    );
    if (!mounted) return;
    InitStep.directToLogin(context);
  }

  Widget _buildNavItem({
    required TUITheme theme,
    required IconData icon,
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    final primary = theme.primaryColor ?? const Color(0xFF1E90FF);
    final textColor = selected
        ? primary
        : (theme.darkTextColor ?? const Color(0xFF111827));
    final bg = selected
        ? primary.withValues(alpha: 0.08)
        : Colors.transparent;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: SizedBox(
            height: 44,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  Icon(icon, size: 20, color: textColor),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight:
                            selected ? FontWeight.w600 : FontWeight.w500,
                        color: textColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLeftNav(TUITheme theme, V2TimUserFullInfo loginUserInfo) {
    final i18n = AppI18n.of(context);
    final nick = (loginUserInfo.nickName?.trim().isNotEmpty ?? false)
        ? loginUserInfo.nickName!.trim()
        : (loginUserInfo.userID ?? '');
    final userId = loginUserInfo.userID ?? '';
    final faceUrl = loginUserInfo.faceUrl ?? '';
    final divider = theme.weakDividerColor ?? const Color(0xFFE5E5E5);
    final weak = theme.weakTextColor ?? const Color(0xFF9CA3AF);
    final caution = theme.cautionColor ?? const Color(0xFFE53935);

    return ColoredBox(
      color: theme.wideBackgroundColor ??
          theme.weakBackgroundColor ??
          Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
            child: Row(
              children: [
                SizedBox(
                  width: 48,
                  height: 48,
                  child: Avatar(
                    faceUrl: faceUrl,
                    showName: nick,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        nick,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: theme.darkTextColor ?? Colors.black,
                        ),
                      ),
                      if (userId.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          userId,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 12, color: weak),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 16),
            child: Container(height: 0.6, color: divider),
          ),
          const SizedBox(height: 8),
          _buildNavItem(
            theme: theme,
            icon: Icons.person_outline_rounded,
            label: i18n.t(
              zhHans: '个人资料',
              zhHant: '個人資料',
              en: 'Profile',
              ja: 'プロフィール',
              ko: '프로필',
            ),
            selected: _pane == _MePane.profile,
            onTap: () => setState(() => _pane = _MePane.profile),
          ),
          _buildNavItem(
            theme: theme,
            icon: Icons.settings_outlined,
            label: i18n.t(
              zhHans: '设置',
              zhHant: '設定',
              en: 'Settings',
              ja: '設定',
              ko: '설정',
            ),
            selected: _pane == _MePane.settings,
            onTap: () => setState(() => _pane = _MePane.settings),
          ),
          _buildNavItem(
            theme: theme,
            icon: Icons.mail_outline_rounded,
            label: i18n.t(
              zhHans: '意见反馈',
              zhHant: '意見回饋',
              en: 'Feedback',
              ja: 'フィードバック',
              ko: '의견 보내기',
            ),
            selected: _pane == _MePane.feedback,
            onTap: () => setState(() => _pane = _MePane.feedback),
          ),
          _buildNavItem(
            theme: theme,
            icon: Icons.info_outline_rounded,
            label: i18n.t(
              zhHans: '关于我们',
              zhHant: '關於我們',
              en: 'About Us',
              ja: 'このアプリについて',
              ko: '앱 정보',
            ),
            selected: _pane == _MePane.about,
            onTap: () => setState(() => _pane = _MePane.about),
          ),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
            child: OutlinedButton(
              onPressed: _handleLogout,
              style: OutlinedButton.styleFrom(
                foregroundColor: caution,
                side: BorderSide(color: caution.withValues(alpha: 0.45)),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(22),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.logout, color: caution, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    i18n.t(
                      zhHans: '退出登录',
                      zhHant: '登出',
                      en: 'Log Out',
                      ja: 'ログアウト',
                      ko: '로그아웃',
                    ),
                    style: TextStyle(
                      color: caution,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRightPane(TUITheme theme, V2TimUserFullInfo loginUserInfo) {
    switch (_pane) {
      case _MePane.profile:
        return TIMUIKitProfile(
          userID: loginUserInfo.userID ?? '',
          controller: _timuiKitProfileController,
          builder: (
            BuildContext context,
            V2TimFriendInfo userInfo,
            V2TimConversation conversation,
            int friendType,
            bool isMute,
          ) {
            return MyProfileDetail(
              userProfile: userInfo.userProfile,
              controller: _timuiKitProfileController,
              shellEmbedded: true,
            );
          },
        );
      case _MePane.settings:
        return Navigator(
          key: const ValueKey('me-settings-nav'),
          onGenerateRoute: (settings) {
            return MaterialPageRoute(
              settings: settings,
              builder: (_) => SettingsPage(
                embedded: true,
                onLogout: _handleLogout,
              ),
            );
          },
        );
      case _MePane.feedback:
        return Navigator(
          key: const ValueKey('me-feedback-nav'),
          onGenerateRoute: (settings) {
            return MaterialPageRoute(
              settings: settings,
              builder: (_) => const FeedbackPage(),
            );
          },
        );
      case _MePane.about:
        return Navigator(
          key: const ValueKey('me-about-nav'),
          onGenerateRoute: (settings) {
            return MaterialPageRoute(
              settings: settings,
              builder: (_) => const AboutUsPage(),
            );
          },
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final loginUserInfoModel = Provider.of<LoginUserInfo>(context);
    final V2TimUserFullInfo loginUserInfo = loginUserInfoModel.loginUserInfo;
    final theme = Provider.of<DefaultThemeData>(context).theme;
    final dividerColor = theme.weakDividerColor ?? const Color(0xFFE5E5E5);

    return Row(
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 300, maxWidth: 340),
          child: _buildLeftNav(theme, loginUserInfo),
        ),
        SizedBox(
          width: 1,
          child: ColoredBox(color: dividerColor),
        ),
        Expanded(
          child: ColoredBox(
            color: theme.wideBackgroundColor ?? Colors.white,
            child: _buildRightPane(theme, loginUserInfo),
          ),
        ),
      ],
    );
  }
}
