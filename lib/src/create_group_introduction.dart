import 'package:flutter/material.dart';
import 'package:tencent_cloud_chat_demo/src/i18n/app_i18n.dart';
import 'package:tencent_cloud_chat_sdk/enum/group_type.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_conversation.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_conversation.dart';
import 'package:tencent_cloud_chat_uikit/data_services/core/tim_uikit_wide_modal_operation_key.dart';
import 'package:provider/provider.dart';
import 'package:tencent_cloud_chat_demo/src/create_group.dart';
import 'package:tencent_cloud_chat_demo/src/provider/theme.dart';
import 'package:tencent_cloud_chat_uikit/theme/tui_theme.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/screen_utils.dart';
import 'package:tencent_cloud_chat_uikit/ui/widgets/wide_popup.dart';
import 'package:tencent_cloud_chat_demo/src/navigation/app_page_transitions.dart';
import 'package:tencent_cloud_chat_demo/src/ui/utils/desktop_modal_layout.dart';

class CreateGroupIntroduction extends StatefulWidget {
  final ValueChanged<V2TimConversation>? directToChat;
  final VoidCallback? closeFunc;

  /// 为 true 时仅选择群类型并通过 [Navigator.pop] 返回 [GroupTypeForUIKit]，
  /// 不再进入选人页（用于「先选好友 → 再选类型」流程）。
  final bool chooseTypeOnly;

  const CreateGroupIntroduction({
    Key? key,
    this.directToChat,
    this.closeFunc,
    this.chooseTypeOnly = false,
  }) : super(key: key);

  static final groupTypeColorMap = {
    GroupType.Work: const Color(0xFF1E90FF),
    GroupType.Public: const Color(0xFF1E90FF),
    GroupType.Meeting: const Color(0xFFF38787),
    GroupType.Community: const Color(0xFF1E90FF),
  };

  static String groupTypeName(AppI18n i18n, String groupType) {
    switch (groupType) {
      case GroupType.Work:
        return i18n.t(
          zhHans: '好友工作群（Work）',
          zhHant: '好友工作群（Work）',
          en: 'Work Group (Work)',
          ja: 'Workグループ',
          ko: 'Work 그룹',
        );
      case GroupType.Public:
        return i18n.t(
          zhHans: '陌生人社交群（Public）',
          zhHant: '陌生人社交群（Public）',
          en: 'Public Group (Public)',
          ja: 'Publicグループ',
          ko: 'Public 그룹',
        );
      case GroupType.Meeting:
        return i18n.t(
          zhHans: '临时会议群（Meeting）',
          zhHant: '臨時會議群（Meeting）',
          en: 'Meeting Group (Meeting)',
          ja: 'Meetingグループ',
          ko: 'Meeting 그룹',
        );
      case GroupType.Community:
        return i18n.t(
          zhHans: '社群（Community）',
          zhHant: '社群（Community）',
          en: 'Community (Community)',
          ja: 'Community',
          ko: 'Community',
        );
      default:
        return groupType;
    }
  }

  static String groupTypeDescription(AppI18n i18n, String groupType) {
    switch (groupType) {
      case GroupType.Work:
        return i18n.t(
          zhHans: '类似普通微信群，创建后仅支持已在群内的好友邀请加群，且无需被邀请方同意或群主审批。',
          zhHant: '類似普通微信群，建立後僅支援已在群內的好友邀請加群，且無需被邀請方同意或群主審批。',
          en: 'Like a typical WeChat group: only existing members can invite friends, with no approval required.',
          ja: '一般的なWeChatグループのように、既存メンバーのみが友達を招待でき、承認は不要です。',
          ko: '일반 WeChat 그룹처럼 기존 멤버만 친구를 초대할 수 있으며 승인이 필요 없습니다.',
        );
      case GroupType.Public:
        return i18n.t(
          zhHans: '类似 QQ 群，创建后群主可以指定群管理员，用户搜索群 ID 发起加群申请后，需要群主或管理员审批通过才能入群。',
          zhHant: '類似 QQ 群，建立後群主可以指定群管理員，使用者搜尋群 ID 發起加群申請後，需要群主或管理員審批通過才能入群。',
          en: 'Like a QQ group: the owner can assign admins, and join requests require owner or admin approval.',
          ja: 'QQグループのように、オーナーが管理者を指定し、参加申請は承認が必要です。',
          ko: 'QQ 그룹처럼 그룹장이 관리자를 지정하며, 가입 신청은 승인이 필요합니다.',
        );
      case GroupType.Meeting:
        return i18n.t(
          zhHans: '创建后可以随意进出，且支持查看入群前消息；适合用于音视频会议场景、在线教育场景等与实时音视频产品结合的场景。',
          zhHant: '建立後可以隨意進出，且支援查看入群前訊息；適合用於音視訊會議場景、線上教育場景等與即時音視訊產品結合的場景。',
          en: 'Members can join and leave freely and view pre-join messages; ideal for meetings and online education.',
          ja: '自由に出入りでき、参加前のメッセージも閲覧可能。会議やオンライン教育向けです。',
          ko: '자유롭게 출입할 수 있고 가입 전 메시지도 볼 수 있습니다. 회의·온라인 교육에 적합합니다.',
        );
      case GroupType.Community:
        return i18n.t(
          zhHans: '创建后可以随意进出，最多支持10w人，支持历史消息存储，用户搜索群 ID 发起加群申请后，无需管理员审批即可进群。',
          zhHant: '建立後可以隨意進出，最多支援10w人，支援歷史訊息儲存，使用者搜尋群 ID 發起加群申請後，無需管理員審批即可進群。',
          en: 'Supports up to 100k members with message history; users can join without admin approval after searching the group ID.',
          ja: '最大10万人、履歴保存に対応。グループID検索後、管理者承認なしで参加できます。',
          ko: '최대 10만 명, 메시지 기록 저장 지원. 그룹 ID 검색 후 관리자 승인 없이 가입 가능합니다.',
        );
      default:
        return '';
    }
  }

