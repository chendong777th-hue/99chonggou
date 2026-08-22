import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tencent_cloud_chat_demo/src/i18n/app_i18n.dart';
import 'package:tencent_cloud_chat_demo/src/provider/theme.dart';
import 'package:tencent_cloud_chat_demo/src/utils/secure_webview.dart';
import 'package:tencent_cloud_chat_uikit/theme/color.dart';
import 'package:webview_flutter/webview_flutter.dart';

class WebviewPage extends StatelessWidget {
  const WebviewPage({Key? key, required this.url}) : super(key: key);

  final String url;

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<DefaultThemeData>(context).theme;
    final initialUri = SecureWebViewPolicy.parseInitialUri(url);
    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        iconTheme: const IconThemeData(
          color: Colors.white,
        ),
        shadowColor: theme.weakDividerColor,
        elevation: 1,
        title: Text(
          AppI18n.of(context).t(
            zhHans: '腾讯云即时通信IM',
            zhHant: '騰訊雲即時通信IM',
            en: 'Tencent Cloud Chat IM',
            ja: 'Tencent Cloud Chat IM',
            ko: 'Tencent Cloud Chat IM',
          ),
          style: const TextStyle(fontSize: 17),
        ),
        leading: SizedBox(
            child: IconButton(
          padding: const EdgeInsets.only(left: 16),
          icon: Image.asset(
            'images/arrow_back.png',
            package: 'tencent_cloud_chat_uikit',
            height: 34,
            width: 34,
          ),
          // 返回Home事件
          onPressed: () => {Navigator.pop(context)},
        )),
        centerTitle: true,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [
              theme.lightPrimaryColor ?? CommonColor.lightPrimaryColor,
              theme.primaryColor ?? CommonColor.primaryColor
            ]),
          ),
        ),
      ),
      body: SizedBox(
        width: MediaQuery.of(context).size.width,
        child: initialUri == null
            ? Center(
                child: Text(
                  AppI18n.of(context).t(
                    zhHans: '仅支持打开 HTTPS 网页',
                    zhHant: '僅支援開啟 HTTPS 網頁',
                    en: 'Only HTTPS pages are supported.',
                    ja: 'HTTPS ページのみ開けます。',
                    ko: 'HTTPS 페이지만 열 수 있습니다.',
                  ),
                ),
              )
            : WebViewWidget(
                controller: WebViewController()
                  ..setJavaScriptMode(JavaScriptMode.disabled)
                  ..setNavigationDelegate(
                    SecureWebViewPolicy.navigationDelegate(
                      initialUri: initialUri,
                    ),
                  )
                  ..loadRequest(initialUri),
              ),
      ),
    );
  }
}
