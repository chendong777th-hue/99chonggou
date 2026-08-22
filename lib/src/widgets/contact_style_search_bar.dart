import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tencent_cloud_chat_demo/src/i18n/app_i18n.dart';
import 'package:tencent_cloud_chat_demo/src/provider/theme.dart';
import 'package:tencent_cloud_chat_demo/src/ui/components/app_search_bar.dart';

/// 与「选择联系人」页一致的搜索条：灰底圆角输入框，可选右侧「取消」。
class ContactStyleSearchBar extends StatelessWidget {
  const ContactStyleSearchBar({
    super.key,
    required this.controller,
    required this.onChanged,
    this.focusNode,
    this.autofocus = false,
    this.hint,
    this.showCancel = true,
    this.onCancel,
    this.padding = const EdgeInsets.fromLTRB(16, 6, 16, 6),
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final FocusNode? focusNode;
  final bool autofocus;
  final String? hint;
  final bool showCancel;
  final VoidCallback? onCancel;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final i18n = AppI18n.of(context);
    final theme = Provider.of<DefaultThemeData>(context).theme;
    final pageBackground = theme.weakBackgroundColor ??
        theme.wideBackgroundColor ??
        theme.appbarBgColor ??
        Colors.white;
    final cancelColor = theme.darkTextColor ??
        theme.appbarTextColor ??
        Colors.black;

    return ColoredBox(
      color: pageBackground,
      child: Padding(
        padding: padding,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: AppSearchBar(
                controller: controller,
                focusNode: focusNode,
                autofocus: autofocus,
                hint: hint ??
                    i18n.t(
                      zhHans: '搜索',
                      zhHant: '搜尋',
                      en: 'Search',
                      ja: '検索',
                      ko: '검색',
                    ),
                onChanged: onChanged,
              ),
            ),
            if (showCancel) ...[
              const SizedBox(width: 10),
              GestureDetector(
                onTap: onCancel ?? () => Navigator.pop(context),
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    i18n.t(
                      zhHans: '取消',
                      zhHant: '取消',
                      en: 'Cancel',
                      ja: 'キャンセル',
                      ko: '취소',
                    ),
                    style: TextStyle(
                      color: cancelColor,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
