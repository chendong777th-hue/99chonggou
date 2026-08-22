import 'package:flutter/material.dart';
import 'package:tencent_cloud_chat_demo/src/i18n/app_i18n.dart';
import 'package:tencent_cloud_chat_demo/src/pages/settings/settings_widgets.dart';

class ProfileInfoPage extends StatelessWidget {
  const ProfileInfoPage({super.key});

  @override
  Widget build(BuildContext context) {
    final i18n = AppI18n.of(context);
    return SettingsScaffold(
      title: i18n.t(
        zhHans: '个人资料',
        zhHant: '個人資料',
        en: 'Profile',
        ja: 'プロフィール',
        ko: '프로필',
      ),
      children: [
        SettingsGroup(
          children: [
            SettingsCell(
              title: i18n.t(
                zhHans: '头像',
                zhHant: '頭像',
                en: 'Avatar',
                ja: 'プロフィール画像',
                ko: '프로필 사진',
              ),
              value: '',
              onTap: () => openSettingsPlaceholder(context),
            ),
            SettingsCell(
              title: i18n.t(
                zhHans: '昵称',
                zhHant: '暱稱',
                en: 'Nickname',
                ja: 'ニックネーム',
                ko: '닉네임',
              ),
              value: i18n.t(
                zhHans: '未设置',
                zhHant: '未設定',
                en: 'Not Set',
                ja: '未設定',
                ko: '설정 안 됨',
              ),
              onTap: () => openSettingsPlaceholder(context),
            ),
            SettingsCell(
              title: i18n.t(
                zhHans: '账号',
                zhHant: '帳號',
                en: 'Account',
                ja: 'アカウント',
                ko: '계정',
              ),
              value: i18n.t(
                zhHans: '未绑定',
                zhHant: '未綁定',
                en: 'Not Linked',
                ja: '未連携',
                ko: '연결되지 않음',
              ),
              showArrow: false,
            ),
            SettingsCell(
              title: i18n.t(
                zhHans: '二维码名片',
                zhHant: '二維碼名片',
                en: 'QR Profile Card',
                ja: 'QRプロフィールカード',
                ko: 'QR 프로필 카드',
              ),
              showDivider: false,
              onTap: () => openSettingsPlaceholder(context),
            ),
          ],
        ),
      ],
    );
  }
}
