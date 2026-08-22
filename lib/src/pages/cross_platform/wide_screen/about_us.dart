import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:tencent_cloud_chat_demo/config.dart';
import 'package:tencent_cloud_chat_demo/src/api/platform_api.dart';
import 'package:tencent_cloud_chat_demo/src/i18n/app_i18n.dart';
import 'package:tencent_cloud_chat_demo/src/provider/theme.dart';
import 'package:tencent_cloud_chat_demo/src/utils/app_version.dart';
import 'package:tencent_cloud_chat_demo/utils/commonUtils.dart';
import 'package:tencent_cloud_chat_sdk/manager/v2_tim_manager.dart';
import 'package:tencent_cloud_chat_uikit/tencent_cloud_chat_uikit.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:tencent_cloud_chat_demo/src/widgets/app_dialog.dart';

class AboutUs extends StatefulWidget {
  final VoidCallback closeFunc;
  const AboutUs({Key? key, required this.closeFunc}) : super(key: key);

  @override
  State<AboutUs> createState() => _AboutUsState();
}

class _AboutUsState extends State<AboutUs> {
  final V2TIMManager sdkInstance = TIMUIKitCore.getSDKInstance();
  String sdkVersion = "null";
  String appDisplayVersion = IMDemoConfig.appVersion;
  String _website = '';
  bool _loadingWebsite = true;

  void getSDKVersion() async {
    final versionValue = await sdkInstance.getVersion();
    setState(() {
      sdkVersion = versionValue.data ?? "null";
    });
  }

  void getAppVersion() async {
    final version = await AppVersion.getDisplayVersion();
    if (!mounted) return;
    setState(() {
      appDisplayVersion = version;
    });
  }

  Future<void> _loadWebsite() async {
    try {
      final info = await PlatformApi.instance.fetchContact();
      if (!mounted) return;
      setState(() {
        _website = info.website.trim();
        _loadingWebsite = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _website = '';
        _loadingWebsite = false;
      });
    }
  }

  Future<void> _showDisclaimer() async {
    widget.closeFunc();
    final i18n = AppI18n.of(context);
    await AppDialog.alert(
      title: i18n.t(
        zhHans: '免责声明',
        zhHant: '免責聲明',
        en: 'Disclaimer',
        ja: '免責事項',
        ko: '면책 조항',
      ),
      message: i18n.t(
        zhHans:
            '99Chat APP（“本产品”）是由腾讯云提供的一款测试产品，腾讯云享有本产品的著作权和所有权。本产品仅用于功能体验，不得用于任何商业用途。严禁在使用中有任何色情、辱骂、暴恐、涉政等违法内容传播。',
        zhHant:
            '99Chat APP（「本產品」）是由騰訊雲提供的一款測試產品，騰訊雲享有本產品的著作權和所有權。本產品僅用於功能體驗，不得用於任何商業用途。嚴禁在使用中有任何色情、辱罵、暴恐、涉政等違法內容傳播。',
        en:
            '99Chat APP ("this product") is a test product provided by Tencent Cloud. Tencent Cloud owns the copyright and ownership of this product. This product is for functional experience only and may not be used for any commercial purpose. Illegal content such as pornography, abuse, violence, or politically sensitive material is strictly prohibited.',
        ja:
            '99Chat APP（本製品）は Tencent Cloud が提供するテスト製品です。Tencent Cloud は本製品の著作権および所有権を有します。本製品は機能体験のみを目的としており、商用利用はできません。わいせつ、侮辱、暴力、政治的内容などの違法コンテンツの配信は禁止されています。',
        ko:
            '99Chat APP(본 제품)은 Tencent Cloud가 제공하는 테스트 제품입니다. Tencent Cloud는 본 제품의 저작권 및 소유권을 보유합니다. 본 제품은 기능 체험용이며 상업적 이용이 금지됩니다. 음란, 욕설, 폭력, 정치적 내용 등 불법 콘텐츠 전송은 엄격히 금지됩니다.',
      ),
      buttonText: i18n.t(
        zhHans: '知道了',
        zhHant: '知道了',
        en: 'OK',
        ja: 'OK',
        ko: '확인',
      ),
    );
  }

