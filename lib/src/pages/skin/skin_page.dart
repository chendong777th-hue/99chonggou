import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tencent_cloud_chat_demo/src/i18n/app_i18n.dart';
import 'package:tencent_cloud_chat_demo/src/provider/theme.dart';
import 'package:tencent_cloud_chat_demo/utils/theme.dart';
import 'package:tencent_cloud_chat_uikit/theme/color.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/screen_utils.dart';

class SkinPage extends StatelessWidget {
  const SkinPage({Key? key}) : super(key: key);

  static String themeName(ThemeType type, AppI18n i18n) {
    switch (type) {
      case ThemeType.system:
        return i18n.t(
          zhHans: '跟随系统',
          zhHant: '跟隨系統',
          en: 'Follow System',
          ja: 'システムに合わせる',
          ko: '시스템 설정 따르기',
        );
      case ThemeType.dark:
        return i18n.t(
          zhHans: '深色主题',
          zhHant: '深色主題',
          en: 'Dark Theme',
          ja: 'ダークテーマ',
          ko: '다크 테마',
        );
      case ThemeType.blue:
        return i18n.t(
          zhHans: '日间主题',
          zhHant: '日間主題',
          en: 'Light Theme',
          ja: 'ライトテーマ',
          ko: '라이트 테마',
        );
    }
  }

  List<Widget> skinBuilder() => ThemeType.values
      .map((type) => SkinCube(
            currentThemeType: type,
          ))
      .toList();

  @override
  Widget build(BuildContext context) {
    final i18n = AppI18n.of(context);
    final theme = Provider.of<DefaultThemeData>(context).theme;

    return TUIKitScreenUtils.getDeviceWidget(
        context: context,
        desktopWidget: Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: skinBuilder()
              .map((e) => Container(
            margin: const EdgeInsets.only(right: 30),
            child: e,
          ))
              .toList(),
        ),
        defaultWidget: Scaffold(
            appBar: AppBar(
              iconTheme: IconThemeData(
                color: theme.primaryColor ?? const Color(0xFF1E90FF),
              ),
              shadowColor: theme.weakDividerColor,
              elevation: 1,
              title: Text(
                i18n.t(
                  zhHans: '主题',
                  zhHant: '主題',
                  en: 'Theme',
                  ja: 'テーマ',
                  ko: '테마',
                ),
                style: const TextStyle(color: Colors.white, fontSize: 17),
              ),
              flexibleSpace: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [
                    theme.lightPrimaryColor ?? CommonColor.lightPrimaryColor,
                    theme.primaryColor ?? CommonColor.primaryColor
                  ]),
                ),
              ),
            ),
            body: Container(
                padding: const EdgeInsets.only(top: 16),
                height: MediaQuery.of(context).size.height,
                width: MediaQuery.of(context).size.width,
                color: theme.weakBackgroundColor,
                child: Wrap(
                  spacing: 16.0, // 主轴(水平)方向间距
                  runSpacing: 16.0, // 纵轴（垂直）方向间距
                  alignment: WrapAlignment.center, //沿主轴方向居中
                  children: skinBuilder(),
                ))));
  }
}

class SkinCube extends StatelessWidget {
  final ThemeType currentThemeType;

  const SkinCube({Key? key, required this.currentThemeType}) : super(key: key);

  void onThemeChanged(BuildContext context, ThemeType type) {
    final selectedThemeType =
        Provider.of<DefaultThemeData>(context, listen: false).currentThemeType;
    if (selectedThemeType != type) {
      Provider.of<DefaultThemeData>(context, listen: false).currentThemeType =
          type;
    }
  }

  @override
  Widget build(BuildContext context) {
    final i18n = AppI18n.of(context);
    final themeType = Provider.of<DefaultThemeData>(context).currentThemeType;
    final previewTheme = DefTheme.getTheme(currentThemeType);
    final isWideScreen =
        TUIKitScreenUtils.getFormFactor(context) == DeviceType.Desktop;

    return SizedBox(
        height: 128,
        width: MediaQuery.of(context).size.width * (isWideScreen ? 0.12 : 0.45),
        child: GestureDetector(
            onTap: () {
              onThemeChanged(context, currentThemeType);
            },
            child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.all(Radius.circular(8)),
                  gradient: LinearGradient(colors: [
                    previewTheme.lightPrimaryColor ??
                        CommonColor.lightPrimaryColor,
                    previewTheme.primaryColor ??
                        CommonColor.primaryColor
                  ]),
                ),
                child: Stack(
                  children: [
                    Positioned(
                      top: 0,
                      right: 0,
                      child: Checkbox(
                          onChanged: (bool? value) {
                            if (value != null && value == true) {
                              onThemeChanged(context, currentThemeType);
                            }
                          },
                          value: themeType == currentThemeType,
                          side: const BorderSide(color: Colors.white, width: 1),
                          shape: const CircleBorder()),
                    ),
                    Positioned(
                        bottom: 0,
                        child: Container(
                            width: MediaQuery.of(context).size.width *
                                (isWideScreen ? 0.12 : 0.45),
                            height: 32,
                            decoration: BoxDecoration(
                                color: Colors.black.withAlpha(64),
                                borderRadius: const BorderRadius.vertical(
                                    bottom: Radius.circular(8))),
                            child: Center(
                                child: Text(
                                    SkinPage.themeName(
                                      currentThemeType,
                                      i18n,
                                    ),
                                    style: const TextStyle(
                                        color: Colors.white, fontSize: 16)))))
                  ],
                ))));
  }
}
