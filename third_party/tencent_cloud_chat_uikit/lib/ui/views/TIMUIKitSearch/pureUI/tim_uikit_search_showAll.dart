// ignore_for_file: file_names

import 'package:flutter/material.dart';
import 'package:tencent_cloud_chat_uikit/base_widgets/tim_ui_kit_statelesswidget.dart';
import 'package:tencent_cloud_chat_uikit/base_widgets/tim_ui_kit_base.dart';
import 'package:tencent_cloud_chat_uikit/theme/tui_theme.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/screen_utils.dart';
import 'package:tencent_cloud_chat_uikit/theme/color.dart';

class TIMUIKitSearchShowALl extends TIMUIKitStatelessWidget {
  final String textShow;
  final VoidCallback? onClick;
  final bool isNeedMoreBottom;

  TIMUIKitSearchShowALl(
      {Key? key,
      this.onClick,
      required this.textShow,
      this.isNeedMoreBottom = false})
      : super(key: key);

  @override
  Widget tuiBuild(BuildContext context, TUIKitBuildValue value) {
    final isDesktopScreen = TUIKitScreenUtils.getFormFactor(context) == DeviceType.Desktop;
    final TUITheme theme = value.theme;
    return InkWell(
      onTap: onClick,
      child: Container(
        decoration: BoxDecoration(
            color: theme.conversationItemBgColor ?? theme.wideBackgroundColor,
            border: Border(
                bottom: BorderSide(
                    color: theme.conversationItemBorderColor ??
                        hexToColor("DBDBDB"),
                    width: 0.5))),
        padding: EdgeInsets.fromLTRB(0, 8, 0, (isNeedMoreBottom ? 24 : 8)),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(
              Icons.search,
              color: theme.weakTextColor ?? hexToColor("979797"),
            ),
            Expanded(
                child: Container(
              margin: const EdgeInsets.only(left: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    // height: 24,
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Text(
                      textShow,
                      style: TextStyle(
                          color: theme.darkTextColor,
                          fontSize: isDesktopScreen ? 14 : 16.0,
                          fontWeight: FontWeight.w400),
                    ),
                  ),
                ],
              ),
            )),
            Icon(
              Icons.expand_more,
              color: theme.weakTextColor ?? hexToColor("979797"),
            ),
          ],
        ),
      ),
    );
  }
}
