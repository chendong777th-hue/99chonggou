
import 'package:flutter/material.dart';
import 'package:tencent_chat_i18n_tool/language_json/strings.g.dart';
import 'package:tencent_chat_i18n_tool/tools/i18n_tool.dart';
import 'package:tencent_cloud_chat_demo/src/i18n/app_i18n.dart';
import 'package:tencent_cloud_chat_demo/src/provider/theme.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

class ContactUs extends StatefulWidget {
  final VoidCallback closeFunc;

  const ContactUs({Key? key, required this.closeFunc}) : super(key: key);

  @override
  State<ContactUs> createState() => _ContactUsState();
}

class _ContactUsState extends State<ContactUs> {
  bool isInternational = true;

  @override
  void initState() {
    super.initState();
    setLanguage();
  }

  void setLanguage(){
    final String? deviceLocale = WidgetsBinding.instance.window.locale.toLanguageTag();
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
    final theme = Provider.of<DefaultThemeData>(context).theme;
    final i18n = AppI18n.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              Text(
                i18n.t(
                  zhHans: '渠道切换：',
                  zhHant: '渠道切換：',
                  en: 'Channel:',
                  ja: 'チャネル切替：',
                  ko: '채널 전환:',
                ),
                style: TextStyle(fontSize: 18, color: theme.darkTextColor),
              ),
              ElevatedButton(
                  onPressed: () {
                    setState(() {
                      isInternational = !isInternational;
                    });
                  },
                  child: Text(isInternational
                      ? i18n.t(
                          zhHans: '中国大陆',
                          zhHant: '中國大陸',
                          en: 'Mainland China',
                          ja: '中国本土',
                          ko: '중국 본토',
                        )
                      : i18n.t(
                          zhHans: '国际',
                          zhHant: '國際',
                          en: 'International',
                          ja: '国際',
                          ko: '국제',
                        ))),
            ],
          ),
          Expanded(
              child: Column(
            mainAxisSize: MainAxisSize.max,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                i18n.t(
                  zhHans: '如果您在使用过程中有任何疑问，请通过如下渠道联系我们',
                  zhHant: '如果您在使用過程中有任何疑問，請透過如下渠道聯繫我們',
                  en:
                      'If you have any questions while using the app, please contact us through the channels below.',
                  ja: 'ご利用中にご不明な点がございましたら、以下のチャネルよりお問い合わせください。',
                  ko: '사용 중 궁금한 점이 있으시면 아래 채널로 문의해 주세요.',
                ),
                style: TextStyle(color: theme.weakTextColor),
              ),
              const SizedBox(
                height: 40,
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Column(
                    children: [
                      Image.asset(
                          isInternational
                              ? "assets/telegram.png"
                              : "assets/wechat_qr.png",
                          height: isInternational ? 80 : 150),
                      const SizedBox(
                        height: 20,
                      ),
                      if (isInternational)
                        const Text(
                          "Telegram",
                          style: TextStyle(fontSize: 16),
                        ),
                      if (!isInternational)
                        Image.asset("assets/wechat.png", height: 30),
                      const SizedBox(
                        height: 20,
                      ),
                      if (isInternational)
                        ElevatedButton(
                            onPressed: () {
                              launchUrl(
                                Uri.parse("https://t.me/+1doS9AUBmndhNGNl"),
                                mode: LaunchMode.externalApplication,
                              );
                            },
                            child: Text(i18n.t(
                              zhHans: '立即进群',
                              zhHant: '立即進群',
                              en: 'Join Now',
                              ja: '今すぐ参加',
                              ko: '지금 참여',
                            ))),
                    ],
                  ),
                  const SizedBox(
                    width: 140,
                  ),
                  Column(
                    children: [
                      Image.asset(
                          isInternational
                              ? "assets/whatsapp.png"
                              : "assets/qq_qr.png",
                          height: isInternational ? 80 : 150),
                      const SizedBox(
                        height: 20,
                      ),
                      if (isInternational)
                        const Text(
                          "WhatsApp",
                          style: TextStyle(fontSize: 16),
                        ),
                      if (!isInternational)
                        Image.asset("assets/qq.png", height: 35),
                      const SizedBox(
                        height: 20,
                      ),
                      if (isInternational)
                        ElevatedButton(
                            onPressed: () {
                              launchUrl(
                                Uri.parse(
                                    "https://chat.whatsapp.com/Gfbxk7rQBqc8Rz4pzzP27A"),
                                mode: LaunchMode.externalApplication,
                              );
                            },
                            child: Text(i18n.t(
                              zhHans: '立即进群',
                              zhHant: '立即進群',
                              en: 'Join Now',
                              ja: '今すぐ参加',
                              ko: '지금 참여',
                            ))),
                    ],
                  )
                ],
              ),
              SizedBox(
                height: isInternational ? 20 : 0,
              ),
              Text(
                i18n.t(
                  zhHans: '在线时间: 周一到周五，早上10点 - 晚上8点',
                  zhHant: '在線時間: 週一到週五，早上10點 - 晚上8點',
                  en: 'Hours: Mon–Fri, 10:00 AM – 8:00 PM',
                  ja: '対応時間: 月〜金 10:00〜20:00',
                  ko: '운영 시간: 월–금 10:00–20:00',
                ),
                style: TextStyle(color: theme.weakTextColor),
              ),
            ],
          ))
        ],
      ),
    );
  }
}
