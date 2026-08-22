import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:tencent_cloud_chat_sdk/manager/v2_tim_manager.dart';
import 'package:tencent_cloud_chat_uikit/tencent_cloud_chat_uikit.dart';
import 'package:tencent_cloud_chat_demo/src/cancel_account.dart';
import 'package:tencent_cloud_chat_demo/src/i18n/app_i18n.dart';
import 'package:tencent_cloud_chat_demo/src/provider/theme.dart';
import 'package:tencent_cloud_chat_demo/src/utils/app_version.dart';
import 'package:tencent_cloud_chat_uikit/theme/color.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:tencent_cloud_chat_demo/config.dart';
import 'package:provider/provider.dart';
import 'contactPage.dart';
import 'pages/privacy/privacy_webview.dart';
import 'package:tencent_cloud_chat_demo/src/navigation/app_page_transitions.dart';
import 'package:tencent_cloud_chat_demo/src/widgets/app_dialog.dart';

class About extends StatefulWidget {
  const About({Key? key}) : super(key: key);

  @override
  State<StatefulWidget> createState() => AboutState();
}

class AboutState extends State<About> {
  final V2TIMManager sdkInstance = TIMUIKitCore.getSDKInstance();
  String sdkVersion = "null";
  String appDisplayVersion = IMDemoConfig.appVersion;

