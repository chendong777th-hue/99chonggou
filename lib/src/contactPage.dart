// ignore_for_file: file_names, unnecessary_import

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:tencent_cloud_chat_demo/src/i18n/app_i18n.dart';
import 'package:tencent_chat_i18n_tool/language_json/strings.g.dart';
import 'package:tencent_chat_i18n_tool/tools/i18n_tool.dart';

import 'package:tencent_cloud_chat_demo/src/provider/theme.dart';
// ignore: unused_import
import 'package:tencent_cloud_chat_demo/utils/toast.dart';
import 'package:tencent_cloud_chat_uikit/theme/color.dart';
import 'package:url_launcher/url_launcher.dart';

class ContactPage extends StatefulWidget {
  const ContactPage({Key? key}) : super(key: key);

  @override
  State<ContactPage> createState() => _ContactPageState();
}

class _ContactPageState extends State<ContactPage> {
  bool isInternational = true;

  @override
  void initState() {
    super.initState();
    setLanguage();
  }

  void setLanguage() {
    final String? deviceLocale =
        WidgetsBinding.instance.window.locale.toLanguageTag();
    final AppLocale appLocale = I18nUtils.findDeviceLocale(deviceLocale);
    String languageType =
        (appLocale == AppLocale.zhHans || appLocale == AppLocale.zhHant)
            ? 'zh'
            : 'other';
    setState(() {
      isInternational = (languageType == "zh") ? false : true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final i18n = AppI18n.of(context);
    final theme = Provider.of<DefaultThemeData>(context).theme;
    final appBarBackgroundColor = theme.appbarBgColor ?? Colors.white;
    return Scaffold(
      backgroundColor: theme.weakBackgroundColor ?? hexToColor("ecf3fe"),
      appBar: AppBar(
        backgroundColor: appBarBackgroundColor,
        surfaceTintColor: Colors.transparent,
        iconTheme: IconThemeData(
          color: theme.primaryColor ?? const Color(0xFF1E90FF),
        ),
        shadowColor: theme.weakDividerColor,
        elevation: 1,
        title: Text(
          i18n.t(
            zhHans: '联系我们',
            zhHant: '聯繫我們',
            en: 'Contact Us',
            ja: 'お問い合わせ',
            ko: '문의하기',
          ),
          style: TextStyle(
            color: theme.primaryColor ?? const Color(0xFF1E90FF),
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: Container(
        width: MediaQuery.of(context).size.width,
        decoration: BoxDecoration(
          color: theme.weakBackgroundColor ?? hexToColor("ecf3fe"),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              // 因为底部有波浪图， icon向上一点，感觉视觉上更协调
              margin: const EdgeInsets.only(bottom: 40),
              child: Column(
                children: [
                  Text(
                    i18n.t(
                      zhHans: '欢迎前往知聊社区参与讨论',
                      zhHant: '歡迎前往知聊社群參與討論',
                      en: 'Join the Zhiliao community to discuss',
                      ja: '知聊コミュニティで議論に参加しましょう',
                      ko: '지료 커뮤니티에서 토론에 참여해 보세요',
                    ),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 18,
                      color: theme.darkTextColor,
                    ),
                  ),
                  Container(
                    margin: const EdgeInsets.only(top: 20, bottom: 100),
                    child: SelectableText(
                      i18n.t(
                        zhHans: 'zhiliao.qq.com',
                        zhHant: 'zhiliao.qq.com',
                        en: 'zhiliao.qq.com',
                        ja: 'zhiliao.qq.com',
                        ko: 'zhiliao.qq.com',
                      ),
                      style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w600,
                          color: theme.primaryColor),
                    ),
                  ),
                  Text(
                    i18n.t(
                      zhHans: '此社区使用本 App 同款 Flutter UIKit 完成全平台开发',
                      zhHant: '此社群使用本 App 同款 Flutter UIKit 完成全平台開發',
                      en: 'This community app is built with the same Flutter UIKit',
                      ja: 'このコミュニティは同じ Flutter UIKit で開発されています',
                      ko: '이 커뮤니티는 동일한 Flutter UIKit으로 개발되었습니다',
                    ),
                    style: TextStyle(
                      color: theme.darkTextColor,
                    ),
                  ),
                  Container(
                    margin: const EdgeInsets.only(top: 20),
                    child: ElevatedButton(
                      onPressed: () {
                        if (isInternational) {
                          launchUrl(
                            Uri.parse("https://t.me/+1doS9AUBmndhNGNl"),
                            mode: LaunchMode.externalApplication,
                          );
                        } else {
                          launchUrl(
                            Uri.parse(
                                "https://zhiliao.qq.com/s/c5GY7HIM62CK/c6RDBIIM62CQ"),
                            mode: LaunchMode.externalApplication,
                          );
                        }
                      },
                      child: Text(i18n.t(
                        zhHans: '前往知聊社区',
                        zhHant: '前往知聊社群',
                        en: 'Go to Zhiliao Community',
                        ja: '知聊コミュニティへ',
                        ko: '지료 커뮤니티로 이동',
                      )),
                    ),
                  ),
                ],
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisAlignment: MainAxisAlignment.center,
              ),
            ),
            Positioned(
              bottom: 0,
              child: Image.asset(
                "assets/logo_bottom.png",
                fit: BoxFit.fitWidth,
                width: MediaQuery.of(context).size.width,
              ),
            )
          ],
        ),
      ),
    );
  }
}
