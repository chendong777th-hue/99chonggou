import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tencent_cloud_chat_demo/src/add_friend.dart';
import 'package:tencent_cloud_chat_demo/src/i18n/app_i18n.dart';
import 'package:tencent_cloud_chat_demo/src/add_group.dart';
import 'package:tencent_cloud_chat_demo/src/conversation.dart'
    show ConversationListScope;
import 'package:tencent_cloud_chat_demo/src/navigation/app_chat_route.dart';
import 'package:tencent_cloud_chat_demo/src/create_group.dart';
import 'package:tencent_cloud_chat_demo/src/pages/cross_platform/wide_screen/desktop_create_group_host.dart';
import 'package:tencent_cloud_chat_demo/src/provider/theme.dart';
import 'package:tencent_cloud_chat_demo/src/search_add_page.dart';
import 'package:tencent_cloud_chat_demo/src/search.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_conversation.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_conversation.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_message.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_message.dart';
import 'package:tencent_cloud_chat_uikit/data_services/core/tim_uikit_wide_modal_operation_key.dart';
import 'package:tencent_cloud_chat_uikit/tencent_cloud_chat_uikit.dart';
import 'package:tencent_cloud_chat_uikit/theme/color.dart';
import 'package:tencent_cloud_chat_uikit/ui/controller/tim_uikit_conversation_controller.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/message_anchor.dart';
import 'package:tencent_cloud_chat_uikit/ui/views/TIMUIKitGroupProfile/group_profile_widget.dart';
import 'package:tencent_cloud_chat_uikit/ui/widgets/drag_widget.dart';
import 'package:tencent_cloud_chat_uikit/ui/widgets/wide_popup.dart';
import 'package:tencent_cloud_chat_demo/src/navigation/app_page_transitions.dart';
import 'package:tencent_cloud_chat_demo/src/ui/utils/desktop_modal_layout.dart';

enum PlusType { create, add }

class SearchEntryWide extends StatefulWidget {
  final TIMUIKitConversationController conversationController;
  final PlusType? plusType;
  final VoidCallback? onClickSearch;
  final ValueChanged<V2TimConversation>? directToChat;
  final ConversationListScope listScope;

  const SearchEntryWide(
      {Key? key,
      required this.conversationController,
      this.plusType = PlusType.create,
      required this.onClickSearch,
      this.directToChat,
      this.listScope = ConversationListScope.c2c})
      : super(key: key);

  @override
  State<SearchEntryWide> createState() => _SearchEntryWideState();
}

class _SearchEntryWideState extends State<SearchEntryWide> {
  late TIMUIKitConversationController _controller;
  final GlobalKey plusKey = GlobalKey();
  OverlayEntry? entry;
  void _dismissOverlay() {
    final current = entry;
    if (current == null) {
      return;
    }
    entry = null;
    try {
      current.remove();
    } catch (_) {}
  }

  @override
  void initState() {
    super.initState();
    _controller = widget.conversationController;
  }

  @override
  void dispose() {
    _dismissOverlay();
    super.dispose();
  }

  List<Map<String, dynamic>> _contactTooltip(BuildContext context) => [
        {
          "id": "searchAdd",
          "icon": Icons.person_search_rounded,
          "label": AppI18n.of(context).t(
            zhHans: '搜索添加',
            zhHant: '搜尋添加',
            en: 'Search & Add',
            ja: '検索して追加',
            ko: '검색 및 추가',
          )
        },
        {
          "id": "createGroup",
          "asset": "assets/group_conv.png",
          "label": AppI18n.of(context).t(
            zhHans: '创建群聊',
            zhHant: '建立群聊',
            en: 'Create Group',
            ja: 'グループを作成',
            ko: '그룹 만들기',
          )
        },
      ];

  List<Map<String, dynamic>> _conversationTooltip(BuildContext context) => [
        {
          "id": "searchAdd",
          "icon": Icons.person_search_rounded,
          "label": AppI18n.of(context).t(
            zhHans: '搜索添加',
            zhHant: '搜尋添加',
            en: 'Search & Add',
            ja: '検索して追加',
            ko: '검색 및 추가',
          )
        },
        {
          "id": "createGroup",
          "asset": "assets/group_conv.png",
          "label": AppI18n.of(context).t(
            zhHans: '创建群聊',
            zhHant: '建立群聊',
            en: 'Create Group',
            ja: 'グループを作成',
            ko: '그룹 만들기',
          )
        },
      ];

