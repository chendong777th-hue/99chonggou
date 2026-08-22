import 'package:flutter/material.dart';
import 'package:tencent_cloud_chat_demo/src/i18n/app_i18n.dart';
import 'package:tencent_cloud_chat_demo/src/pages/settings/settings_widgets.dart';
import 'package:tencent_cloud_chat_demo/src/theme/app_colors.dart';

class HelpCenterPage extends StatelessWidget {
  const HelpCenterPage({super.key});

  @override
  Widget build(BuildContext context) {
    var dark = settingsIsDark(context);
    final i18n = AppI18n.of(context);

    return SettingsScaffold(
      title: i18n.t(
        zhHans: '帮助中心',
        zhHant: '幫助中心',
        en: 'Help Center',
        ja: 'ヘルプセンター',
        ko: '도움말 센터',
      ),
      children: [
        SettingsGroup(
          children: [
            Container(
              width: double.infinity,
              constraints: const BoxConstraints(minHeight: 180),
              padding: const EdgeInsets.all(16),
              child: Text(
                '',
                style: TextStyle(
                  color: AppColors.text(dark: dark),
                  fontSize: 15,
                  height: 1.5,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
