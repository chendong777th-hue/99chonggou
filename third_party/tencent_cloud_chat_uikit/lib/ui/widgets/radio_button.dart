import 'package:flutter/material.dart';
import 'package:tencent_cloud_chat_uikit/base_widgets/tim_ui_kit_statelesswidget.dart';
import 'package:tencent_cloud_chat_uikit/base_widgets/tim_ui_kit_base.dart';
import 'package:tencent_cloud_chat_uikit/theme/color.dart';
import 'package:tencent_cloud_chat_uikit/theme/tui_theme.dart';

class CheckBoxButton extends TIMUIKitStatelessWidget {
  final bool isChecked;
  final Function(bool isChecked)? onChanged;
  final bool disabled;
  final bool onlyShow;
  final double? size;

  CheckBoxButton(
      {this.disabled = false,
      Key? key,
      this.size,
      this.onlyShow = false,
      required this.isChecked,
      this.onChanged})
      : super(key: key);

  @override
  Widget tuiBuild(BuildContext context, TUIKitBuildValue value) {
    final TUITheme theme = value.theme;
    final backgroundColor = theme.weakBackgroundColor ?? Colors.white;
    final isDarkTheme =
        ThemeData.estimateBrightnessForColor(backgroundColor) ==
            Brightness.dark;
    final uncheckedBorderColor =
        theme.weakTextColor ?? hexToColor("888888");
    final uncheckedFillColor =
        isDarkTheme ? Colors.transparent : Colors.white;

    BoxDecoration boxDecoration = !isChecked
        ? BoxDecoration(
            border: Border.all(
              color: uncheckedBorderColor,
              width: 1.5,
            ),
            shape: BoxShape.circle,
            color: uncheckedFillColor,
          )
        : BoxDecoration(
            shape: BoxShape.circle,
            color: theme.primaryColor ?? CommonColor.primaryColor,
          );

    if (disabled) {
      boxDecoration = BoxDecoration(
        shape: BoxShape.circle,
        color: (theme.weakTextColor ?? Colors.grey).withValues(alpha: 0.35),
      );
    }

    final double boxSize = size ?? 22;
    final Widget? checkIcon = isChecked && !disabled
        ? Icon(
            Icons.check,
            size: boxSize / 2,
            color: Colors.white,
          )
        : null;

    return Center(
        child: onlyShow
            ? Container(
                height: boxSize,
                width: boxSize,
                decoration: boxDecoration,
                child: checkIcon,
              )
            : InkWell(
                onTap: () {
                  if (onChanged != null && !disabled) {
                    onChanged!(!isChecked);
                  }
                },
                child: Container(
                  height: boxSize,
                  width: boxSize,
                  decoration: boxDecoration,
                  child: checkIcon,
                ),
              ));
  }
}
