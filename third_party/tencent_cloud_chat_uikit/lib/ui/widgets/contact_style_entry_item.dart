import 'package:flutter/material.dart';
import 'package:tencent_cloud_chat_uikit/base_widgets/tim_ui_kit_base.dart';
import 'package:tencent_cloud_chat_uikit/base_widgets/tim_ui_kit_statelesswidget.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/screen_utils.dart';
import 'package:tencent_cloud_chat_uikit/theme/color.dart';
import 'package:tencent_cloud_chat_uikit/theme/tui_theme.dart';

/// 通讯录顶部入口（新的朋友 / 我的群聊）同款行样式。
class ContactStyleEntryItem extends TIMUIKitStatelessWidget {
  final Widget icon;
  final String title;
  final VoidCallback? onTap;
  final bool showDivider;

  ContactStyleEntryItem({
    Key? key,
    required this.icon,
    required this.title,
    this.onTap,
    this.showDivider = true,
  }) : super(key: key);

  @override
  Widget tuiBuild(BuildContext context, TUIKitBuildValue value) {
    final TUITheme theme = value.theme;
    final isDesktop =
        TUIKitScreenUtils.getFormFactor(context) == DeviceType.Desktop;
    final textColor = theme.darkTextColor ?? Colors.black;
    final dividerColor = theme.weakDividerColor ?? CommonColor.weakDividerColor;
    final backgroundColor =
        theme.conversationItemBgColor ?? theme.weakBackgroundColor ?? Colors.white;

    return InkWell(
      onTap: onTap,
      child: Container(
        color: backgroundColor,
        padding: const EdgeInsets.only(top: 8, left: 16),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Row(
                children: [
                  Container(
                    height: isDesktop ? 30 : 40,
                    width: isDesktop ? 30 : 40,
                    margin: const EdgeInsets.only(right: 12, bottom: 12),
                    alignment: Alignment.center,
                    child: icon,
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 10, bottom: 20),
                      child: Text(
                        title,
                        style: TextStyle(
                          color: textColor,
                          fontSize: isDesktop ? 13 : 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (showDivider)
              Padding(
                padding: const EdgeInsets.only(left: 42),
                child: Container(
                  height: 0.6,
                  color: dividerColor,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

String contactStyleEntryIconAsset(
  TUITheme theme, {
  required String entryId,
}) {
  final isDark = ThemeData.estimateBrightnessForColor(
        theme.appbarBgColor ?? theme.wideBackgroundColor ?? Colors.white,
      ) ==
      Brightness.dark;
  final suffix = isDark ? 'solemn' : 'brisk';
  switch (entryId) {
    case 'friend':
    case 'newContact':
      return 'assets/newContact_$suffix.png';
    case 'group':
    case 'groupList':
      return 'assets/groupList_$suffix.png';
    default:
      return '';
  }
}

Widget contactStyleEntryIcon(
  BuildContext context,
  TUITheme theme, {
  required String entryId,
}) {
  final isDesktop =
      TUIKitScreenUtils.getFormFactor(context) == DeviceType.Desktop;
  final size = isDesktop ? 30.0 : 46.0;
  final asset = contactStyleEntryIconAsset(theme, entryId: entryId);
  if (asset.isEmpty) {
    return SizedBox(width: size, height: size);
  }
  return SizedBox(
    width: size,
    height: size,
    child: ClipOval(
      child: Image.asset(
        asset,
        fit: BoxFit.cover,
      ),
    ),
  );
}
