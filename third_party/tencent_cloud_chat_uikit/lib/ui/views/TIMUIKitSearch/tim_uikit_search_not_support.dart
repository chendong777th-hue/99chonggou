import 'package:flutter/material.dart';
import 'package:tencent_chat_i18n_tool/tencent_chat_i18n_tool.dart';
import 'package:tencent_cloud_chat_uikit/base_widgets/tim_ui_kit_base.dart';
import 'package:tencent_cloud_chat_uikit/base_widgets/tim_ui_kit_statelesswidget.dart';
import 'package:tencent_cloud_chat_uikit/theme/color.dart';

class TIMUIKitSearchNotSupport extends TIMUIKitStatelessWidget {
  /// 宽屏把搜索嵌在列表栏时，必须能返回会话列表；否则会卡在本页。
  final VoidCallback? onBack;

  TIMUIKitSearchNotSupport({Key? key, this.onBack}) : super(key: key);

  @override
  Widget tuiBuild(BuildContext context, TUIKitBuildValue value) {
    final theme = value.theme;
    return Scaffold(
      backgroundColor: hexToColor("ecf3fe"),
      appBar: onBack == null
          ? null
          : AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              scrolledUnderElevation: 0,
              surfaceTintColor: Colors.transparent,
              leading: IconButton(
                tooltip: TIM_t("返回"),
                onPressed: onBack,
                icon: Icon(
                  Icons.arrow_back_ios_new_rounded,
                  size: 18,
                  color: theme.primaryColor ?? hexToColor("147AFF"),
                ),
              ),
            ),
      body: Container(
        width: MediaQuery.of(context).size.width,
        decoration: BoxDecoration(
          color: hexToColor("ecf3fe"),
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
                    TIM_t("Web网页端不支持搜索"),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 18,
                      color: theme.darkTextColor,
                    ),
                  ),
                  Text(
                    TIM_t("暂时仅限 Android/iOS 端"),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 18,
                      color: theme.darkTextColor,
                    ),
                  ),
                  if (onBack != null) ...[
                    const SizedBox(height: 24),
                    TextButton(
                      onPressed: onBack,
                      child: Text(TIM_t("返回列表")),
                    ),
                  ],
                ],
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisAlignment: MainAxisAlignment.center,
              ),
            ),
            Positioned(
              bottom: 0,
              child: Image.asset(
                "images/logo_bottom.png",
                package: 'tencent_cloud_chat_uikit',
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