  void _handleOnConvItemTapedWithPlace(V2TimConversation? selectedConv,
      [MessageAnchor? anchor]) async {
    await openChatWithAnchor(context, selectedConv!, anchor: anchor);
    _controller.reloadData(count: 40);
  }

  _handleTapTooltipItem(String id) {
    switch (id) {
      case "searchAdd":
        final searchAddSize = DesktopModalLayout.medium(context);
        TUIKitWidePopup.showPopupWindow(
          context: context,
          operationKey: TUIKitWideModalOperationKey.addFriend,
          width: searchAddSize.width,
          height: searchAddSize.height,
          borderRadius: const BorderRadius.all(Radius.circular(20)),
          title: AppI18n.of(context).t(
            zhHans: '搜索添加',
            zhHant: '搜尋添加',
            en: 'Search & Add',
            ja: '検索して追加',
            ko: '검색 추가',
          ),
          // 嵌套 Navigator：搜到用户后进添加页，留在弹窗内不全屏。
          child: (closeFunc) => Navigator(
            onGenerateRoute: (settings) {
              return MaterialPageRoute(
                settings: settings,
                builder: (_) => UnifiedSearchAddPage(
                  embeddedInPopup: true,
                  closeFunc: closeFunc,
                  directToChat: (conversation) {
                    closeFunc();
                    if (widget.directToChat != null) {
                      widget.directToChat!(conversation);
                    }
                  },
                ),
              );
            },
          ),
        );
        break;
      case "addFriend":
        final addFriendSize = DesktopModalLayout.medium(context);
        TUIKitWidePopup.showPopupWindow(
          context: context,
          operationKey: TUIKitWideModalOperationKey.addFriend,
          width: addFriendSize.width,
          height: addFriendSize.height,
          borderRadius: const BorderRadius.all(Radius.circular(20)),
          title: AppI18n.of(context).t(
            zhHans: '添加好友',
            zhHant: '添加好友',
            en: 'Add Friend',
            ja: '友達を追加',
            ko: '친구 추가',
          ),
          child: (closeFunc) => Navigator(
            onGenerateRoute: (settings) {
              return MaterialPageRoute(
                settings: settings,
                builder: (_) => AddFriend(
                  closeFunc: closeFunc,
                  directToChat: (_) {
                    closeFunc();
                    if (widget.directToChat != null) {
                      widget.directToChat!(_);
                    }
                  },
                ),
              );
            },
          ),
        );
        break;
      case "addGroup":
        final addGroupSize = DesktopModalLayout.medium(context);
        TUIKitWidePopup.showPopupWindow(
          context: context,
          operationKey: TUIKitWideModalOperationKey.addGroup,
          width: addGroupSize.width,
          height: addGroupSize.height,
          borderRadius: const BorderRadius.all(Radius.circular(20)),
          title: AppI18n.of(context).t(
            zhHans: '添加群聊',
            zhHant: '添加群聊',
            en: 'Add Group',
            ja: 'グループを追加',
            ko: '그룹 추가',
          ),
          child: (closeFunc) => Navigator(
            onGenerateRoute: (settings) {
              return MaterialPageRoute(
                settings: settings,
                builder: (_) => AddGroup(
                  closeFunc: closeFunc,
                  directToChat: (_) {
                    closeFunc();
                    if (widget.directToChat != null) {
                      widget.directToChat!(_);
                    }
                  },
                ),
              );
            },
          ),
        );
        break;
      case "createGroup":
        DesktopCreateGroupHost.open(
          scope: widget.listScope == ConversationListScope.group
              ? DesktopCreateGroupScope.group
              : DesktopCreateGroupScope.c2c,
          convType: GroupTypeForUIKit.community,
        );
        break;
    }
  }

  Widget _buildTooltipIcon(Map e, theme) {
    final icon = e["icon"];
    if (icon is IconData) {
      return Icon(
        icon,
        size: 18,
        color: theme.primaryColor ?? const Color(0xFF1E90FF),
      );
    }
    return ColorFiltered(
      colorFilter: ColorFilter.mode(
        theme.primaryColor ?? const Color(0xFF1E90FF),
        BlendMode.srcATop,
      ),
      child: Image.asset(
        e["asset"]!,
        width: 18,
        height: 18,
      ),
    );
  }

