import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tencent_chat_i18n_tool/tencent_chat_i18n_tool.dart';
import 'package:tencent_cloud_chat_demo/src/all_group_application_list.dart';
import 'package:tencent_cloud_chat_demo/src/chat.dart';
import 'package:tencent_cloud_chat_demo/src/conversation.dart';
import 'package:tencent_cloud_chat_demo/src/i18n/app_i18n.dart';
import 'package:tencent_cloud_chat_demo/src/pages/c2c_chat_settings_page.dart';
import 'package:tencent_cloud_chat_demo/src/pages/cross_platform/wide_screen/desktop_archive_host.dart';
import 'package:tencent_cloud_chat_demo/src/pages/cross_platform/wide_screen/desktop_create_group_host.dart';
import 'package:tencent_cloud_chat_demo/src/pages/cross_platform/wide_screen/desktop_group_notice_host.dart';
import 'package:tencent_cloud_chat_demo/src/pages/cross_platform/wide_screen/desktop_profile_host.dart';
import 'package:tencent_cloud_chat_demo/src/pages/cross_platform/wide_screen/desktop_side_settings_shell.dart';
import 'package:tencent_cloud_chat_demo/src/create_group.dart';
import 'package:tencent_cloud_chat_demo/src/user_profile.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_deleted_bus.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_pin_service.dart';
import 'package:tencent_cloud_chat_demo/src/services/group_notice_refresh_bus.dart';
import 'package:tencent_cloud_chat_demo/src/utils/message_conversation_id.dart';
import 'package:tencent_cloud_chat_demo/src/widgets/conversation_profile_pin_bar.dart';
import 'package:tencent_cloud_chat_demo/src/widgets/group_profile_join_mode_row.dart';
import 'package:tencent_cloud_chat_demo/src/pages/cross_platform/wide_screen/empty_widget.dart';
import 'package:tencent_cloud_chat_demo/src/provider/theme.dart';
import 'package:tencent_cloud_chat_demo/src/search.dart';
import 'package:tencent_cloud_chat_demo/utils/toast.dart';
import 'package:tencent_cloud_chat_demo/utils/custom_message/custom_last_message.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_conversation.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_conversation.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_message.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_message.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/life_cycle/group_profile_life_cycle.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/separate_models/tui_group_profile_model.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/view_models/tui_conversation_view_model.dart';
import 'package:tencent_cloud_chat_uikit/data_services/core/tim_uikit_wide_modal_operation_key.dart';
import 'package:tencent_cloud_chat_uikit/data_services/services_locatar.dart';
import 'package:tencent_cloud_chat_uikit/tencent_cloud_chat_uikit.dart';
import 'package:tencent_cloud_chat_uikit/ui/controller/tim_uikit_conversation_controller.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/message_anchor.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/platform.dart';
import 'package:tencent_cloud_chat_uikit/ui/views/TIMUIKitGroupProfile/group_profile_widget.dart';
import 'package:tencent_cloud_chat_uikit/ui/views/TIMUIKitProfile/profile_widget.dart';
import 'package:tencent_cloud_chat_uikit/ui/widgets/wide_popup.dart';

class ConversationAndChat extends StatefulWidget {
  final V2TimConversation? conversation;
  final MessageAnchor? searchJumpAnchor;
  final ConversationListScope listScope;
  /// 是否承接桌面壳内的用户资料（消息 / 群聊 Tab）。
  final bool showDesktopUserProfile;

  const ConversationAndChat({
    Key? key,
    this.conversation,
    this.searchJumpAnchor,
    this.listScope = ConversationListScope.c2c,
    this.showDesktopUserProfile = false,
  }) : super(key: key);

  @override
  State<ConversationAndChat> createState() => _ConversationAndChatState();
}

class _ConversationAndChatState extends State<ConversationAndChat> {
  final TIMUIKitConversationController _conversationController = TIMUIKitConversationController();
  final TUIConversationViewModel _conversationViewModel =
      serviceLocator<TUIConversationViewModel>();

  V2TimConversation? currentConversation;
  MessageAnchor? pendingMessageAnchor;
  V2TimMessage? pendingTargetMessage;
  String? _cachedCurrentConversationFaceUrl;
  bool isShowSearch = false;
  /// 右侧「设置」边栏（群资料 / 单聊资料，形态与群聊一致）
  bool isShowSideProfile = false;

