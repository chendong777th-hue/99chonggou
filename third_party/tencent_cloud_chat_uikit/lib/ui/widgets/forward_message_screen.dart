import 'package:flutter/material.dart';
import 'package:lpinyin/lpinyin.dart';
import 'package:tencent_chat_i18n_tool/tencent_chat_i18n_tool.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_conversation.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_conversation.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_friend_info.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_friend_info.dart';
import 'package:tencent_cloud_chat_sdk/tencent_im_sdk_plugin.dart';
import 'package:tencent_cloud_chat_uikit/base_widgets/tim_callback.dart';
import 'package:tencent_cloud_chat_uikit/base_widgets/tim_ui_kit_state.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/separate_models/tui_chat_separate_view_model.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/life_cycle/friend_list_life_cycle.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/view_models/tui_chat_global_model.dart';
import 'package:tencent_cloud_chat_uikit/theme/tui_theme_view_model.dart';
import 'package:tencent_cloud_chat_uikit/data_services/services_locatar.dart';
import 'package:tencent_cloud_chat_uikit/ui/views/TIMUIKitContact/tim_uikit_contact.dart';
import 'package:tencent_cloud_chat_uikit/ui/views/TIMUIKitGroup/tim_uikit_group.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/message.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/screen_utils.dart';
import 'package:tencent_cloud_chat_uikit/ui/widgets/contact_style_entry_item.dart';
import 'package:tencent_cloud_chat_uikit/ui/widgets/forward_confirm_bottom_sheet.dart';
import 'package:tencent_cloud_chat_uikit/ui/widgets/recent_conversation_list.dart';
import 'package:tencent_cloud_chat_uikit/base_widgets/tim_ui_kit_base.dart';
import 'package:tencent_cloud_chat_uikit/theme/tui_theme.dart';

GlobalKey<_ForwardMessageScreenState> forwardMessageScreenKey = GlobalKey();

class ForwardMessageScreen extends StatefulWidget {
  final bool isMergerForward;
  final ConvType conversationType;
  final TUIChatSeparateViewModel model;
  final VoidCallback? onClose;

  const ForwardMessageScreen(
      {Key? key, this.isMergerForward = false, required this.conversationType, required this.model, this.onClose})
      : super(key: key);

  @override
  State<StatefulWidget> createState() => _ForwardMessageScreenState();
}

class _ForwardMessageScreenState extends TIMUIKitState<ForwardMessageScreen> {
  final TUIChatGlobalModel model = serviceLocator<TUIChatGlobalModel>();
  List<V2TimConversation> _conversationList = [];
  bool isMultiSelect = false;
  bool _forwardActionInFlight = false;
  final TextEditingController _searchController = TextEditingController();
  String _keyword = "";

  String _getMergerMessageTitle() {
    return widget.model.getMergerForwardTitle();
  }

  List<String> _getAbstractList() {
    return widget.model.getSelectedMessageList().map((e) {
      final sender = (e.nickName != null && e.nickName!.isNotEmpty) ? e.nickName : e.sender;
      return "$sender: ${model.abstractMessageBuilder != null ? model.abstractMessageBuilder!(e) : MessageUtils.getAbstractMessageAsync(e, [])}";
    }).toList();
  }

  handleForwardMessage() async {
    if (_forwardActionInFlight) {
      return;
    }
    if (_conversationList.isEmpty) {
      return;
    }
    for (final message in widget.model.getSelectedMessageList()) {
      if (widget.model.isWalletCardMessage(message)) {
        onTIMCallback(TIMCallback(
          type: TIMCallbackType.INFO,
          infoRecommendText: TIM_t("钱包消息不可转发"),
        ));
        return;
      }
      if (widget.model.isContactCardMessage(message)) {
        onTIMCallback(TIMCallback(
          type: TIMCallbackType.INFO,
          infoRecommendText: TIM_t("个人名片不支持转发！"),
        ));
        return;
      }
    }
    _forwardActionInFlight = true;
    try {
      // 多会话转发：跳过「发送给」确认弹窗，直接发送并显示转圈，
      // 避免确认层 barrier 与重转发叠在一起出现「只灰不转圈」。
      final skipConfirm = _conversationList.length > 1;
      final confirmed = skipConfirm
          ? await _sendForwardWithoutConfirm(context)
          : await _showConfirmForwardDialog(context);
      if (confirmed != true) {
        return;
      }

      widget.model.updateMultiSelectStatus(false);

      if (widget.onClose != null) {
        widget.onClose!();
      } else if (mounted) {
        Navigator.pop(context);
      }
      _showForwardSuccessToast();
    } finally {
      _forwardActionInFlight = false;
    }
  }

