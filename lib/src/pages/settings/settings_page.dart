import 'package:flutter/material.dart';
import 'package:tencent_cloud_chat_demo/utils/toast.dart';
import 'package:tencent_cloud_chat_demo/src/i18n/app_i18n.dart';
import 'package:tencent_cloud_chat_demo/src/pages/settings/account_security_page.dart';
import 'package:tencent_cloud_chat_demo/src/pages/settings/about_us_page.dart';
import 'package:tencent_cloud_chat_demo/src/pages/settings/display_theme_page.dart';
import 'package:tencent_cloud_chat_demo/src/pages/settings/feedback_page.dart';
import 'package:tencent_cloud_chat_demo/src/pages/settings/friend_permission_page.dart';
import 'package:tencent_cloud_chat_demo/src/pages/settings/moments_permission_page.dart';
import 'package:tencent_cloud_chat_demo/src/pages/settings/node_switch_page.dart';
import 'package:tencent_cloud_chat_demo/src/pages/settings/settings_widgets.dart';
import 'package:tencent_cloud_chat_demo/src/pages/settings/storage_page.dart';
import 'package:tencent_cloud_chat_demo/src/services/app_update_service.dart';
import 'package:tencent_cloud_chat_demo/src/theme/app_colors.dart';
import 'package:tencent_cloud_chat_demo/src/widgets/app_dialog.dart';
import 'package:tencent_cloud_chat_demo/src/utils/app_version.dart';
import 'package:tencent_cloud_chat_demo/utils/navigation_routes.dart';
import 'package:tencent_cloud_chat_demo/utils/profile_page_nav.dart';

class SettingsPage extends StatefulWidget {
  final Future<void> Function()? onLogout;

  /// 桌面右栏 / 弹窗内：根页不显示返回箭头，子页仍走内嵌 Navigator。
  final bool embedded;