  Widget aboutItem(String label, Function onClick, [String? rightText]) {
    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: Color(int.parse('ededed', radix: 16)).withAlpha(255),
            width: 1,
            style: BorderStyle.solid,
          ),
        ),
      ),
      child: InkWell(
        onTap: () {
          onClick();
        },
        child: TIMUIKitOperationItem(
          isEmpty: label.isEmpty,
          operationName: label,
          showAllowEditStatus: !(rightText != null && rightText.isNotEmpty),
          operationRightWidget: Text(rightText ?? "", textAlign: TextAlign.end),
        ),
      ),
    );
  }

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

  Future<void> _showDisclaimer() async {
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
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<DefaultThemeData>(context).theme;
    final i18n = AppI18n.of(context);
    return Scaffold(
      appBar: AppBar(
        iconTheme: IconThemeData(
          color: theme.primaryColor ?? const Color(0xFF1E90FF),
        ),
        shadowColor: theme.weakDividerColor,
        elevation: 1,
        title: Text(
          i18n.t(
            zhHans: '关于腾讯云 · IM',
            zhHant: '關於騰訊雲 · IM',
            en: 'About Tencent Cloud · IM',
            ja: 'Tencent Cloud · IM について',
            ko: 'Tencent Cloud · IM 정보',
          ),
          style: const TextStyle(fontSize: IMDemoConfig.appBarTitleFontSize),
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
      body: Column(
        children: [
          aboutItem(
            i18n.t(
              zhHans: 'SDK版本号',
              zhHant: 'SDK版本號',
              en: 'SDK Version',
              ja: 'SDKバージョン',
              ko: 'SDK 버전',
            ),
            () {},
            sdkVersion,
          ),
          aboutItem(
            i18n.t(
              zhHans: '应用版本号',
              zhHant: '應用版本號',
              en: 'App Version',
              ja: 'アプリバージョン',
              ko: '앱 버전',
            ),
            () {},
            appDisplayVersion,
          ),
          const SizedBox(
            height: 12,
          ),
          aboutItem(
            i18n.t(
              zhHans: '隐私政策',
              zhHant: '隱私政策',
              en: 'Privacy Policy',
              ja: 'プライバシーポリシー',
              ko: '개인정보 처리방침',
            ),
            () {
            if (kIsWeb) {
              launchUrl(
                Uri.parse(
                    "https://privacy.qq.com/document/preview/1cfe904fb7004b8ab1193a55857f7272"),
                mode: LaunchMode.externalApplication,
              );
              return;
            }
            Navigator.push(
                context,
                AppMaterialPageRoute(
                    builder: (context) => PrivacyDocument(
                        title: i18n.t(
                          zhHans: '隐私政策',
                          zhHant: '隱私政策',
                          en: 'Privacy Policy',
                          ja: 'プライバシーポリシー',
                          ko: '개인정보 처리방침',
                        ),
                        url:
                            "https://privacy.qq.com/document/preview/1cfe904fb7004b8ab1193a55857f7272")));
          }),
          aboutItem(
            i18n.t(
              zhHans: '用户协议',
              zhHant: '用戶協議',
              en: 'User Agreement',
              ja: '利用規約',
              ko: '이용약관',
            ),
            () {
            if (kIsWeb) {
              launchUrl(
                Uri.parse(
                    "https://web.sdk.qcloud.com/document/Tencent-IM-User-Agreement.html"),
                mode: LaunchMode.externalApplication,
              );
              return;
            }
            Navigator.push(
                context,
                AppMaterialPageRoute(
                    builder: (context) => PrivacyDocument(
                        title: i18n.t(
                          zhHans: '用户协议',
                          zhHant: '用戶協議',
                          en: 'User Agreement',
                          ja: '利用規約',
                          ko: '이용약관',
                        ),
                        url:
                            "https://web.sdk.qcloud.com/document/Tencent-IM-User-Agreement.html")));
          }),
          aboutItem(
            i18n.t(
              zhHans: '免责声明',
              zhHant: '免責聲明',
              en: 'Disclaimer',
              ja: '免責事項',
              ko: '면책 조항',
            ),
            () {
              _showDisclaimer();
            }),
          const SizedBox(
            height: 12,
          ),
          aboutItem(
            i18n.t(
              zhHans: '信息收集清单',
              zhHant: '資訊收集清單',
              en: 'Data Collection List',
              ja: '情報収集リスト',
              ko: '정보 수집 목록',
            ),
            () {
            if (kIsWeb) {
              launchUrl(
                Uri.parse(
                    "https://privacy.qq.com/document/preview/45ba982a1ce6493597a00f8c86b52a1e"),
                mode: LaunchMode.externalApplication,
              );
              return;
            }
            Navigator.push(
                context,
                AppMaterialPageRoute(
                    builder: (context) => PrivacyDocument(
                        title: i18n.t(
                          zhHans: '信息收集清单',
                          zhHant: '資訊收集清單',
                          en: 'Data Collection List',
                          ja: '情報収集リスト',
                          ko: '정보 수집 목록',
                        ),
                        url:
                            "https://privacy.qq.com/document/preview/45ba982a1ce6493597a00f8c86b52a1e")));
          }),
          aboutItem(
            i18n.t(
              zhHans: '信息共享清单',
              zhHant: '資訊共享清單',
              en: 'Data Sharing List',
              ja: '情報共有リスト',
              ko: '정보 공유 목록',
            ),
            () {
            if (kIsWeb) {
              launchUrl(
                Uri.parse(
                    "https://privacy.qq.com/document/preview/dea84ac4bb88454794928b77126e9246"),
                mode: LaunchMode.externalApplication,
              );
              return;
            }
            Navigator.push(
                context,
                AppMaterialPageRoute(
                    builder: (context) => PrivacyDocument(
                        title: i18n.t(
                          zhHans: '信息共享清单',
                          zhHant: '資訊共享清單',
                          en: 'Data Sharing List',
                          ja: '情報共有リスト',
                          ko: '정보 공유 목록',
                        ),
                        url:
                            "https://privacy.qq.com/document/preview/dea84ac4bb88454794928b77126e9246")));
          }),
          const SizedBox(
            height: 12,
          ),
          aboutItem(
            i18n.t(
              zhHans: '注销账户',
              zhHant: '註銷帳戶',
              en: 'Delete Account',
              ja: 'アカウント削除',
              ko: '계정 삭제',
            ),
            () {
            Navigator.push(
              context,
              AppMaterialPageRoute(
                builder: (context) => CancelAccount(),
              ),
            );
          }),
          aboutItem(
            i18n.t(
              zhHans: '联系我们',
              zhHant: '聯繫我們',
              en: 'Contact Us',
              ja: 'お問い合わせ',
              ko: '문의하기',
            ),
            () {
            Navigator.push(
              context,
              AppMaterialPageRoute(
                builder: (context) => const ContactPage(),
              ),
            );
          }),
        ],
      ),
    );
  }
}