  Future<bool> _sendForwardWithoutConfirm(BuildContext context) async {
    final theme = serviceLocator<TUIThemeViewModel>().theme;
    final sheetColor =
        theme.conversationItemBgColor ?? theme.weakBackgroundColor ?? Colors.white;
    final isDark = sheetColor.computeLuminance() < 0.5;
    final titleColor = isDark ? Colors.white : const Color(0xFF111111);
    final primary = theme.primaryColor ?? const Color(0xFF2196F3);

    try {
      await runWithForwardSendingOverlay(
        context: context,
        statusText: TIM_t("正在发送中"),
        indicatorColor: primary,
        cardColor: sheetColor,
        textColor: titleColor,
        action: () => _performForwardSend(context),
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _performForwardSend(BuildContext context) async {
    if (widget.isMergerForward) {
      await widget.model.sendMergerMessage(
        conversationList: _conversationList,
        title: _getMergerMessageTitle(),
        abstractList: _getAbstractList(),
        context: context,
      );
    } else {
      await widget.model.sendForwardMessage(
        conversationList: _conversationList,
      );
    }
  }

  List<ForwardSinglePreviewItem> _buildSinglePreviewItems() {
    return widget.model.getSelectedMessageList().map((message) {
      final sender = widget.model.getMessageDisplayName(message);
      final summary = model.abstractMessageBuilder != null
          ? model.abstractMessageBuilder!(message)
          : MessageUtils.getAbstractMessageAsync(message, []);
      return ForwardSinglePreviewItem(
        senderName: sender,
        summary: summary,
        faceUrl: widget.model.getMessageFaceUrl(message),
      );
    }).toList();
  }

  void _showForwardSuccessToast() {
    onTIMCallback(TIMCallback(
      type: TIMCallbackType.INFO,
      infoRecommendText: TIM_t("发送成功"),
    ));
  }

  Future<bool?> _showConfirmForwardDialog(BuildContext context) async {
    final messages = widget.model.getSelectedMessageList();
    final theme = serviceLocator<TUIThemeViewModel>().theme;
    final sheetColor =
        theme.conversationItemBgColor ?? theme.weakBackgroundColor ?? Colors.white;
    final isDark = sheetColor.computeLuminance() < 0.5;
    final titleColor = isDark ? Colors.white : const Color(0xFF111111);
    final primary = theme.primaryColor ?? const Color(0xFF2196F3);

    // 单会话确认预览前同步头像；用转圈盖住准备过程。
    if (!widget.isMergerForward && messages.isNotEmpty) {
      await runWithForwardSendingOverlay(
        context: context,
        statusText: TIM_t("正在准备中"),
        indicatorColor: primary,
        cardColor: sheetColor,
        textColor: titleColor,
        action: () => widget.model.syncMessagesFaceUrlFromSdk(messages),
      );
    }
    if (!mounted) {
      return false;
    }

    return showForwardConfirmBottomSheet(
      context: context,
      theme: theme,
      isMergerForward: widget.isMergerForward,
      receivers: List<V2TimConversation>.from(_conversationList),
      singleItems:
          widget.isMergerForward ? const [] : _buildSinglePreviewItems(),
      mergeTitle: widget.isMergerForward ? _getMergerMessageTitle() : '',
      mergeAbstracts:
          widget.isMergerForward ? _getAbstractList() : const [],
      onConfirmSend: () => _performForwardSend(context),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
    widget.model.updateMultiSelectStatus(false);
  }

  Future<void> _selectFriend(TUITheme theme) async {
    TUIChatGlobalModel.ensureAppExtensionsRegistered();
    final pageBuilder =
        serviceLocator<TUIChatGlobalModel>().appForwardSelectFriendPage;
    final conversation = await Navigator.push<V2TimConversation>(
      context,
      MaterialPageRoute(
        builder: (context) => pageBuilder != null
            ? pageBuilder(context)
            : _ForwardSelectFriendPage(theme: theme),
      ),
    );
    if (!mounted || conversation == null) {
      return;
    }
    _conversationList = [conversation];
    await handleForwardMessage();
  }

  Future<void> _selectGroup(TUITheme theme) async {
    TUIChatGlobalModel.ensureAppExtensionsRegistered();
    final pageBuilder =
        serviceLocator<TUIChatGlobalModel>().appForwardSelectGroupPage;
    final conversation = await Navigator.push<V2TimConversation>(
      context,
      MaterialPageRoute(
        builder: (context) => pageBuilder != null
            ? pageBuilder(context)
            : _ForwardSelectGroupPage(theme: theme),
      ),
    );
    if (!mounted || conversation == null) {
      return;
    }
    _conversationList = [conversation];
    await handleForwardMessage();
  }

  Widget _buildSearchBar(TUITheme theme) {
    final builder = serviceLocator<TUIChatGlobalModel>().appSearchBarBuilder;
    if (builder != null) {
      return builder(
        context,
        _searchController,
        (value) => setState(() => _keyword = value.trim()),
      );
    }
    final fillColor = theme.inputFillColor ??
        theme.selectPanelBgColor ??
        const Color(0xFFF1F2F6);
    final hintColor = theme.weakTextColor ?? const Color(0xFF999999);
    final textColor = theme.darkTextColor ?? Colors.black;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 6, 16, 6),
      height: 36,
      decoration: BoxDecoration(
        color: fillColor,
        borderRadius: BorderRadius.circular(10),
      ),
      child: TextField(
        controller: _searchController,
        onChanged: (value) {
          setState(() {
            _keyword = value.trim();
          });
        },
        style: TextStyle(
          color: textColor,
          fontSize: 14,
          height: 1.2,
        ),
        decoration: InputDecoration(
          hintText: TIM_t("搜索"),
          hintStyle: TextStyle(
            color: hintColor,
            fontSize: 14,
            height: 1.2,
          ),
          prefixIcon: Icon(
            Icons.search,
            color: hintColor,
            size: 18,
          ),
          prefixIconConstraints: const BoxConstraints(
            minWidth: 34,
            minHeight: 36,
          ),
          border: InputBorder.none,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 8),
        ),
      ),
    );
  }

  @override
  Widget tuiBuild(BuildContext context, TUIKitBuildValue value) {
    final isDesktopScreen = TUIKitScreenUtils.getFormFactor(context) == DeviceType.Desktop;
    final TUITheme theme = value.theme;
    if (isDesktopScreen) {
      isMultiSelect = true;
      return RecentForwardList(
        isMultiSelect: isMultiSelect,
        onChanged: (conversationList) {
          _conversationList = conversationList;

          if (!isMultiSelect) {
            handleForwardMessage();
          }
        },
      );
    }
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Text(
          isMultiSelect ? TIM_t("选择多个会话") : TIM_t("选择一个会话"),
          style: TextStyle(
            color: theme.appbarTextColor,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        shadowColor: theme.weakBackgroundColor,
        backgroundColor: theme.appbarBgColor ?? theme.primaryColor,
        leadingWidth: 80,
        leading: TextButton(
          onPressed: () {
            if (isMultiSelect) {
              setState(() {
                isMultiSelect = false;
                _conversationList = [];
              });
            } else {
              widget.model.updateMultiSelectStatus(false);
              if (widget.onClose != null) {
                widget.onClose!();
              } else {
                Navigator.pop(context);
              }
            }
          },
          child: Text(
            TIM_t("取消"),
            style: TextStyle(
              color: theme.appbarTextColor,
              fontSize: 13,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              if (!isMultiSelect) {
                setState(() {
                  isMultiSelect = true;
                });
              } else {
                handleForwardMessage();
              }
            },
            child: Text(
              !isMultiSelect ? TIM_t("多选") : TIM_t("完成"),
              style: TextStyle(
                color: theme.appbarTextColor,
                fontSize: 13,
              ),
            ),
          )
        ],
      ),
      body: isMultiSelect
          ? RecentForwardList(
              isMultiSelect: true,
              sectionTitle: TIM_t("最近"),
              showSectionHeader: true,
              onChanged: (conversationList) {
                _conversationList = conversationList;
              },
            )
          : Column(
              children: [
                _buildSearchBar(theme),
                ContactStyleEntryItem(
                  icon: contactStyleEntryIcon(
                    context,
                    theme,
                    entryId: 'friend',
                  ),
                  title: TIM_t("选择朋友"),
                  onTap: () => _selectFriend(theme),
                ),
                ContactStyleEntryItem(
                  icon: contactStyleEntryIcon(
                    context,
                    theme,
                    entryId: 'group',
                  ),
                  title: TIM_t("选择群聊"),
                  onTap: () => _selectGroup(theme),
                  showDivider: false,
                ),
                Expanded(
                  child: RecentForwardList(
                    isMultiSelect: false,
                    keyword: _keyword,
                    sectionTitle: TIM_t("最近"),
                    showSectionHeader: true,
                    onChanged: (conversationList) async {
                      _conversationList = conversationList;
                      if (_conversationList.isNotEmpty) {
                        await handleForwardMessage();
                      }
                    },
                  ),
                ),
              ],
            ),
    );
  }
}

class _ForwardSelectFriendPage extends StatefulWidget {
  final TUITheme theme;

