import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tencent_cloud_chat_demo/src/i18n/app_i18n.dart';
import 'package:tencent_cloud_chat_demo/src/provider/theme.dart';
import 'package:tencent_cloud_chat_demo/src/ui/app_tokens.dart';

typedef AppSearchBarInsetBuilder = Widget Function(
  BuildContext context,
  TextEditingController controller,
  ValueChanged<String> onChanged,
);

const double kAppSearchBarHeight = 40;
const double kAppSearchBarIconSize = 18;
const double kAppSearchBarFontSize = 14;

/// 带统一外边距的 [AppSearchBar]，供各页面复用。
Widget buildAppSearchBarInset({
  required BuildContext context,
  TextEditingController? controller,
  ValueChanged<String>? onChanged,
  String? hint,
  FocusNode? focusNode,
  bool autofocus = false,
  bool readOnly = false,
  VoidCallback? onTap,
  EdgeInsetsGeometry padding = const EdgeInsets.fromLTRB(16, 6, 16, 6),
}) {
  return Padding(
    padding: padding,
    child: AppSearchBar(
      controller: controller,
      onChanged: onChanged,
      hint: hint,
      focusNode: focusNode,
      autofocus: autofocus,
      readOnly: readOnly,
      onTap: onTap,
    ),
  );
}

class AppSearchBar extends StatefulWidget {
  final String? hint;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onTap;
  final bool readOnly;
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final bool autofocus;

  const AppSearchBar({
    Key? key,
    this.hint,
    this.onChanged,
    this.onTap,
    this.readOnly = false,
    this.controller,
    this.focusNode,
    this.autofocus = false,
  }) : super(key: key);

  @override
  State<AppSearchBar> createState() => _AppSearchBarState();
}

class _AppSearchBarState extends State<AppSearchBar> {
  TextEditingController? _internalController;
  bool _showClear = false;

  TextEditingController get _effectiveController =>
      widget.controller ?? _internalController!;

  @override
  void initState() {
    super.initState();
    if (widget.controller == null) {
      _internalController = TextEditingController();
    }
    _effectiveController.addListener(_syncClearVisibility);
    _syncClearVisibility();
    if (widget.autofocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        widget.focusNode?.requestFocus();
      });
    }
  }

  @override
  void didUpdateWidget(covariant AppSearchBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      (oldWidget.controller ?? _internalController)
          ?.removeListener(_syncClearVisibility);
      if (widget.controller == null && _internalController == null) {
        _internalController = TextEditingController();
      }
      _effectiveController.addListener(_syncClearVisibility);
      _syncClearVisibility();
    }
  }

  @override
  void dispose() {
    _effectiveController.removeListener(_syncClearVisibility);
    _internalController?.dispose();
    super.dispose();
  }

  void _syncClearVisibility() {
    final show = _effectiveController.text.trim().isNotEmpty;
    if (show != _showClear && mounted) {
      setState(() => _showClear = show);
    }
  }

  void _handleChanged(String value) {
    final trimmed = value.trim();
    final show = trimmed.isNotEmpty;
    if (show != _showClear) {
      setState(() => _showClear = show);
    }
    widget.onChanged?.call(trimmed);
  }

  void _clearText() {
    _effectiveController.clear();
    setState(() => _showClear = false);
    widget.onChanged?.call('');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<DefaultThemeData>(context).theme;
    final resolvedHint = widget.hint ??
        AppI18n.of(context).t(
          zhHans: '搜索',
          zhHant: '搜尋',
          en: 'Search',
          ja: '検索',
          ko: '검색',
        );
    final fillColor = theme.inputFillColor ??
        theme.selectPanelBgColor ??
        AppTokens.ink25;
    final hintColor = theme.weakTextColor ?? AppTokens.ink300;
    final textColor = theme.darkTextColor ?? AppTokens.ink800;
    return GestureDetector(
      onTap: widget.readOnly ? widget.onTap : null,
      child: Container(
        decoration: BoxDecoration(
          color: fillColor,
          borderRadius: BorderRadius.circular(10),
        ),
        child: widget.readOnly
            ? SizedBox(
                height: kAppSearchBarHeight,
                child: Row(
                  children: [
                    const SizedBox(width: 10),
                    Icon(
                      Icons.search,
                      size: kAppSearchBarIconSize,
                      color: hintColor,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        resolvedHint,
                        style: AppTokens.body.copyWith(
                          color: hintColor,
                          fontSize: kAppSearchBarFontSize,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                  ],
                ),
              )
            : SizedBox(
                height: kAppSearchBarHeight,
                child: TextField(
                  controller: _effectiveController,
                  focusNode: widget.focusNode,
                  autofocus: widget.autofocus,
                  onChanged: _handleChanged,
                  textInputAction: TextInputAction.search,
                  style: AppTokens.body.copyWith(
                    fontSize: kAppSearchBarFontSize,
                    color: textColor,
                    height: 1.2,
                  ),
                  cursorColor: theme.primaryColor ?? AppTokens.brand500,
                  decoration: InputDecoration(
                    hintText: resolvedHint,
                    hintStyle: AppTokens.body.copyWith(
                      color: hintColor,
                      fontSize: kAppSearchBarFontSize,
                      height: 1.2,
                    ),
                    prefixIcon: Icon(
                      Icons.search,
                      color: hintColor,
                      size: kAppSearchBarIconSize,
                    ),
                    prefixIconConstraints: const BoxConstraints(
                      minWidth: 34,
                      minHeight: kAppSearchBarHeight,
                    ),
                    suffixIcon: _showClear
                        ? IconButton(
                            onPressed: _clearText,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(
                              minWidth: 34,
                              minHeight: kAppSearchBarHeight,
                            ),
                            icon: Icon(
                              Icons.cancel,
                              color: hintColor,
                              size: kAppSearchBarIconSize,
                            ),
                          )
                        : null,
                    suffixIconConstraints: const BoxConstraints(
                      minWidth: 34,
                      minHeight: kAppSearchBarHeight,
                    ),
                    border: InputBorder.none,
                    filled: false,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
      ),
    );
  }
}
