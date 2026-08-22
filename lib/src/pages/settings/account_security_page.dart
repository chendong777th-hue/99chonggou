import 'package:flutter/material.dart';
import 'package:tencent_cloud_chat_demo/src/i18n/app_i18n.dart';
import 'package:tencent_cloud_chat_demo/src/pages/settings/biometric_pay_settings_cell.dart';
import 'package:tencent_cloud_chat_demo/src/pages/settings/change_password_page.dart';
import 'package:tencent_cloud_chat_demo/src/pages/settings/change_phone_page.dart';
import 'package:tencent_cloud_chat_demo/src/pages/settings/login_devices_page.dart';
import 'package:tencent_cloud_chat_demo/src/pages/settings/settings_widgets.dart';
import 'package:tencent_cloud_chat_demo/src/pages/settings/trade_password_settings_nav.dart';
import 'package:tencent_cloud_chat_demo/src/utils/phone_binding_guard.dart';
import 'package:tencent_cloud_chat_demo/utils/navigation_routes.dart';

class AccountSecurityPage extends StatefulWidget {
  const AccountSecurityPage({super.key});

  @override
  State<AccountSecurityPage> createState() => _AccountSecurityPageState();
}

class _AccountSecurityPageState extends State<AccountSecurityPage> {
  bool _phoneBound = false;

  @override
  void initState() {
    super.initState();
    _loadPhoneBound();
  }

  Future<void> _loadPhoneBound() async {
    try {
      final bound = await PhoneBindingGuard.fetchIsBound();
      if (!mounted) return;
      setState(() => _phoneBound = bound);
    } catch (_) {
      if (!mounted) return;
      setState(() => _phoneBound = false);
    }
  }

  void _open(BuildContext context, Widget page) {
    Navigator.push(
      context,
      NavigationRoutes.cupertino(builder: (_) => page),
    );
  }

  Future<void> _openChangePhone(BuildContext context) async {
    await Navigator.push(
      context,
      NavigationRoutes.cupertino(builder: (_) => const ChangePhonePage()),
    );
    if (mounted) {
      await _loadPhoneBound();
    }
  }

  @override
  Widget build(BuildContext context) {
    final i18n = AppI18n.of(context);
    final phoneTitle = _phoneBound
        ? i18n.t(
            zhHans: '修改手机号码',
            zhHant: '修改手機號碼',
            en: 'Change Phone Number',
            ja: '電話番号を変更',
            ko: '휴대전화 번호 변경',
          )
        : i18n.t(
            zhHans: '绑定手机号码',
            zhHant: '綁定手機號碼',
            en: 'Link Phone Number',
            ja: '電話番号を登録',
            ko: '휴대전화 번호 등록',
          );

    return SettingsScaffold(
      title: i18n.t(
        zhHans: '账号安全',
        zhHant: '帳號安全',
        en: 'Account Security',
        ja: 'アカウントとセキュリティ',
        ko: '계정 및 보안',
      ),
      children: [
        SettingsGroup(
          children: [
            SettingsCell(
              title: i18n.t(
                zhHans: '修改密码',
                zhHant: '修改密碼',
                en: 'Change Password',
                ja: 'パスワードを変更',
                ko: '비밀번호 변경',
              ),
              onTap: () => _open(context, const ChangePasswordPage()),
            ),
            SettingsCell(
              title: i18n.t(
                zhHans: '支付密码',
                zhHant: '支付密碼',
                en: 'Payment Password',
                ja: '支払いパスワード',
                ko: '결제 비밀번호',
              ),
              onTap: () => TradePasswordSettingsNav.open(context),
            ),
            const BiometricPaySettingsCell(),
            SettingsCell(
              title: phoneTitle,
              onTap: () => _openChangePhone(context),
            ),
            SettingsCell(
              title: i18n.t(
                zhHans: '登录设备',
                zhHant: '登入裝置',
                en: 'Signed-in Devices',
                ja: 'ログイン端末',
                ko: '로그인 기기',
              ),
              showDivider: false,
              onTap: () => _open(context, const LoginDevicesPage()),
            ),
          ],
        ),
      ],
    );
  }
}