  const _ForwardSelectFriendPage({
    required this.theme,
  });

  @override
  State<_ForwardSelectFriendPage> createState() =>
      _ForwardSelectFriendPageState();
}

class _ForwardSelectFriendPageState extends State<_ForwardSelectFriendPage> {
  final TextEditingController _searchController = TextEditingController();
  String _keyword = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _showName(V2TimFriendInfo item) {
    final remark = item.friendRemark?.trim() ?? '';
    if (remark.isNotEmpty) return remark;
    final nick = item.userProfile?.nickName?.trim() ?? '';
    if (nick.isNotEmpty) return nick;
    return item.userID;
  }

  Future<V2TimConversation> _buildConversation(V2TimFriendInfo item) async {
    final conversationID = "c2c_${item.userID}";
    final res = await TencentImSDKPlugin.v2TIMManager
        .getConversationManager()
        .getConversation(conversationID: conversationID);
    if (res.code == 0 && res.data != null) {
      return res.data!;
    }
    return V2TimConversation(
      conversationID: conversationID,
      userID: item.userID,
      type: 1,
      showName: item.friendRemark?.isNotEmpty == true
          ? item.friendRemark
          : ((item.userProfile?.nickName?.isNotEmpty == true)
              ? item.userProfile?.nickName
              : item.userID),
      faceUrl: item.userProfile?.faceUrl,
    );
  }

