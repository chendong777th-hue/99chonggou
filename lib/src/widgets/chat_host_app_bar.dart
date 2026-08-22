import 'package:flutter/material.dart';
import 'package:tencent_cloud_chat_demo/src/i18n/app_i18n.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/view_models/chat_ui_state_store.dart';
import 'package:tencent_cloud_chat_uikit/theme/tui_theme.dart';

/// 聊天页外层 AppBar：多选时换成「取消 + 已选条数」，避免盖住 UIKit 内建顶栏。
class ChatHostAppBar extends StatelessWidget implements PreferredSizeWidget {
  static const double multiSelectLeadingWidth = 88;

  final TUITheme theme;
  final ChatUiStateStore uiStateStore;
  final String conversationID;
  final bool observeMultiSelect;
  final Widget title;
  final List<Widget> actions;
  final VoidCallback onCancelMultiSelect;
  final PreferredSizeWidget? bottom;

  const ChatHostAppBar({
    super.key,
    required this.theme,
    required this.uiStateStore,
    required this.conversationID,
    required this.observeMultiSelect,
    required this.title,
    required this.actions,
    required this.onCancelMultiSelect,
    this.bottom,
  });

  @override
  Size get preferredSize {
    final bottomHeight = bottom?.preferredSize.height ?? 0;
    return Size.fromHeight(kToolbarHeight + bottomHeight);
  }

  Color get _titleColor =>
      theme.chatHeaderTitleTextColor ?? theme.appbarTextColor ?? Colors.black;

  Color get _actionColor =>
      theme.chatHeaderBackTextColor ??
      theme.primaryColor ??
      const Color(0xFF1E90FF);

  @override
  Widget build(BuildContext context) {
    if (!observeMultiSelect) {
      return _buildNormal();
    }
    return ListenableBuilder(
      listenable: uiStateStore,
      builder: (context, _) {
        if (!uiStateStore.isMultiSelect(conversationID)) {
          return _buildNormal();
        }
        return _buildMultiSelect(context);
      },
    );
  }

  AppBar _buildNormal() {
    return AppBar(
      centerTitle: false,
      titleSpacing: 0,
      leadingWidth: 48,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      shadowColor: Colors.transparent,
      backgroundColor: theme.chatHeaderBgColor ?? theme.appbarBgColor,
      titleTextStyle: TextStyle(
        color: _titleColor,
        fontSize: 16,
        fontWeight: FontWeight.w500,
        height: 1.1,
      ),
      toolbarTextStyle: TextStyle(
        color: theme.weakTextColor ?? const Color(0xFF999999),
        fontSize: 12,
        fontWeight: FontWeight.w400,
        height: 1.1,
      ),
      bottom: bottom,
      title: title,
      leading: const BackButton(),
      iconTheme: IconThemeData(color: _actionColor),
      actions: actions,
    );
  }

  AppBar _buildMultiSelect(BuildContext context) {
    final i18n = AppI18n.of(context);
    final selectedCount = uiStateStore.selectedCount(conversationID);
    final titleText = selectedCount <= 0
        ? i18n.t(
            zhHans: '选择消息',
            zhHant: '選擇訊息',
            en: 'Select messages',
            ja: 'メッセージを選択',
            ko: '메시지 선택',
          )
        : i18n.format(
            zhHans: '已选择{count}条',
            zhHant: '已選擇{count}條',
            en: '{count} selected',
            ja: '{count}件選択',
            ko: '{count}개 선택',
            vars: <String, String>{'count': '$selectedCount'},
          );
    return AppBar(
      centerTitle: true,
      titleSpacing: 0,
      leadingWidth: multiSelectLeadingWidth,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      shadowColor: Colors.transparent,
      backgroundColor: theme.chatHeaderBgColor ?? theme.appbarBgColor,
      titleTextStyle: TextStyle(
        color: _titleColor,
        fontSize: 17,
        fontWeight: FontWeight.w600,
        height: 1.1,
      ),
      bottom: bottom,
      title: Text(
        titleText,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      leading: Align(
        alignment: Alignment.centerLeft,
        child: TextButton(
          onPressed: onCancelMultiSelect,
          style: TextButton.styleFrom(
            padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
            minimumSize: const Size(0, 44),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            alignment: Alignment.centerLeft,
            foregroundColor: _actionColor,
          ),
          child: Text(
            i18n.t(
              zhHans: '取消',
              zhHant: '取消',
              en: 'Cancel',
              ja: 'キャンセル',
              ko: '취소',
            ),
            maxLines: 1,
            style: TextStyle(
              color: _actionColor,
              fontSize: 17,
              fontWeight: FontWeight.w400,
              height: 1.15,
            ),
          ),
        ),
      ),
      actions: const <Widget>[
        SizedBox(width: ChatHostAppBar.multiSelectLeadingWidth),
      ],
    );
  }
}

/// 多选时拦截系统返回：先退出多选，不离开聊天页。
class ChatMultiSelectPopGuard extends StatelessWidget {
  final ChatUiStateStore uiStateStore;
  final String conversationID;
  final VoidCallback onCancelMultiSelect;
  final Widget child;

  const ChatMultiSelectPopGuard({
    super.key,
    required this.uiStateStore,
    required this.conversationID,
    required this.onCancelMultiSelect,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: uiStateStore,
      child: child,
      builder: (context, cachedChild) {
        final blocking = uiStateStore.isMultiSelect(conversationID);
        return PopScope(
          key: const ValueKey('chat_multi_select_pop_guard'),
          canPop: !blocking,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop && uiStateStore.isMultiSelect(conversationID)) {
              onCancelMultiSelect();
            }
          },
          child: cachedChild!,
        );
      },
    );
  }
}