  @override
  void initState() {
    super.initState();
    currentConversation = widget.conversation;
    pendingMessageAnchor = widget.searchJumpAnchor;
    pendingTargetMessage = null;
    _cachedCurrentConversationFaceUrl = currentConversation?.faceUrl;
    _conversationViewModel.addListener(_onConversationViewModelChanged);
    ConversationDeletedBus.instance.revision
        .addListener(_onConversationsDeletedBus);
    DesktopProfileHost.userIdNotifier.addListener(_onDesktopProfileHostChanged);
  }

  @override
  void dispose() {
    DesktopProfileHost.userIdNotifier.removeListener(_onDesktopProfileHostChanged);
    ConversationDeletedBus.instance.revision
        .removeListener(_onConversationsDeletedBus);
    _conversationViewModel.removeListener(_onConversationViewModelChanged);
    super.dispose();
  }

  /// 侧栏打开资料时，左侧若卡在「Web 不支持搜索」页，先退回会话列表。
  void _onDesktopProfileHostChanged() {
    if (!mounted || !widget.showDesktopUserProfile) {
      return;
    }
    if (!DesktopProfileHost.isOpen || !isShowSearch) {
      return;
    }
    setState(() {
      isShowSearch = false;
    });
  }

  void _openMessageSearch() {
    // Web SDK 无全局消息搜索：勿替换列表栏，否则会出现无返回的 NotSupport 页。
    if (kIsWeb || PlatformUtils().isWeb) {
      ToastUtils.toast(AppI18n.of(context).t(
        zhHans: '网页端暂不支持消息搜索',
        zhHant: '網頁端暫不支援訊息搜尋',
        en: 'Message search is not available on Web',
        ja: 'Webではメッセージ検索に対応していません',
        ko: '웹에서는 메시지 검색을 지원하지 않습니다',
      ));
      return;
    }
    setState(() {
      isShowSearch = true;
    });
  }

  void _onConversationsDeletedBus() {
    if (!mounted || currentConversation == null) {
      return;
    }
    final currentId = currentConversation!.conversationID.trim();
    if (currentId.isEmpty) {
      return;
    }
    final hit = ConversationDeletedBus.instance.lastDeletedIds.any(
      (id) => MessageConversationId.sameConversation(id, currentId),
    );
    if (!hit) {
      return;
    }
    _clearOpenConversationWindow();
  }

  void _clearOpenConversationWindow() {
    if (!mounted) {
      return;
    }
    setState(() {
      currentConversation = null;
      isShowSideProfile = false;
      _syncSideProfilePaneOpen(false);
      pendingMessageAnchor = null;
      pendingTargetMessage = null;
      _cachedCurrentConversationFaceUrl = null;
    });
  }

  void _onConversationViewModelChanged() {
    if (!mounted || currentConversation == null) return;
    final conversationID = currentConversation!.conversationID;
    if (conversationID != null && conversationID.isNotEmpty) {
      for (final conv in _conversationViewModel.conversationList) {
        if (conv?.conversationID == conversationID) {
          final latestUrl = conv?.faceUrl ?? '';
          if (latestUrl.isNotEmpty &&
              latestUrl != (currentConversation!.faceUrl ?? '')) {
            currentConversation!.faceUrl = latestUrl;
          }
          break;
        }
      }
    }
    final faceUrl = currentConversation!.faceUrl ?? '';
    if (faceUrl == (_cachedCurrentConversationFaceUrl ?? '')) {
      return;
    }
    _cachedCurrentConversationFaceUrl = faceUrl;
    setState(() {});
  }

  @override
  void didUpdateWidget(ConversationAndChat oldWidget) {
    super.didUpdateWidget(oldWidget);
    setState(() {
      isShowSideProfile = false;
      _syncSideProfilePaneOpen(false);
      currentConversation = widget.conversation;
      pendingMessageAnchor = widget.searchJumpAnchor;
      pendingTargetMessage = null;
      _cachedCurrentConversationFaceUrl = currentConversation?.faceUrl;
    });
  }

  String _messageJumpKey(MessageAnchor? anchor) => anchor?.stableKey ?? '';

  void _syncSideProfilePaneOpen(bool open) {
    GroupNoticeRefreshBus.instance.setSideProfilePanelOpen(open);
  }

  void _openSideProfile() {
    setState(() {
      isShowSideProfile = true;
    });
    _syncSideProfilePaneOpen(true);
  }

