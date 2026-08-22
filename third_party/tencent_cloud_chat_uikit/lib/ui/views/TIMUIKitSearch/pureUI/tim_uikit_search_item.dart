import 'package:flutter/material.dart';
import 'package:tencent_cloud_chat_uikit/base_widgets/tim_ui_kit_statelesswidget.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/screen_utils.dart';
import 'package:tencent_cloud_chat_uikit/ui/views/TIMUIKitSearch/tim_uikit_search_item_wide.dart';
import 'package:tencent_cloud_chat_uikit/ui/widgets/avatar.dart';
import 'package:tencent_cloud_chat_uikit/base_widgets/tim_ui_kit_base.dart';
import 'package:tencent_cloud_chat_uikit/theme/color.dart';
import 'package:tencent_cloud_chat_uikit/theme/tui_theme.dart';

class TIMUIKitSearchItem extends TIMUIKitStatelessWidget {
  final String faceUrl;
  final String showName;
  final String lineOne;
  final String? lineOneRight;
  final String? lineTwo;
  final Widget? lineTwoWidget;
  final VoidCallback? onClick;

  TIMUIKitSearchItem(
      {Key? key,
      required this.faceUrl,
      required this.showName,
      required this.lineOne,
      this.lineTwo,
      this.lineTwoWidget,
      this.lineOneRight,
      this.onClick})
      : super(key: key);

  static const int _messagePreviewMaxLines = 2;

  Widget _renderLineOneRight(String? text, TUITheme theme) {
    if (text == null || text.isEmpty) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 12,
          color: theme.weakTextColor,
        ),
      ),
    );
  }

  Widget _renderLineTwo(String? text, Widget? widgetLine, TUITheme theme) {
    if (widgetLine != null) {
      return widgetLine;
    }
    if (text == null || text.isEmpty) {
      return const SizedBox.shrink();
    }
    return Text(
      text,
      maxLines: _messagePreviewMaxLines,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        color: theme.weakTextColor,
        height: 1.35,
        fontSize: 14,
      ),
    );
  }

  @override
  Widget tuiBuild(BuildContext context, TUIKitBuildValue value) {
    final TUITheme theme = value.theme;

    return TUIKitScreenUtils.getDeviceWidget(
      context: context,
      defaultWidget: GestureDetector(
        onTap: onClick,
        child: Container(
          decoration: BoxDecoration(
              border: Border(
                  bottom: BorderSide(
                      color: theme.conversationItemBorderColor ??
                          hexToColor("DBDBDB"),
                      width: 0.5))),
          padding: const EdgeInsets.fromLTRB(0, 12, 0, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 40,
                height: 40,
                child: Stack(
                  fit: StackFit.expand,
                  clipBehavior: Clip.none,
                  children: [Avatar(faceUrl: faceUrl, showName: showName)],
                ),
              ),
              Expanded(
                child: Container(
                  margin: const EdgeInsets.only(left: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                lineOne,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: theme.darkTextColor,
                                  fontSize: 17,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            _renderLineOneRight(lineOneRight, theme),
                          ],
                        ),
                      ),
                      _renderLineTwo(lineTwo, lineTwoWidget, theme),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      desktopWidget: TIMUIKitSearchWideItem(
          lineOneRight: lineOneRight,
          key: key,
          lineTwo: lineTwo,
          lineTwoWidget: lineTwoWidget,
          onClick: onClick,
          faceUrl: faceUrl,
          showName: showName,
          lineOne: lineOne),
    );
  }
}