  List<ColumnMenuItem> _getTooltipContent(BuildContext context) {
    List toolTipList = widget.plusType == PlusType.add
        ? _contactTooltip(context)
        : _conversationTooltip(context);
    final theme = Provider.of<DefaultThemeData>(context, listen: false).theme;
    return toolTipList.map((e) {
      return ColumnMenuItem(
        label: e['label']!,
        icon: _buildTooltipIcon(e, theme),
        onClick: () {
          _handleTapTooltipItem(e["id"]!);
          _dismissOverlay();
        },
      );
    }).toList();
  }

  showStartConversation(Offset? offset) {
    if (entry != null) {
      return;
    }
    entry = OverlayEntry(builder: (BuildContext context) {
      final theme = Provider.of<DefaultThemeData>(context, listen: false).theme;
      return TUIKitDragArea(
          closeFun: _dismissOverlay,
          initOffset: offset ??
              Offset(MediaQuery.of(context).size.height * 0.5,
                  MediaQuery.of(context).size.height * 0.5),
          child: Container(
            decoration: BoxDecoration(
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  offset: const Offset(0, 6),
                  blurRadius: 18,
                  spreadRadius: 0,
                ),
              ],
              color: theme.selectPanelBgColor ??
                  theme.conversationItemBgColor ??
                  theme.appbarBgColor ??
                  Colors.white,
              border: Border.all(
                color: theme.weakDividerColor ?? Colors.transparent,
              ),
              borderRadius: const BorderRadius.all(Radius.circular(8)),
            ),
            margin: const EdgeInsets.only(top: 4),
            child: TUIKitColumnMenu(
              padding: const EdgeInsets.all(6),
              data: _getTooltipContent(context),
            ),
          ));
    });
    Overlay.of(context).insert(entry!);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<DefaultThemeData>(context).theme;
    final iconColor =
        (theme.appbarTextColor ?? hexToColor("979797")).withValues(alpha: 0.7);
    return Container(
      decoration: BoxDecoration(
        color: theme.weakBackgroundColor ?? Colors.white,
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        child: Row(
          children: [
            Expanded(
              child: InkWell(
                onTap: () async {
                  if (widget.onClickSearch != null) {
                    widget.onClickSearch!();
                  } else {
                    await Navigator.push(
                        context,
                        AppMaterialPageRoute(
                          settings: const RouteSettings(name: AppRoutes.search),
                          builder: (context) => Search(
                            onTapConversation: _handleOnConvItemTapedWithPlace,
                          ),
                        ));
                  }
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: theme.inputFillColor ?? hexToColor("f7f7f8"),
                    borderRadius: const BorderRadius.all(Radius.circular(4)),
                  ),
                  height: 30,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Row(
                      children: [
                        Icon(
                          Icons.search,
                          color: iconColor,
                          size: 16,
                        ),
                        const SizedBox(width: 6),
                        Text(AppI18n.of(context).t(
                              zhHans: '搜索',
                              zhHant: '搜尋',
                              en: 'Search',
                              ja: '検索',
                              ko: '검색',
                            ),
                            style: TextStyle(
                              color: iconColor,
                              fontSize: 12,
                            )),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(
              width: 10,
            ),
            InkWell(
              onTap: () {
                final alignBox =
                    plusKey.currentContext?.findRenderObject() as RenderBox?;
                var offset = alignBox?.localToGlobal(Offset.zero);
                final double? dx = (offset?.dx != null) ? offset!.dx : null;
                final double? dy =
                    (offset?.dy != null && alignBox?.size.height != null)
                        ? offset!.dy + alignBox!.size.height + 2
                        : null;
                showStartConversation(
                    (dx != null && dy != null) ? Offset(dx, dy) : null);
              },
              child: Container(
                key: plusKey,
                height: 30,
                width: 30,
                decoration: BoxDecoration(
                  color: theme.inputFillColor ?? hexToColor("f7f7f8"),
                  borderRadius: const BorderRadius.all(Radius.circular(4)),
                ),
                child: Icon(
                  widget.plusType == PlusType.create
                      ? Icons.add
                      : Icons.person_add_alt,
                  color: theme.weakTextColor ?? hexToColor("838383"),
                  size: 18,
                ),
              ),
            )
          ],
        ),
      ),
    );
  }
}