  void _closeSideProfile() {
    if (!mounted) {
      return;
    }
    setState(() {
      isShowSideProfile = false;
    });
    _syncSideProfilePaneOpen(false);
    final groupId = currentConversation?.groupID?.trim() ?? '';
    if (groupId.isNotEmpty) {
      GroupNoticeRefreshBus.instance.notifyRefresh(groupId);
    }
  }

  /// 群成员点击：仍用轻量浮层名片；会话「设置」走右侧边栏。
  void onClickUserName(Offset? offset, String user) {
    final conversation = currentConversation != null &&
            currentConversation!.userID == user
        ? currentConversation!
        : ConversationPinService.c2cConversationSnapshot(userID: user);
    TUIKitWidePopup.showPopupWindow(
        operationKey: TUIKitWideModalOperationKey.showUserProfileFromChat,
        context: context,
        isDarkBackground: false,
        width: 350,
        offset: offset,
        height: 460,
        child: (closeFunc) => Container(
              padding: const EdgeInsets.only(top: 20, left: 10, right: 10),
              child: TIMUIKitProfile(
                smallCardMode: true,
                profileWidgetBuilder: ProfileWidgetBuilder(
                  pinConversationBar: (isPinned, onChange) {
                    return ConversationProfilePinBar(
                      conversation: conversation,
                      source: 'wide_chat_profile_popup',
                      smallCardMode: true,
                    );
                  },
                ),
                profileWidgetsOrder: const [
                  ProfileWidgetEnum.userInfoCard,
                  ProfileWidgetEnum.operationDivider,
                  ProfileWidgetEnum.remarkBar,
                  ProfileWidgetEnum.genderBar,
                  ProfileWidgetEnum.birthdayBar,
                  ProfileWidgetEnum.operationDivider,
                  ProfileWidgetEnum.addToBlockListBar,
                  ProfileWidgetEnum.pinConversationBar,
                  ProfileWidgetEnum.messageMute,
                ],
                userID: user,
              ),
            ));
  }

  /// Web / 桌面设置侧栏宽度（单栏列表，略宽于原先 350）。
  static const double _sideProfileWidth = 400;

