import 'package:flutter/material.dart';
import 'package:tencent_cloud_chat_demo/src/i18n/app_i18n.dart';
import 'package:tencent_cloud_chat_demo/src/navigation/app_page_transitions.dart';
import 'package:tencent_cloud_chat_demo/src/pages/customer_service/customer_service_webview.dart';
import 'package:tencent_cloud_chat_demo/src/provider/theme.dart';
import 'package:tencent_cloud_chat_demo/src/tencent_page.dart';
import 'package:tencent_cloud_chat_demo/src/utils/group_game_url_builder.dart';
import 'package:tencent_cloud_chat_demo/utils/app_material_theme.dart';
import 'package:tencent_cloud_chat_demo/utils/theme.dart';
import 'package:provider/provider.dart';

class GroupGamePage extends StatelessWidget {
  const GroupGamePage({
    super.key,
    required this.groupId,
    this.groupName,
  });

  final String groupId;
  final String? groupName;

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<DefaultThemeData>(context, listen: false).theme;
    final isDark =
        Provider.of<DefaultThemeData>(context, listen: false).currentThemeType ==
            ThemeType.dark;
    final title = (groupName?.trim().isNotEmpty ?? false)
        ? groupName!.trim()
        : AppI18n.of(context).t(
            zhHans: '群游戏',
            zhHant: '群遊戲',
            en: 'Group Game',
            ja: 'グループゲーム',
            ko: '그룹 게임',
          );

    return TencentPage(
      name: 'group_game',
      child: Scaffold(
        backgroundColor: theme.weakBackgroundColor,
        appBar: AppBar(
          title: Text(title),
          backgroundColor: theme.appbarBgColor,
          foregroundColor: theme.appbarTextColor,
          surfaceTintColor: Colors.transparent,
          systemOverlayStyle: buildAppSystemUiOverlayStyle(theme, isDark: isDark),
        ),
        body: CustomerServiceWebView(
          url: GroupGameUrlBuilder.build(groupId),
        ),
      ),
    );
  }

  static Future<void> open(
    BuildContext context, {
    required String groupId,
    String? groupName,
  }) {
    return Navigator.of(context).push<void>(
      AppMaterialPageRoute(
        settings: const RouteSettings(name: 'group_game'),
        builder: (_) => GroupGamePage(
          groupId: groupId,
          groupName: groupName,
        ),
      ),
    );
  }
}