  Widget _buildSearchBar() {
    final builder = serviceLocator<TUIChatGlobalModel>().appSearchBarBuilder;
    if (builder != null) {
      return builder(
        context,
        _searchController,
        (value) => setState(() => _keyword = value.trim()),
      );
    }
    final theme = widget.theme;
    final fillColor = theme.inputFillColor ??
        theme.selectPanelBgColor ??
        const Color(0xFFF1F2F6);
    final hintColor = theme.weakTextColor ?? const Color(0xFF999999);
    final textColor = theme.darkTextColor ?? Colors.black;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 6, 16, 6),
      height: 40,
      decoration: BoxDecoration(
        color: fillColor,
        borderRadius: BorderRadius.circular(10),
      ),
      child: TextField(
        controller: _searchController,
        onChanged: (value) => setState(() => _keyword = value.trim()),
        style: TextStyle(color: textColor, fontSize: 14, height: 1.2),
        decoration: InputDecoration(
          hintText: TIM_t("搜索"),
          hintStyle: TextStyle(color: hintColor, fontSize: 14, height: 1.2),
          prefixIcon: Icon(Icons.search, color: hintColor, size: 18),
          prefixIconConstraints: const BoxConstraints(minWidth: 34, minHeight: 40),
          border: InputBorder.none,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 10),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    final keyword = _keyword.trim().toLowerCase();
    return Scaffold(
      backgroundColor: theme.weakBackgroundColor ?? Colors.white,
      appBar: AppBar(
        centerTitle: true,
        elevation: 0,
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        backgroundColor: theme.appbarBgColor ?? theme.weakBackgroundColor,
        iconTheme: IconThemeData(
          color: theme.primaryColor ?? const Color(0xFF1E90FF),
        ),
        title: Text(
          TIM_t("选择朋友"),
          style: TextStyle(
            color: theme.appbarTextColor ?? theme.darkTextColor,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: Column(
        children: [
          _buildSearchBar(),
          Expanded(
            child: TIMUIKitContact(
              isShowOnlineStatus: true,
              lifeCycle: FriendListLifeCycle(
                friendListWillMount: (list) async {
                  if (keyword.isEmpty) {
                    return list;
                  }
                  return list.where((item) {
                    final name = _showName(item);
                    final pinyin =
                        PinyinHelper.getPinyinE(name).toLowerCase();
                    final haystack =
                        '${item.userID} $name $pinyin'.toLowerCase();
                    return haystack.contains(keyword);
                  }).toList();
                },
              ),
              onTapItem: (item) async {
                final conversation = await _buildConversation(item);
                if (context.mounted) {
                  Navigator.pop(context, conversation);
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ForwardSelectGroupPage extends StatefulWidget {
  final TUITheme theme;

  const _ForwardSelectGroupPage({
    required this.theme,
  });

  @override
  State<_ForwardSelectGroupPage> createState() =>
      _ForwardSelectGroupPageState();
}

class _ForwardSelectGroupPageState extends State<_ForwardSelectGroupPage> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Widget _buildSearchBar() {
    final builder = serviceLocator<TUIChatGlobalModel>().appSearchBarBuilder;
    if (builder != null) {
      return builder(
        context,
        _searchController,
        (_) => setState(() {}),
      );
    }
    final theme = widget.theme;
    final fillColor = theme.inputFillColor ??
        theme.selectPanelBgColor ??
        const Color(0xFFF1F2F6);
    final hintColor = theme.weakTextColor ?? const Color(0xFF999999);
    final textColor = theme.darkTextColor ?? Colors.black;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 6, 16, 6),
      height: 40,
      decoration: BoxDecoration(
        color: fillColor,
        borderRadius: BorderRadius.circular(10),
      ),
      child: TextField(
        controller: _searchController,
        onChanged: (_) => setState(() {}),
        style: TextStyle(color: textColor, fontSize: 14, height: 1.2),
        decoration: InputDecoration(
          hintText: TIM_t("搜索"),
          hintStyle: TextStyle(color: hintColor, fontSize: 14, height: 1.2),
          prefixIcon: Icon(Icons.search, color: hintColor, size: 18),
          prefixIconConstraints: const BoxConstraints(minWidth: 34, minHeight: 40),
          border: InputBorder.none,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 10),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    return Scaffold(
      backgroundColor: theme.weakBackgroundColor ?? Colors.white,
      appBar: AppBar(
        centerTitle: true,
        elevation: 0,
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        backgroundColor: theme.appbarBgColor ?? theme.weakBackgroundColor,
        iconTheme: IconThemeData(
          color: theme.primaryColor ?? const Color(0xFF1E90FF),
        ),
        title: Text(
          TIM_t("选择群聊"),
          style: TextStyle(
            color: theme.appbarTextColor ?? theme.darkTextColor,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: Column(
        children: [
          _buildSearchBar(),
          Expanded(
            child: TIMUIKitGroup(
              searchKeyword: _searchController.text,
              isShowIndexBar: true,
              onTapItem: (groupInfo, conversation) {
                Navigator.pop(context, conversation);
              },
            ),
          ),
        ],
      ),
    );
  }
}