  Widget _buildSideProfileBody() {
    final conversation = currentConversation!;
    final groupId = TencentUtils.checkString(conversation.groupID);
    if (groupId != null) {
      return TIMUIKitGroupProfile(
        groupID: groupId,
        profileWidgetBuilder: GroupProfileWidgetBuilder(
          groupJoiningModeBar: (groupAddOptType, handleActionTap) {
            return const GroupProfileJoinModeRow();
          },
          pinedConversationBar: (isPinned, onChange) {
            return Consumer<TUIGroupProfileModel>(
              builder: (context, model, _) {
                return ConversationGroupProfilePinBar(
                  groupID: groupId,
                  conversation: model.conversation,
                  source: 'wide_group_profile',
                  onApplied: (pinned) {
                    if (model.conversation != null) {
                      model.conversation!.isPinned = pinned;
                    }
                  },
                );
              },
            );
          },
        ),
        lifeCycle: GroupProfileLifeCycle(
          didLeaveGroup: () async {
            if (!mounted) {
              return;
            }
            setState(() {
              isShowSideProfile = false;
              currentConversation = null;
            });
            _syncSideProfilePaneOpen(false);
          },
        ),
        onClickUser: (memberInfo, tapDetails) {
          onClickUserName(
            tapDetails != null
                ? Offset(
                    min(tapDetails.globalPosition.dx,
                        MediaQuery.of(context).size.width - 350),
                    min(tapDetails.globalPosition.dy,
                        MediaQuery.of(context).size.height - 470),
                  )
                : null,
            memberInfo.userID,
          );
        },
        profileWidgetsOrder: const [
          GroupProfileWidgetEnum.detailCard,
          GroupProfileWidgetEnum.operationDivider,
          GroupProfileWidgetEnum.memberListTile,
          GroupProfileWidgetEnum.operationDivider,
          GroupProfileWidgetEnum.groupNotice,
          GroupProfileWidgetEnum.groupManage,
          GroupProfileWidgetEnum.groupJoiningModeBar,
          GroupProfileWidgetEnum.operationDivider,
          GroupProfileWidgetEnum.pinedConversationBar,
          GroupProfileWidgetEnum.muteGroupMessageBar,
          GroupProfileWidgetEnum.nameCardBar,
          GroupProfileWidgetEnum.buttonArea,
        ],
      );
    }

    final userId = conversation.userID?.trim() ?? '';
    if (userId.isEmpty) {
      return const SizedBox.shrink();
    }
    return C2cChatSettingsPage(
      key: ValueKey('c2c_side_${conversation.conversationID}'),
      conversation: conversation,
      embeddedInSidePanel: true,
      directToChat: (next) {
        if (!mounted) {
          return;
        }
        setState(() {
          isShowSideProfile = false;
          currentConversation = next;
          pendingMessageAnchor = null;
          pendingTargetMessage = null;
        });
        _syncSideProfilePaneOpen(false);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<DefaultThemeData>(context).theme;
    return Row(
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 300, maxWidth: 340),
          child: ClipRect(
            child: isShowSearch
              ? Search(
                  onTapConversation: (conversation, anchor) {
                    DesktopProfileHost.close();
                    DesktopGroupNoticeHost.close();
                    DesktopArchiveHost.close();
                    DesktopCreateGroupHost.close();
                    setState(() {
                      isShowSideProfile = false;
                      _syncSideProfilePaneOpen(false);
                      currentConversation = conversation;
                      pendingMessageAnchor = anchor;
                      pendingTargetMessage = null;
                      isShowSearch = false;
                    });
                  },
                  onTapConversationWithMessage:
                      (conversation, anchor, targetMessage) {
                    DesktopProfileHost.close();
                    DesktopGroupNoticeHost.close();
                    DesktopArchiveHost.close();
                    DesktopCreateGroupHost.close();
                    setState(() {
                      isShowSideProfile = false;
                      _syncSideProfilePaneOpen(false);
                      currentConversation = conversation;
                      pendingMessageAnchor = anchor;
                      pendingTargetMessage = targetMessage;
                      isShowSearch = false;
                    });
                  },
                  isAutoFocus: true,
                  onBack: () {
                    setState(() {
                      isShowSearch = false;
                    });
                  },
                )
              : Conversation(
                  selectedConversation: currentConversation,
                  listScope: widget.listScope,
                  onConversationChanged: (conversation) {
                    if (conversation == null) {
                      _clearOpenConversationWindow();
                      return;
                    }
                    DesktopProfileHost.close();
                    DesktopGroupNoticeHost.close();
                    DesktopArchiveHost.close();
                    DesktopCreateGroupHost.close();
                    setState(() {
                      isShowSideProfile = false;
                      _syncSideProfilePaneOpen(false);
                      currentConversation = conversation;
                      pendingMessageAnchor = null;
                    });
                  },
                  onClickSearch: _openMessageSearch,
                  conversationController: _conversationController,
                ),
          ),
        ),
        SizedBox(
          width: 1,
          child: Container(
            color: theme.weakDividerColor,
          ),
        ),
        Expanded(
          child: ValueListenableBuilder<DesktopCreateGroupArgs?>(
            valueListenable: DesktopCreateGroupHost.argsNotifier,
            builder: (context, createGroupArgs, _) {
              final expectCreateScope =
                  widget.listScope == ConversationListScope.group
                      ? DesktopCreateGroupScope.group
                      : DesktopCreateGroupScope.c2c;
              final showCreateGroup = widget.showDesktopUserProfile &&
                  createGroupArgs != null &&
                  createGroupArgs.scope == expectCreateScope;
              if (showCreateGroup) {
                return Navigator(
                  key: ValueKey('desktop_create_group_$expectCreateScope'),
                  onGenerateRoute: (settings) {
                    return MaterialPageRoute(
                      settings: settings,
                      builder: (_) => CreateGroup(
                        key: createGroupKey,
                        convType: createGroupArgs.convType,
                        initialSelectedUserIds:
                            createGroupArgs.initialSelectedUserIds,
                        selectGroupTypeAfterMembers:
                            createGroupArgs.selectGroupTypeAfterMembers,
                        onDesktopClose: DesktopCreateGroupHost.close,
                        directToChat: (conversation) {
                          DesktopCreateGroupHost.close();
                          setState(() {
                            isShowSideProfile = false;
                            _syncSideProfilePaneOpen(false);
                            currentConversation = conversation;
                            pendingMessageAnchor = null;
                            pendingTargetMessage = null;
                          });
                        },
                      ),
                    );
                  },
                );
              }
              return ValueListenableBuilder<DesktopArchiveScope?>(
                valueListenable: DesktopArchiveHost.scopeNotifier,
                builder: (context, archiveScope, _) {
                  final expectArchiveScope =
                      widget.listScope == ConversationListScope.group
                          ? DesktopArchiveScope.group
                          : DesktopArchiveScope.c2c;
                  final showArchive = widget.showDesktopUserProfile &&
                      archiveScope == expectArchiveScope;
                  if (showArchive) {
                    return ArchivedConversationPage(
                      key: ValueKey('desktop_archive_$expectArchiveScope'),
                      controller: _conversationController,
                      listScope: widget.listScope,
                      shellEmbedded: true,
                      onClose: DesktopArchiveHost.close,
                      onTapConversation: (conversation) {
                        if (conversation == null) {
                          return;
                        }
                        DesktopArchiveHost.close();
                        setState(() {
                          isShowSideProfile = false;
                          _syncSideProfilePaneOpen(false);
                          currentConversation = conversation;
                          pendingMessageAnchor = null;
                          pendingTargetMessage = null;
                        });
                      },
                      lastMessageAbstractBuilder:
                          conversationListLastMessageAbstract,
                    );
                  }
                  return ValueListenableBuilder<bool>(
                    valueListenable: DesktopGroupNoticeHost.openNotifier,
                    builder: (context, groupNoticeOpen, _) {
                      final showGroupNotice =
                          widget.showDesktopUserProfile &&
                              widget.listScope == ConversationListScope.group &&
                              groupNoticeOpen;
                      if (showGroupNotice) {
                        return AllGroupApplicationListPage(
                          key: const ValueKey('desktop_group_notice'),
                          shellEmbedded: true,
                          onClose: DesktopGroupNoticeHost.close,
                          onOpenConversation: (conversation) {
                            DesktopGroupNoticeHost.close();
                            setState(() {
                              isShowSideProfile = false;
                              _syncSideProfilePaneOpen(false);
                              currentConversation = conversation;
                              pendingMessageAnchor = null;
                              pendingTargetMessage = null;
                            });
                          },
                        );
                      }
                      return ValueListenableBuilder<String?>(
                        valueListenable: DesktopProfileHost.userIdNotifier,
                        builder: (context, profileUserId, _) {
                          final showProfile =
                              widget.showDesktopUserProfile &&
                                  (profileUserId?.trim().isNotEmpty ?? false);
                          if (showProfile) {
                            return UserProfile(
                              key: ValueKey('desktop_profile_$profileUserId'),
                              userID: profileUserId!.trim(),
                              groupId: DesktopProfileHost.groupId,
                              onClose: DesktopProfileHost.close,
                              onClickSendMessage: (conversation) {
                                DesktopProfileHost.close();
                                DesktopGroupNoticeHost.close();
                                DesktopArchiveHost.close();
                                DesktopCreateGroupHost.close();
                                setState(() {
                                  isShowSideProfile = false;
                                  _syncSideProfilePaneOpen(false);
                                  currentConversation = conversation;
                                  pendingMessageAnchor = null;
                                  pendingTargetMessage = null;
                                });
                              },
                            );
                          }
                          if (currentConversation == null) {
                            return EmptyWidget(
                              title: TIM_t("99Chat · IM"),
                              description: TIM_t("服务亿级 99Chat 用户的即时通讯技术"),
                            );
                          }
                          return Stack(
                            children: [
                              Chat(
                                key: ValueKey(
                                  '${currentConversation!.conversationID}_${_messageJumpKey(pendingMessageAnchor)}',
                                ),
                                directToChat: (conversation) {
                                  DesktopProfileHost.close();
                                  DesktopGroupNoticeHost.close();
                                  DesktopArchiveHost.close();
                                  DesktopCreateGroupHost.close();
                                  setState(() {
                                    isShowSideProfile = false;
                                    _syncSideProfilePaneOpen(false);
                                    currentConversation = conversation;
                                    pendingMessageAnchor = null;
                                    pendingTargetMessage = null;
                                  });
                                },
                                selectedConversation: currentConversation!,
                                entryUnreadCount:
                                    currentConversation!.unreadCount ?? 0,
                                initFindingMsg: pendingTargetMessage,
                                searchJumpAnchor: pendingMessageAnchor,
                                showGroupProfile: _openSideProfile,
                              ),
                              DesktopSideSettingsShell(
                                theme: theme,
                                width: _sideProfileWidth,
                                visible: isShowSideProfile,
                                title: TIM_t("设置"),
                                onClose: _closeSideProfile,
                                child: currentConversation == null
                                    ? const SizedBox.shrink()
                                    : _buildSideProfileBody(),
                              ),
                            ],
                          );
                        },
                      );
                    },
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