  @override
  void initState() {
    getSDKVersion();
    getAppVersion();
    _loadWebsite();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<DefaultThemeData>(context).theme;
    final i18n = AppI18n.of(context);
    final officialWebsiteTitle = i18n.t(
      zhHans: '官方网站',
      zhHant: '官方網站',
      en: 'Official Website',
      ja: '公式サイト',
      ko: '공식 웹사이트',
    );
    final officialWebsiteLabel = _loadingWebsite
        ? i18n.t(
            zhHans: '官方网站（获取中）',
            zhHant: '官方網站（讀取中）',
            en: 'Official Website (Loading)',
            ja: '公式サイト（読み込み中）',
            ko: '공식 웹사이트 (불러오는 중)',
          )
        : (_website.isNotEmpty
            ? officialWebsiteTitle
            : i18n.t(
                zhHans: '官方网站（未配置）',
                zhHant: '官方網站（未設定）',
                en: 'Official Website (Not configured)',
                ja: '公式サイト（未設定）',
                ko: '공식 웹사이트 (설정되지 않음)',
              ));

    TextSpan webViewLink(String title, [String? url]) {
      return TextSpan(
        text: title,
        style: const TextStyle(
          fontSize: 12,
          color: Color.fromRGBO(0, 110, 253, 1),
        ),
        recognizer: url == null
            ? null
            : (TapGestureRecognizer()
              ..onTap = () {
                launchUrl(
                  Uri.parse(url),
                  mode: LaunchMode.externalApplication,
                );
              }),
      );
    }

    return Container(
      padding: const EdgeInsets.all(20),
      child: Stack(
        children: [
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text.rich(TextSpan(children: [
                  webViewLink(
                    officialWebsiteLabel,
                    _website.isNotEmpty ? _website : null,
                  ),
                  webViewLink("  |  "),
                  webViewLink(i18n.t(
                    zhHans: '所有 SDK',
                    zhHant: '所有 SDK',
                    en: 'All SDKs',
                    ja: 'すべてのSDK',
                    ko: '모든 SDK',
                  ), "https://pub.dev/publishers/comm.qq.com/packages"),
                  webViewLink("  |  "),
                  webViewLink(i18n.t(
                    zhHans: '源代码',
                    zhHant: '原始碼',
                    en: 'Source Code',
                    ja: 'ソースコード',
                    ko: '소스 코드',
                  ), "https://github.com/TencentCloud/chat-demo-flutter"),
                ])),
                const SizedBox(
                  height: 4,
                ),
                Text.rich(TextSpan(children: [
                  webViewLink(i18n.t(
                    zhHans: '隐私政策',
                    zhHant: '隱私政策',
                    en: 'Privacy Policy',
                    ja: 'プライバシーポリシー',
                    ko: '개인정보 처리방침',
                  ), "https://privacy.qq.com/document/preview/1cfe904fb7004b8ab1193a55857f7272"),
                  webViewLink("  |  "),
                  webViewLink(i18n.t(
                    zhHans: '用户协议',
                    zhHant: '用戶協議',
                    en: 'User Agreement',
                    ja: '利用規約',
                    ko: '이용약관',
                  ), "https://web.sdk.qcloud.com/document/Tencent-IM-User-Agreement.html"),
                  webViewLink("  |  "),
                  webViewLink(i18n.t(
                    zhHans: '信息收集清单',
                    zhHant: '資訊收集清單',
                    en: 'Data Collection List',
                    ja: '情報収集リスト',
                    ko: '정보 수집 목록',
                  ), "https://privacy.qq.com/document/preview/45ba982a1ce6493597a00f8c86b52a1e"),
                  webViewLink("  |  "),
                  webViewLink(i18n.t(
                    zhHans: '信息共享清单',
                    zhHant: '資訊共享清單',
                    en: 'Data Sharing List',
                    ja: '情報共有リスト',
                    ko: '정보 공유 목록',
                  ), "https://privacy.qq.com/document/preview/dea84ac4bb88454794928b77126e9246"),
                ])),
                const SizedBox(
                  height: 10,
                ),
                Text(
                  "Copyright © 2013-2023 Tencent Cloud. All Rights Reserved. 腾讯云 版权所有",
                  style: TextStyle(color: theme.weakTextColor, fontSize: 12),
                ),
              ],
            ),
          ),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                height: CommonUtils.adaptWidth(100),
                child: const Image(
                  image: AssetImage("assets/logo.png"),
                ),
              ),
              const SizedBox(
                height: 20,
              ),
              Text(
                i18n.t(
                  zhHans: '腾讯云即时通信IM',
                  zhHant: '騰訊雲即時通信IM',
                  en: 'Tencent Cloud Chat',
                  ja: 'Tencent Cloud チャット',
                  ko: 'Tencent Cloud 채팅',
                ),
                style: TextStyle(
                  color: theme.darkTextColor,
                  fontSize: CommonUtils.adaptFontSize(40),
                ),
              ),
              const SizedBox(
                height: 20,
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    i18n.t(
                      zhHans: 'SDK版本号',
                      zhHant: 'SDK版本號',
                      en: 'SDK Version',
                      ja: 'SDKバージョン',
                      ko: 'SDK 버전',
                    ),
                    style: TextStyle(color: theme.weakTextColor),
                  ),
                  Text(
                    ": $sdkVersion",
                    style: TextStyle(color: theme.weakTextColor),
                  ),
                  const SizedBox(
                    width: 12,
                  ),
                  SizedBox(
                    width: 1,
                    height: 14,
                    child: Container(
                      color: theme.weakTextColor,
                    ),
                  ),
                  const SizedBox(
                    width: 12,
                  ),
                  Text(
                    i18n.t(
                      zhHans: '应用版本号',
                      zhHant: '應用版本號',
                      en: 'App Version',
                      ja: 'アプリバージョン',
                      ko: '앱 버전',
                    ),
                    style: TextStyle(color: theme.weakTextColor),
                  ),
                  Text(
                    ": $appDisplayVersion",
                    style: TextStyle(color: theme.weakTextColor),
                  ),
                ],
              ),
              const SizedBox(
                height: 20,
              ),
              ElevatedButton(
                  onPressed: () {
                    _showDisclaimer();
                  },
                  child: Text(i18n.t(
                    zhHans: '免责声明',
                    zhHant: '免責聲明',
                    en: 'Disclaimer',
                    ja: '免責事項',
                    ko: '면책 조항',
                  ))),
              const SizedBox(
                height: 80,
              ),
            ],
          )
        ],
      ),
    );
  }
}
