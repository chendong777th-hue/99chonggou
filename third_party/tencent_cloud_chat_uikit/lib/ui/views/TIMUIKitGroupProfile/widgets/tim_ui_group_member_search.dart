import 'dart:async';

import 'package:flutter/material.dart';
import 'package:tencent_chat_i18n_tool/tencent_chat_i18n_tool.dart';
import 'package:tencent_cloud_chat_uikit/base_widgets/tim_ui_kit_base.dart';
import 'package:tencent_cloud_chat_uikit/base_widgets/tim_ui_kit_state.dart';
import 'package:tencent_cloud_chat_uikit/theme/color.dart';
import 'package:tencent_cloud_chat_uikit/theme/tui_theme.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/screen_utils.dart';

class GroupMemberSearchTextField extends StatefulWidget {
  final void Function(String text) onTextChange;

  const GroupMemberSearchTextField({
    Key? key,
    required this.onTextChange,
  }) : super(key: key);

  @override
  State<GroupMemberSearchTextField> createState() =>
      _GroupMemberSearchTextFieldState();
}

class _GroupMemberSearchTextFieldState
    extends TIMUIKitState<GroupMemberSearchTextField> {
  final TextEditingController _controller = TextEditingController();
  late final FocusNode _focusNode;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    _controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    if (mounted) {
      setState(() {});
    }
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) {
        return;
      }
      widget.onTextChange(_controller.text);
    });
  }

  @override
  Widget tuiBuild(BuildContext context, TUIKitBuildValue value) {
    final TUITheme theme = value.theme;
    final isDesktopScreen =
        TUIKitScreenUtils.getFormFactor(context) == DeviceType.Desktop;
    final searchBackgroundColor =
        theme.inputFillColor ?? const Color(0xFFF3F4F6);
    final iconColor = theme.weakTextColor ?? const Color(0xFF9CA3AF);
    final horizontalPadding = isDesktopScreen ? 20.0 : 12.0;
    final verticalPadding = isDesktopScreen
        ? const EdgeInsets.fromLTRB(0, 8, 0, 8)
        : const EdgeInsets.fromLTRB(0, 8, 0, 16);
    final fieldHeight = isDesktopScreen ? 36.0 : 40.0;
    final fieldRadius = isDesktopScreen ? 8.0 : 10.0;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        horizontalPadding,
        verticalPadding.top,
        horizontalPadding,
        verticalPadding.bottom,
      ),
      child: Container(
        height: fieldHeight,
        decoration: BoxDecoration(
          color: searchBackgroundColor,
          borderRadius: BorderRadius.circular(fieldRadius),
          border: isDesktopScreen
              ? Border.all(
                  color: (theme.weakDividerColor ?? const Color(0xFFE8EAED))
                      .withValues(alpha: 0.9),
                )
              : null,
        ),
        child: Row(
          children: [
            SizedBox(width: isDesktopScreen ? 12 : 12),
            Icon(
              Icons.search_rounded,
              color: iconColor,
              size: isDesktopScreen ? 18 : 18,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _controller,
                focusNode: _focusNode,
                style: TextStyle(
                  color: theme.darkTextColor,
                  fontSize: isDesktopScreen ? 13.5 : 14,
                  fontWeight: FontWeight.w400,
                  height: 1.2,
                ),
                cursorColor: theme.primaryColor ?? CommonColor.primaryColor,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: TIM_t("搜索"),
                  hintStyle: TextStyle(
                    color: iconColor,
                    fontSize: isDesktopScreen ? 13.5 : 14,
                  ),
                  border: InputBorder.none,
                  filled: false,
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ),
            if (_controller.text.isNotEmpty)
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(
                  minWidth: 32,
                  minHeight: 32,
                ),
                icon: Icon(
                  Icons.cancel_rounded,
                  size: 16,
                  color: iconColor,
                ),
                onPressed: () {
                  _controller.clear();
                  widget.onTextChange('');
                },
              )
            else
              SizedBox(width: isDesktopScreen ? 12 : 12),
          ],
        ),
      ),
    );
  }
}