  @override
  State<CreateGroupIntroduction> createState() => _CreateGroupIntroductionState();
}

class _CreateGroupIntroductionState extends State<CreateGroupIntroduction> {
  void createGroupFunc(GroupTypeForUIKit type) {
    if (widget.chooseTypeOnly) {
      Navigator.of(context).pop(type);
      return;
    }

    final isWideScreen = TUIKitScreenUtils.getFormFactor(context) == DeviceType.Desktop;

    if (isWideScreen) {
      if (widget.closeFunc != null) {
        widget.closeFunc!();
      }

      final screenSize = DesktopModalLayout.createGroupPicker(context);
      TUIKitWidePopup.showPopupWindow(
        operationKey: TUIKitWideModalOperationKey.chooseContacts,
        context: context,
        width: screenSize.width,
        height: screenSize.height,
        borderRadius: const BorderRadius.all(Radius.circular(20)),
        child: (closeFunc) => Navigator(
          onGenerateRoute: (settings) {
            return MaterialPageRoute(
              settings: settings,
              builder: (_) => CreateGroup(
                key: createGroupKey,
                onDesktopClose: closeFunc,
                convType: type,
                directToChat: (conversation) {
                  closeFunc();
                  widget.directToChat?.call(conversation);
                },
              ),
            );
          },
        ),
      );
    } else {
      Navigator.of(context).push(
        AppMaterialPageRoute(
          builder: (context) => CreateGroup(
            convType: type,
            directToChat: widget.directToChat,
          ),
        ),
      );
    }
  }

  handleTapTooltipItem(String groupType) {
    switch (groupType) {
      case GroupType.Work:
        createGroupFunc(GroupTypeForUIKit.work);
        break;
      case GroupType.Public:
        createGroupFunc(GroupTypeForUIKit.public);
        break;
      case GroupType.Meeting:
        createGroupFunc(GroupTypeForUIKit.meeting);
        break;
      case GroupType.Community:
        createGroupFunc(GroupTypeForUIKit.community);
        break;
    }
  }

  Widget renderGroupItem(String groupType, TUITheme theme, AppI18n i18n) {
    return Container(
      decoration:
          BoxDecoration(border: Border.all(color: theme.weakBackgroundColor!), borderRadius: BorderRadius.circular(10)),
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: InkWell(
        onTap: () {
          handleTapTooltipItem(groupType);
        },
        child: Container(
          padding: const EdgeInsets.all(8),
          child: Row(
            children: [
              Icon(Icons.group, size: 40, color: CreateGroupIntroduction.groupTypeColorMap[groupType]!),
              const SizedBox(width: 20),
              Expanded(
                  child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    CreateGroupIntroduction.groupTypeName(i18n, groupType),
                    style: TextStyle(
                        fontSize: 16,
                        color: CreateGroupIntroduction.groupTypeColorMap[groupType]!,
                        fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    CreateGroupIntroduction.groupTypeDescription(i18n, groupType),
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.weakTextColor,
                    ),
                  )
                ],
              ))
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<DefaultThemeData>(context).theme;
    final i18n = AppI18n.of(context);

    Widget createGroupList() {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              renderGroupItem(GroupType.Work, theme, i18n),
              renderGroupItem(GroupType.Public, theme, i18n),
              renderGroupItem(GroupType.Meeting, theme, i18n),
              renderGroupItem(GroupType.Community, theme, i18n),
            ],
          ),
        ),
      );
    }

    return TUIKitScreenUtils.getDeviceWidget(
        context: context,
        desktopWidget: createGroupList(),
        defaultWidget: Scaffold(
          backgroundColor: theme.weakBackgroundColor ?? Colors.white,
          appBar: AppBar(
              title: Text(
                i18n.t(
                  zhHans: '创建群聊',
                  zhHant: '建立群聊',
                  en: 'Create Group',
                  ja: 'グループを作成',
                  ko: '그룹 만들기',
                ),
                style: TextStyle(
                  color: theme.primaryColor ?? const Color(0xFF1E90FF),
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              shadowColor: theme.weakDividerColor,
              backgroundColor: theme.appbarBgColor ?? Colors.white,
),
          body: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 20),
            child: SingleChildScrollView(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  renderGroupItem(GroupType.Work, theme, i18n),
                  renderGroupItem(GroupType.Public, theme, i18n),
                  renderGroupItem(GroupType.Meeting, theme, i18n),
                  renderGroupItem(GroupType.Community, theme, i18n),
                ],
              ),
            ),
          ),
        ));
  }
}
