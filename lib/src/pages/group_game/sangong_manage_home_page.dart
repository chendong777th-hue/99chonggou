import 'package:flutter/material.dart';
import 'package:tencent_cloud_chat_demo/src/i18n/app_i18n.dart';
import 'package:tencent_cloud_chat_demo/src/navigation/app_page_transitions.dart';
import 'package:tencent_cloud_chat_demo/src/models/sangong_my_config.dart';
import 'package:tencent_cloud_chat_demo/src/pages/group_game/sangong_game_rules_settings_page.dart';
import 'package:tencent_cloud_chat_demo/src/pages/group_game/sangong_members_page.dart';
import 'package:tencent_cloud_chat_demo/src/pages/group_game/sangong_my_config_page.dart';
import 'package:tencent_cloud_chat_demo/src/pages/settings/settings_widgets.dart';
import 'package:tencent_cloud_chat_demo/src/theme/app_colors.dart';

/// 三公管理首页：规则 / 我的配置 / 成员管理（按角色显示）。
class SangongManageHomePage extends StatelessWidget {
  const SangongManageHomePage({
    super.key,
    required this.gameGroupId,
    this.tenantId = '',
    this.canEditConfig = false,
    this.canManageMembers = false,
    this.needsSetup = false,
    this.floatVisible,
    this.onFloatVisibleChanged,
    this.onConfigSaved,
  });

  final String gameGroupId;
  final String tenantId;
  final bool canEditConfig;
  final bool canManageMembers;
  final bool needsSetup;
  final bool? floatVisible;
  final ValueChanged<bool>? onFloatVisibleChanged;
  final ValueChanged<SangongMyConfig>? onConfigSaved;

  static Future<void> open(
    BuildContext context, {
    required String gameGroupId,
    String tenantId = '',
    bool canEditConfig = false,
    bool canManageMembers = false,
    bool needsSetup = false,
    bool? floatVisible,
    ValueChanged<bool>? onFloatVisibleChanged,
    ValueChanged<SangongMyConfig>? onConfigSaved,
  }) {
    if (needsSetup) {
      return SangongMyConfigPage.open(
        context,
        initialGameGroupId: gameGroupId,
        onSaved: onConfigSaved,
      ).then((_) {});
    }
    return Navigator.of(context).push<void>(
      AppMaterialPageRoute(
        settings: const RouteSettings(name: 'sangong_manage_home'),
        builder: (_) => SangongManageHomePage(
          gameGroupId: gameGroupId,
          tenantId: tenantId,
          canEditConfig: canEditConfig,
          canManageMembers: canManageMembers,
          floatVisible: floatVisible,
          onFloatVisibleChanged: onFloatVisibleChanged,
          onConfigSaved: onConfigSaved,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final i18n = AppI18n.of(context);
    final dark = settingsIsDark(context);
    return SettingsScaffold(
      title: i18n.t(zhHans: '三公管理', zhHant: '三公管理', en: 'Sangong'),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Text(
            i18n.t(
              zhHans: '群主可改配置与帮工；帮工仅可使用聊天页操作台跑局。',
              zhHant: '群主可改配置與幫工；幫工僅可使用聊天頁操作台跑局。',
              en: 'Owners manage config and helpers; helpers use the console.',
            ),
            style: TextStyle(
              color: AppColors.subText(dark: dark),
              fontSize: 13,
              height: 1.35,
            ),
          ),
        ),
        SettingsGroup(
          children: [
            SettingsCell(
              title: i18n.t(
                zhHans: '游戏规则',
                zhHant: '遊戲規則',
                en: 'Game rules',
              ),
              value: i18n.t(
                zhHans: '门数 / 赔率 / 开机关机',
                zhHant: '門數 / 賠率 / 開關機',
                en: 'Doors / odds / session',
              ),
              onTap: () {
                SangongGameRulesSettingsPage.open(
                  context,
                  floatVisible: floatVisible,
                  onFloatVisibleChanged: onFloatVisibleChanged,
                );
              },
            ),
            if (canEditConfig)
              SettingsCell(
                title: i18n.t(
                  zhHans: '我的配置',
                  zhHant: '我的配置',
                  en: 'My config',
                ),
                value: i18n.t(
                  zhHans: '下注群 / 结账群 / 机器人',
                  zhHant: '下注群 / 結賬群 / 機器人',
                  en: 'Groups / bot',
                ),
                showDivider: canManageMembers,
                onTap: () {
                  SangongMyConfigPage.open(
                    context,
                    initialGameGroupId: gameGroupId,
                    onSaved: onConfigSaved,
                  );
                },
              ),
            if (canManageMembers)
              SettingsCell(
                title: i18n.t(
                  zhHans: '成员管理',
                  zhHant: '成員管理',
                  en: 'Members',
                ),
                value: i18n.t(
                  zhHans: '添加帮工',
                  zhHant: '添加幫工',
                  en: 'Helpers',
                ),
                showDivider: false,
                onTap: () {
                  SangongMembersPage.open(context);
                },
              ),
          ],
        ),
      ],
    );
  }
}