  const SettingsPage({
    super.key,
    this.onLogout,
    this.embedded = false,
  });

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  String _displayVersion = '';
  bool _checkingUpdate = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _loadVersion();
    });
  }

  Future<void> _loadVersion() async {
    final version = await AppVersion.getDisplayVersion();
    if (!mounted) return;
    setState(() {
      _displayVersion = version;
    });
  }

  Future<void> _checkForUpdate() async {
    if (_checkingUpdate) return;
    setState(() {
      _checkingUpdate = true;
    });
    try {
      await AppUpdateService.instance.check(context, manual: true);
    } finally {
      if (mounted) {
        setState(() {
          _checkingUpdate = false;
        });
      }
    }
  }

  void _open(Widget page) {
    Navigator.push(
      context,
      NavigationRoutes.cupertino(builder: (_) => page),
    );
  }

  Future<void> _confirmLogout() async {
    var dark = settingsIsDark(context);
    final i18n = AppI18n.of(context);

    final ok = await AppDialog.confirm(
      title: i18n.t(
        zhHans: '退出登录',
        zhHant: '登出',
        en: 'Log Out',
        ja: 'ログアウト',
        ko: '로그아웃',
      ),
      message: i18n.t(
        zhHans: '确认退出当前账号？',
        zhHant: '確定要登出目前帳號嗎？',
        en: 'Are you sure you want to log out of this account?',
        ja: '現在のアカウントからログアウトしますか？',
        ko: '현재 계정에서 로그아웃하시겠습니까?',
      ),
      cancelText: i18n.t(
        zhHans: '取消',
        zhHant: '取消',
        en: 'Cancel',
        ja: 'キャンセル',
        ko: '취소',
      ),
      confirmText: i18n.t(
        zhHans: '退出登录',
        zhHant: '登出',
        en: 'Log Out',
        ja: 'ログアウト',
        ko: '로그아웃',
      ),
      destructive: true,
    );

    if (!ok) return;

    if (widget.onLogout != null) {
      await widget.onLogout!();
      return;
    }

    if (!mounted) return;

    ToastUtils.toast(i18n.t(
      zhHans: '退出登录入口已预留',
      zhHant: '登出入口已預留',
      en: 'The logout entry is reserved for future integration.',
      ja: 'ログアウト機能の入口は予約済みで、後続実装に対応します。',
      ko: '로그아웃 기능은 추후 연동을 위해 자리만 마련되어 있습니다.',
    ));
  }

  @override
  Widget build(BuildContext context) {
    var dark = settingsIsDark(context);
    final i18n = AppI18n.of(context);

    return SettingsScaffold(
      title: i18n.t(
        zhHans: '设置',
        zhHant: '設定',
        en: 'Settings',
        ja: '設定',
        ko: '설정',
      ),
      showLeading: !widget.embedded,
      children: [
        SettingsGroup(
          children: [
            if (!widget.embedded)
              SettingsCell(
                title: i18n.t(
                  zhHans: '个人资料',
                  zhHant: '個人資料',
                  en: 'Profile',
                  ja: 'プロフィール',
                  ko: '프로필',
                ),
                onTap: () => ProfilePageNav.openMyProfileDetail(context),
              ),
            SettingsCell(
              title: i18n.t(
                zhHans: '账号安全',
                zhHant: '帳號安全',
                en: 'Account Security',
                ja: 'アカウントとセキュリティ',
                ko: '계정 및 보안',
              ),
              showDivider: false,
              onTap: () => _open(const AccountSecurityPage()),
            ),
          ],
        ),
        SettingsGroup(
          children: [
            SettingsCell(
              title: i18n.t(
                zhHans: '朋友权限',
                zhHant: '朋友權限',
                en: 'Friend Permissions',
                ja: '友だち権限',
                ko: '친구 권한',
              ),
              onTap: () => _open(const FriendPermissionPage()),
            ),
            SettingsCell(
              title: i18n.t(
                zhHans: '朋友圈',
                zhHant: '朋友圈',
                en: 'Moments',
                ja: 'モーメント',
                ko: '모멘트',
              ),
              showDivider: false,
              onTap: () => _open(const MomentsPermissionPage()),
            ),
          ],
        ),
        SettingsGroup(
          children: [
            SettingsCell(
              title: i18n.t(
                zhHans: '界面与显示',
                zhHant: '介面與顯示',
                en: 'Appearance',
                ja: '表示と外観',
                ko: '화면 및 표시',
              ),
              onTap: () => _open(const DisplayThemePage()),
            ),
            SettingsCell(
              title: i18n.t(
                zhHans: '储存空间',
                zhHant: '儲存空間',
                en: 'Storage',
                ja: 'ストレージ',
                ko: '저장 공간',
              ),
              onTap: () => _open(const StoragePage()),
            ),
            SettingsCell(
              title: i18n.t(
                zhHans: '节点切换',
                zhHant: '節點切換',
                en: 'Node Switch',
                ja: 'ノード切替',
                ko: '노드 전환',
              ),
              showDivider: false,
              onTap: () => _open(const NodeSwitchPage()),
            ),
          ],
        ),
        SettingsGroup(
          children: [
            SettingsCell(
              title: i18n.t(
                zhHans: '关于我们',
                zhHant: '關於我們',
                en: 'About Us',
                ja: 'このアプリについて',
                ko: '앱 정보',
              ),
              onTap: () => _open(const AboutUsPage()),
            ),
            SettingsCell(
              title: i18n.t(
                zhHans: '意见反馈',
                zhHant: '意見回饋',
                en: 'Feedback',
                ja: 'フィードバック',
                ko: '의견 보내기',
              ),
              onTap: () => _open(const FeedbackPage()),
            ),
            SettingsCell(
              title: i18n.t(
                zhHans: '当前版本',
                zhHant: '目前版本',
                en: 'Version',
                ja: 'バージョン',
                ko: '현재 버전',
              ),
              value: _displayVersion.isEmpty
                  ? i18n.t(
                      zhHans: '获取中',
                      zhHant: '讀取中',
                      en: 'Loading',
                      ja: '読み込み中',
                      ko: '불러오는 중',
                    )
                  : _checkingUpdate
                      ? i18n.t(
                          zhHans: '检查中',
                          zhHant: '檢查中',
                          en: 'Checking',
                          ja: '確認中',
                          ko: '확인 중',
                        )
                      : 'v$_displayVersion',
              showArrow: true,
              showDivider: false,
              onTap: _checkForUpdate,
            ),
          ],
        ),
        if (!widget.embedded)
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 24),
            decoration: BoxDecoration(
              color: AppColors.card(dark: dark),
              border: Border(
                top: BorderSide(
                  color: AppColors.line(dark: dark),
                  width: 0.6,
                ),
                bottom: BorderSide(
                  color: AppColors.line(dark: dark),
                  width: 0.6,
                ),
              ),
            ),
            child: InkWell(
              onTap: _confirmLogout,
              child: SizedBox(
                height: 56,
                child: Center(
                  child: Text(
                    i18n.t(
                      zhHans: '退出登录',
                      zhHant: '登出',
                      en: 'Log Out',
                      ja: 'ログアウト',
                      ko: '로그아웃',
                    ),
                    style: TextStyle(
                      color: AppColors.primaryRed,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
