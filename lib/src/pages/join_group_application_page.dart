import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tencent_cloud_chat_demo/src/i18n/app_i18n.dart';
import 'package:tencent_cloud_chat_demo/src/navigation/app_chat_route.dart';
import 'package:tencent_cloud_chat_demo/src/provider/theme.dart';
import 'package:tencent_cloud_chat_demo/src/theme/app_colors.dart';
import 'package:tencent_cloud_chat_demo/src/api/group_join_api.dart';
import 'package:tencent_cloud_chat_demo/src/models/group_join_source.dart';
import 'package:tencent_cloud_chat_demo/utils/group_invite_message.dart';
import 'package:tencent_cloud_chat_demo/utils/toast.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_callback.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_callback.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_conversation.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_conversation.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_group_info.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_group_info.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/life_cycle/add_group_life_cycle.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/view_models/tui_self_info_view_model.dart';
import 'package:tencent_cloud_chat_uikit/data_services/conversation/conversation_services.dart';
import 'package:tencent_cloud_chat_uikit/data_services/core/core_services_implements.dart';
import 'package:tencent_cloud_chat_uikit/data_services/group/group_services.dart';
import 'package:tencent_cloud_chat_uikit/data_services/services_locatar.dart';
import 'package:tencent_cloud_chat_uikit/tencent_cloud_chat_uikit.dart';
import 'package:tencent_cloud_chat_uikit/ui/widgets/avatar.dart';

/// 进群预览：非成员「加入群聊」，已是成员「进入群聊」。
class JoinGroupApplicationPage extends StatefulWidget {
  final V2TimGroupInfo groupInfo;
  final AddGroupLifeCycle? lifeCycle;
  final ValueChanged<V2TimConversation>? directToChat;
  final GroupJoinSource? joinSource;

  const JoinGroupApplicationPage({
    Key? key,
    required this.groupInfo,
    this.lifeCycle,
    this.directToChat,
    this.joinSource,
  }) : super(key: key);

  @override
  State<JoinGroupApplicationPage> createState() =>
      _JoinGroupApplicationPageState();
}

class _JoinGroupApplicationPageState extends State<JoinGroupApplicationPage> {
  final GroupServices _groupServices = serviceLocator<GroupServices>();
  final ConversationService _conversationService =
      serviceLocator<ConversationService>();
  final CoreServicesImpl _coreServices = serviceLocator<CoreServicesImpl>();

