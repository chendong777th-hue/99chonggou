import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:tencent_cloud_chat_demo/src/i18n/app_i18n.dart';
import 'package:tencent_cloud_chat_demo/src/provider/theme.dart';
import 'package:tencent_cloud_chat_demo/src/utils/secure_webview.dart';
import 'package:tencent_cloud_chat_uikit/theme/color.dart';
import 'package:webview_flutter/webview_flutter.dart';

class PrivacyDocument extends StatelessWidget {
  final String title;
  final String url;
  const PrivacyDocument({Key? key, required this.title, required this.url})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<DefaultThemeData>(context).theme;
    final initialUri = SecureWebViewPolicy.parseInitialUri(url);
    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        shadowColor: theme.weakDividerColor,
        elevation: 1,
        iconTheme: IconThemeData(
          color: theme.primaryColor ?? const Color(0xFF1E90FF),
        ),
        title: Text(
          title,
          style: const TextStyle(fontSize: 17),
        ),
        leading: BackButton(
          onPressed: () => Navigator.pop(context),
        ),
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
