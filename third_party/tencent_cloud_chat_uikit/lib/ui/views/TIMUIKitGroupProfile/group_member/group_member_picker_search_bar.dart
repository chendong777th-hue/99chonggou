import 'package:flutter/material.dart';
import 'package:tencent_chat_i18n_tool/tencent_chat_i18n_tool.dart';
import 'package:tencent_cloud_chat_uikit/base_widgets/tim_ui_kit_base.dart';
import 'package:tencent_cloud_chat_uikit/base_widgets/tim_ui_kit_statelesswidget.dart';
import 'package:tencent_cloud_chat_uikit/theme/tui_theme.dart';

/// 添加/删除群成员等选人页共用的搜索框。
class GroupMemberPickerSearchBar extends TIMUIKitStatelessWidget {
  final TextEditingController controller;
  final String keyword;
  final VoidCallback onClear;
  final Widget? trailing;

  GroupMemberPickerSearchBar({
    Key? key,
    required this.controller,
    required this.keyword,
    required this.onClear,
    this.trailing,
  }) : super(key: key);

  @override
  Widget tuiBuild(BuildContext context, TUIKitBuildValue value) {
    final TUITheme theme = value.theme;
    final searchField = Container(
      height: 40,
      decoration: BoxDecoration(
        color: theme.inputFillColor ?? const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(8),
      ),
      alignment: Alignment.center,
      child: TextField(
        controller: controller,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          border: InputBorder.none,
          isDense: true,
          prefixIcon: Icon(
            Icons.search,
            size: 20,
            color: theme.weakTextColor ?? const Color(0xFF999999),
          ),
          suffixIcon: keyword.isEmpty
              ? null
              : IconButton(
                  padding: EdgeInsets.zero,
                  icon: Icon(
                    Icons.cancel,
                    size: 18,
                    color: theme.weakTextColor ?? const Color(0xFF999999),
                  ),
                  onPressed: onClear,
                ),
          hintText: TIM_t('搜索'),
          hintStyle: TextStyle(
            color: theme.weakTextColor ?? const Color(0xFF999999),
            fontSize: 14,
          ),
        ),
        style: TextStyle(color: theme.darkTextColor, fontSize: 15),
      ),
    );

    if (trailing == null) {
      return Container(
        margin: const EdgeInsets.fromLTRB(16, 10, 16, 8),
        child: searchField,
      );
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 10, 8, 8),
      child: Row(
        children: [
          Expanded(child: searchField),
          trailing!,
        ],
      ),
    );
  }
}