  V2TimGroupInfo? _detail;
  bool _loadingDetail = true;
  bool _hasJoined = false;
  bool _acting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _loadGroupDetail();
    });
  }

  Future<void> _loadGroupDetail() async {
    final groupID = widget.groupInfo.groupID.trim();
    if (groupID.isEmpty) {
      if (mounted) {
        setState(() {
          _detail = widget.groupInfo;
          _loadingDetail = false;
        });
      }
      return;
    }
    final res = await _groupServices.getGroupsInfo(groupIDList: [groupID]);
    V2TimGroupInfo? loaded = widget.groupInfo;
    if (res != null) {
      for (final item in res) {
        if (item.resultCode == 0 && item.groupInfo != null) {
          loaded = item.groupInfo;
          break;
        }
      }
    }
    final joinedGroups = await _groupServices.getJoinedGroupList();
    final hasJoined = joinedGroups?.any(
          (g) => g.groupID.trim() == groupID,
        ) ??
        false;
    if (!mounted) {
      return;
    }
    setState(() {
      _detail = loaded;
      _hasJoined = hasJoined;
      _loadingDetail = false;
    });
  }

  V2TimGroupInfo get _group => _detail ?? widget.groupInfo;

  String get _showName {
    final name = _group.groupName?.trim() ?? '';
    if (name.isNotEmpty) {
      return name;
    }
    return _group.groupID;
  }

  String get _introductionText {
    final intro = _group.introduction?.trim() ?? '';
    if (intro.isNotEmpty) {
      return intro;
    }
    return AppI18n.current.t(
      zhHans: '暂无群简介',
      zhHant: '暫無群簡介',
      en: 'No group description',
      ja: 'グループ紹介はありません',
      ko: '그룹 소개 없음',
    );
  }

  int get _memberCount => _group.memberCount ?? 0;

  String _defaultJoinMessage() {
    final loginUserInfo = _coreServices.loginUserInfo;
    final selfName = loginUserInfo?.nickName ??
        loginUserInfo?.userID ??
        serviceLocator<TUISelfInfoViewModel>().loginInfo?.nickName ??
        '';
    return AppI18n.current.format(
      zhHans: '我是{option1}',
      zhHant: '我是{option1}',
      en: 'I am {option1}',
      ja: '私は{option1}です',
      ko: '저는 {option1}입니다',
      vars: {'option1': selfName},
    );
  }

  Future<V2TimConversation?> _buildGroupConversation() async {
    final groupID = _group.groupID.trim();
    if (groupID.isEmpty) {
      return null;
    }
    final conversationID = 'group_$groupID';
    final conversation = await _conversationService.getConversation(
      conversationID: conversationID,
    );
    if (conversation != null) {
      return conversation;
    }
    final cached = await _conversationService
        .getConversationListByConversationId(convID: conversationID);
    if (cached != null) {
      return cached;
    }
    return V2TimConversation(
      conversationID: conversationID,
      type: 2,
      groupID: groupID,
      showName: _group.groupName,
      groupType: _group.groupType,
      faceUrl: _group.faceUrl,
    );
  }

  Future<void> _enterChat() async {
    if (_acting || _loadingDetail) {
      return;
    }
    setState(() => _acting = true);
    try {
      final conversation = await _buildGroupConversation();
      if (!mounted) {
        return;
      }
      if (conversation == null) {
        ToastUtils.toast(AppI18n.current.t(
          zhHans: '进入群聊失败',
          zhHant: '進入群聊失敗',
          en: 'Failed to enter group chat',
          ja: 'グループチャットに入れませんでした',
          ko: '그룹 채팅 입장 실패',
        ));
        return;
      }
      if (widget.directToChat != null) {
        widget.directToChat!(conversation);
        Navigator.of(context).pop();
        return;
      }
      await Navigator.push(
        context,
        appChatRoute(conversation),
      );
    } finally {
      if (mounted) {
        setState(() => _acting = false);
      }
    }
  }

  Future<V2TimCallback?> _joinGroup() async {
    final groupID = _group.groupID.trim();
    final message = _defaultJoinMessage();
    if (widget.lifeCycle?.shouldAddGroup != null &&
        await widget.lifeCycle!.shouldAddGroup(groupID, message, context) ==
            false) {
      return null;
    }
    if (GroupJoinApi.isSelfHostedGovernanceGroupType(_group.groupType)) {
      final result = await GroupJoinApi.instance.applyJoin(
        groupId: groupID,
        message: message,
        joinSource: widget.joinSource,
      );
      switch (result.outcome) {
        case GroupJoinOutcome.added:
          return V2TimCallback(code: 0, desc: 'ok');
        case GroupJoinOutcome.pending:
          return V2TimCallback(code: 0, desc: 'PENDING');
        case GroupJoinOutcome.failed:
          return V2TimCallback(
            code: -1,
            desc: result.code ?? 'JOIN_FAILED',
          );
      }
    }
    return V2TimCallback(code: -1, desc: 'JOIN_NOT_SUPPORTED');
  }

  Future<void> _handleJoin() async {
    if (_acting || _loadingDetail) {
      return;
    }
    setState(() => _acting = true);
    try {
      final res = await _joinGroup();
      if (!mounted) {
        return;
      }
      if (res?.code == 0) {
        final desc = res?.desc ?? '';
        ToastUtils.toast(
          desc.toUpperCase().contains('PENDING')
              ? GroupInviteMessage.joinResultMessage(
                  code: desc,
                  outcome: 'pending',
                )
              : (GroupJoinApi.isSelfHostedGovernanceGroupType(_group.groupType) &&
                      desc == 'ok'
                  ? AppI18n.current.t(
                      zhHans: '已加入群聊',
                      zhHant: '已加入群聊',
                      en: 'Joined the group',
                      ja: 'グループに参加しました',
                      ko: '그룹에 참가했습니다',
                    )
                  : AppI18n.current.t(
                      zhHans: '群申请已发送',
                      zhHant: '群申請已發送',
                      en: 'Group request sent',
                      ja: 'グループ参加申請を送信しました',
                      ko: '그룹 가입 요청을 보냈습니다',
                    )),
        );
        Navigator.of(context).pop(true);
      } else if (res != null) {
        final desc = res.desc.trim();
        ToastUtils.toast(
          desc.isNotEmpty
              ? GroupInviteMessage.joinResultMessage(code: desc)
              : AppI18n.current.t(
                  zhHans: '加入失败',
                  zhHant: '加入失敗',
                  en: 'Failed to join',
                  ja: '参加に失敗しました',
                  ko: '가입 실패',
                ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _acting = false);
      }
    }
  }

  Future<void> _handlePrimaryAction() async {
    if (_hasJoined) {
      await _enterChat();
      return;
    }
    await _handleJoin();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<DefaultThemeData>(context).theme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    // 页面底与文案走 AppColors，避免深色模式下整页白底。
    final pageBackgroundColor = AppColors.background(dark: dark);
    final titleColor = AppColors.text(dark: dark);
    final secondaryColor = AppColors.subText(dark: dark);
    final primaryColor = theme.primaryColor ?? AppColors.primaryBlue;
    final i18n = AppI18n.of(context);
    final actionLabel = _hasJoined
        ? i18n.t(
            zhHans: '进入群聊',
            zhHant: '進入群聊',
            en: 'Enter Group Chat',
            ja: 'グループチャットに入る',
            ko: '그룹 채팅 입장',
          )
        : i18n.t(
            zhHans: '加入群聊',
            zhHant: '加入群聊',
            en: 'Join Group Chat',
            ja: 'グループに参加',
            ko: '그룹 가입',
          );

    return Scaffold(
      backgroundColor: pageBackgroundColor,
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: primaryColor,
            size: 22,
          ),
        ),
        backgroundColor: pageBackgroundColor,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: _loadingDetail
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
                    child: Column(
                      children: [
                        const SizedBox(height: 16),
                        SizedBox(
                          width: 96,
                          height: 96,
                          child: Avatar(
                            faceUrl: _group.faceUrl ?? '',
                            showName: _showName,
                            type: 2,
                            borderRadius: BorderRadius.circular(48),
                            isShowBigWhenClick: true,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          _showName,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: titleColor,
                            height: 1.25,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          i18n.format(
                            zhHans: '共{option1}人',
                            zhHant: '共{option1}人',
                            en: '{option1} members',
                            ja: 'メンバー{option1}人',
                            ko: '멤버 {option1}명',
                            vars: {'option1': '$_memberCount'},
                          ),
                          style: TextStyle(
                            fontSize: 14,
                            color: secondaryColor,
                          ),
                        ),
                        const SizedBox(height: 36),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            _introductionText,
                            style: TextStyle(
                              fontSize: 15,
                              height: 1.45,
                              color: titleColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                  child: SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _acting ? null : _handlePrimaryAction,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor:
                            primaryColor.withValues(alpha: 0.5),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: _acting
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            )
                          : Text(
                              actionLabel,
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
