import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tencent_cloud_chat_demo/src/i18n/app_i18n.dart';
import 'package:tencent_cloud_chat_demo/src/pages/chat_background_page.dart';
import 'package:tencent_cloud_chat_demo/src/pages/settings/font_size_page.dart';
import 'package:tencent_cloud_chat_demo/src/pages/settings/language_switch_sheet.dart';
import 'package:tencent_cloud_chat_demo/src/pages/settings/settings_widgets.dart';
import 'package:tencent_cloud_chat_demo/src/provider/local_setting.dart';
import 'package:tencent_cloud_chat_demo/src/provider/theme.dart';
import 'package:tencent_cloud_chat_demo/src/services/chat_background_service.dart';
import 'package:tencent_cloud_chat_demo/src/widgets/app_dialog.dart';
import 'package:tencent_cloud_chat_demo/utils/navigation_routes.dart';
import 'package:tencent_cloud_chat_demo/utils/theme.dart';

class DisplayThemePage extends StatelessWidget {
  const DisplayThemePage({super.key});

  void _open(BuildContext context, Widget page) {
    Navigator.push(
      context,
      NavigationRoutes.cupertino(builder: (_) => page),
    );
  }

  String _themeText(ThemeType type, AppI18n i18n) {
    switch (type) {
      case ThemeType.dark:
        return i18n.t(
          zhHans: '深色模式',
          zhHant: '深色模式',
          en: 'Dark Mode',
          ja: 'ダークモード',
          ko: '다크 모드',
        );
      case ThemeType.system:
        return i18n.t(
          zhHans: '跟随系统',
          zhHant: '跟隨系統',
          en: 'Follow System',
          ja: 'システムに合わせる',
          ko: '시스템 설정 따르기',
        );
      case ThemeType.blue:
        return i18n.t(
          zhHans: '日间模式',
          zhHant: '日間模式',
          en: 'Light Mode',
          ja: 'ライトモード',
          ko: '라이트 모드',
        );
    }
  }

  Future<void> _showThemeSheet(
    BuildContext context,
    DefaultThemeData themeData,
  ) async {
    final i18n = AppI18n.of(context);
    final selected = await AppDialog.actionSheet<ThemeType>(
      title: i18n.t(
        zhHans: '选择主题',
        zhHant: '選擇主題',
        en: 'Choose Theme',
        ja: 'テーマを選択',
        ko: '테마 선택',
      ),
      cancelText: i18n.t(
        zhHans: '取消',
        zhHant: '取消',
        en: 'Cancel',
        ja: 'キャンセル',
        ko: '취소',
      ),
      actions: [
        AppActionSheetItem(
          text: i18n.t(
            zhHans: '深色模式',
            zhHant: '深色模式',
            en: 'Dark Mode',
            ja: 'ダークモード',
            ko: '다크 모드',
          ),
          value: ThemeType.dark,
        ),
        AppActionSheetItem(
          text: i18n.t(
            zhHans: '日间模式',
            zhHant: '日間模式',
            en: 'Light Mode',
            ja: 'ライトモード',
            ko: '라이트 모드',
          ),
          value: ThemeType.blue,
        ),
        AppActionSheetItem(
          text: i18n.t(
            zhHans: '跟随系统',
            zhHant: '跟隨系統',
            en: 'Follow System',
            ja: 'システムに合わせる',
            ko: '시스템 설정 따르기',
          ),
          value: ThemeType.system,
        ),
      ],
    );

    if (selected == null) return;
    themeData.currentThemeType = selected;
  }

  @override
  Widget build(BuildContext context) {
    final themeData = Provider.of<DefaultThemeData>(context);
    final localSetting = Provider.of<LocalSetting>(context);
    final i18n = AppI18n.of(context);

    return SettingsScaffold(
      title: i18n.t(
        zhHans: '界面与显示',
        zhHant: '介面與顯示',
        en: 'Appearance',
        ja: '表示と外観',
        ko: '화면 및 표시',
      ),
      children: [
        SettingsGroup(
          margin: EdgeInsets.zero,
          children: [
            SettingsCell(
              title: i18n.t(
                zhHans: '皮肤主题',
                zhHant: '主題樣式',
                en: 'Theme',
                ja: 'テーマ',
                ko: '테마',
              ),
              value: _themeText(themeData.selectedThemeType, i18n),
              onTap: () => _showThemeSheet(context, themeData),
            ),
            SettingsCell(
              title: i18n.t(
                zhHans: '字体大小',
                zhHant: '字體大小',
                en: 'Font Size',
                ja: '文字サイズ',
                ko: '글자 크기',
              ),
              value: FontSizePage.labelForScale(localSetting.chatFontScale),
              onTap: () => _open(context, const FontSizePage()),
            ),
            SettingsCell(
              title: i18n.t(
                zhHans: '全局默认聊天背景',
                zhHant: '全域預設聊天背景',
                en: 'Default Chat Background',
                ja: '全体デフォルトのチャット背景',
                ko: '전체 기본 채팅 배경',
              ),
              onTap: () => _open(
                context,
                ChatBackgroundPage(
                  conversationId:
                      ChatBackgroundService.globalBackgroundConversationId,
                  conversationName: i18n.t(
                    zhHans: '全部聊天',
                    zhHant: '全部聊天',
                    en: 'All Chats',
                    ja: 'すべてのチャット',
                    ko: '모든 채팅',
                  ),
                ),
              ),
            ),
            SettingsCell(
              title: i18n.t(
                zhHans: '多语言选择',
                zhHant: '多語言選擇',
                en: 'Language',
                ja: '言語',
                ko: '언어',
              ),
              value: LanguageSwitchSheet.languageText(
                localSetting.language,
                i18n,
              ),
              showDivider: false,
              onTap: () => LanguageSwitchSheet.show(context, localSetting),
            ),
          ],
        ),
      ],
    );
  }
}
