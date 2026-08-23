import 'dart:convert';
import 'dart:async';
import 'dart:typed_data';
import 'package:tencent_cloud_chat_demo/src/i18n/app_i18n.dart';
import 'dart:io';
import 'package:tencent_cloud_chat_demo/src/platform/permission_guard.dart';

import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/scheduler.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:tencent_cloud_chat_demo/src/api/group_create_limit_api.dart';
import 'package:tencent_cloud_chat_demo/src/api/group_quota_limit_error.dart';
import 'package:tencent_cloud_chat_demo/src/api/me_group_api.dart';
import 'package:tencent_cloud_chat_demo/utils/dio_error_message.dart';
import 'package:tencent_cloud_chat_demo/src/api/me_friend_api.dart';
import 'package:tencent_cloud_chat_demo/src/api/upload_api.dart';
import 'package:tencent_cloud_chat_demo/src/models/me_group_record.dart';
import 'package:tencent_cloud_chat_demo/src/services/app_gallery_picker.dart';
import 'package:tencent_cloud_chat_sdk/enum/group_type.dart';
import 'package:tencent_cloud_chat_sdk/manager/v2_tim_manager.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_conversation.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_conversation.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_friend_info.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_friend_info.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_msg_create_info_result.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_msg_create_info_result.dart';
import 'package:tencent_cloud_chat_uikit/tencent_cloud_chat_uikit.dart';

import 'package:tencent_cloud_chat_demo/src/navigation/app_chat_route.dart';
import 'package:tencent_cloud_chat_demo/src/navigation/app_page_transitions.dart';
import 'package:tencent_cloud_chat_demo/src/provider/presence_provider.dart';
import 'package:tencent_cloud_chat_demo/src/provider/theme.dart';
import 'package:tencent_cloud_chat_demo/src/services/chat_external_message_sender.dart';
import 'package:tencent_cloud_chat_demo/src/ui/components/app_search_bar.dart';
import 'package:tencent_cloud_chat_demo/utils/friend_mutual_utils.dart';
import 'package:tencent_cloud_chat_demo/utils/chat_id_format.dart';
import 'package:tencent_cloud_chat_demo/utils/toast.dart';
import 'package:tencent_cloud_chat_demo/src/services/group_local/group_create_limit_refresh_bus.dart';
import 'package:tencent_cloud_chat_demo/src/services/group_local/group_create_service.dart';
import 'package:tencent_cloud_chat_demo/src/services/group_local/group_membership_sync_service.dart';
import 'package:tencent_cloud_chat_demo/src/services/group_local/group_change_event_sync_service.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_local/conversation_list_notifier.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_local/conversation_local_store.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_refresh_bus.dart';
import 'package:tencent_cloud_chat_demo/src/services/peer_profile_refresh_bus.dart';
import 'package:tencent_cloud_chat_demo/utils/group_create_limit_message.dart';
import 'package:tencent_cloud_chat_uikit/theme/tui_theme.dart';
import 'package:tencent_cloud_chat_uikit/ui/views/TIMUIKitSearch/conversation_search_utils.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/screen_utils.dart';
import 'package:tencent_cloud_chat_uikit/ui/widgets/avatar.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/view_models/tui_friendship_view_model.dart';
import 'package:tencent_cloud_chat_uikit/data_services/message/message_services.dart';
import 'package:tencent_cloud_chat_uikit/data_services/services_locatar.dart';
import 'package:tencent_cloud_chat_demo/src/utils/launch_system_ui.dart';
import 'package:tencent_cloud_chat_demo/src/utils/group_member_user_ids.dart';
import 'package:tencent_cloud_chat_demo/src/ui/utils/desktop_modal_layout.dart';

enum GroupTypeForUIKit { single, work, chat, meeting, public, community }

/// 普通群（Work / Public / Meeting）初始成员上限。
const int kStandardGroupMemberLimit = 2000;

/// 超级大群（Community）初始成员上限。
const int kSuperGroupMemberLimit = 100000;

GlobalKey<_CreateGroup> createGroupKey = GlobalKey();

class CreateGroup extends StatefulWidget {
  final GroupTypeForUIKit convType;
  final ValueChanged<V2TimConversation>? directToChat;

  /// 进入选人页时预勾选的好友 ID（如单聊设置页当前对方）。
  final List<String>? initialSelectedUserIds;

  /// 选完好友后进入通用群类型页 [CreateGroupIntroduction]，再进确认创建。
  final bool selectGroupTypeAfterMembers;

  /// Web / 桌面弹窗关闭（嵌入 WidePopup 且无外层标题时使用）。
  final VoidCallback? onDesktopClose;

  const CreateGroup({
    Key? key,
    required this.convType,
    this.directToChat,
    this.initialSelectedUserIds,
    this.selectGroupTypeAfterMembers = false,
    this.onDesktopClose,
  }) : super(key: key);

  @override
  State<StatefulWidget> createState() => _CreateGroup();
}

class _CreateGroup extends State<CreateGroup> {
  final V2TIMManager _sdkInstance = TIMUIKitCore.getSDKInstance();
  final MessageService _messageService = serviceLocator<MessageService>();
  final CoreServicesImpl _coreInstance = TIMUIKitCore.getInstance();
  final TUIFriendShipViewModel _friendshipViewModel =
      serviceLocator<TUIFriendShipViewModel>();
  final TextEditingController _searchController = TextEditingController();
  List<V2TimFriendInfo> friendList = [];
  List<V2TimFriendInfo> selectedFriendList = [];
  String _searchKeyword = "";
  Timer? _friendListRefreshTimer;
  int _friendListRequestGen = 0;
  bool _presenceLoadScheduled = false;
  bool _creatingGroup = false;
  int _contactListGeneration = 0;
  final GlobalKey<ContactListState> _contactListKey = GlobalKey();

  String _dioMsg(DioError e) => DioErrorMessage.forApp(e);

  void _safeSetState(VoidCallback fn) {
    if (!mounted) {
      return;
    }
    if (SchedulerBinding.instance.schedulerPhase == SchedulerPhase.idle) {
      setState(fn);
      return;
    }
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(fn);
      }
    });
  }

  void _schedulePresenceLoad(
      PresenceProvider presence, Iterable<String> userIds) {
    if (!mounted || _presenceLoadScheduled) {
      return;
    }
    final ids = userIds
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList(growable: false);
    if (ids.isEmpty) {
      return;
    }
    _presenceLoadScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _presenceLoadScheduled = false;
      if (!mounted) {
        return;
      }
      presence.ensure(ids);
    });
  }

  Future<void> _getConversationList() async {
    final requestGen = ++_friendListRequestGen;
    try {
      final list = await MeFriendApi.instance.loadFriendsForPickers();
      if (!mounted || requestGen != _friendListRequestGen) return;
      _safeSetState(() {
        friendList = list;
        final byId = {
          for (final friend in list)
            if (friend.userID.trim().isNotEmpty) friend.userID.trim(): friend,
        };
        if (selectedFriendList.isNotEmpty) {
          final order = selectedFriendList
              .map((friend) => friend.userID.trim())
              .where((id) => id.isNotEmpty)
              .toList();
          selectedFriendList = [
            for (final id in order)
              if (byId.containsKey(id)) byId[id]!,
          ];
        } else {
          final initials = widget.initialSelectedUserIds ?? const <String>[];
          if (initials.isNotEmpty) {
            selectedFriendList = [
              for (final raw in initials)
                if (byId[raw.trim()] != null) byId[raw.trim()]!,
            ];
            _contactListGeneration++;
          }
        }
      });
    } catch (_) {
      if (!mounted || requestGen != _friendListRequestGen) return;
      _safeSetState(() {
        friendList = [];
        selectedFriendList = [];
      });
    }
  }

  void _scheduleFriendListRefresh() {
    _friendListRefreshTimer?.cancel();
    _friendListRefreshTimer = Timer(const Duration(milliseconds: 120), () {
      unawaited(_getConversationList());
    });
  }

  _createSingleConversation() async {
    final userID = selectedFriendList.first.userID;
    final conversationID = "c2c_$userID";
    final res = await _sdkInstance
        .getConversationManager()
        .getConversation(conversationID: conversationID);
    if (!mounted) return;

    if (res.code == 0) {
      final V2TimConversation conversation = res.data ??
          V2TimConversation(
              conversationID: conversationID, userID: userID, type: 1);
      if (widget.directToChat != null) {
        widget.directToChat!(conversation);
      } else {
        Navigator.pushReplacement(context, appChatRoute(conversation));
      }
    }
  }

  _getShowName(V2TimFriendInfo item) {
    final friendRemark = item.friendRemark ?? "";
    final nickName = item.userProfile?.nickName ?? "";
    final userID = item.userID;
    final showName = nickName != "" ? nickName : userID;
    return friendRemark != "" ? friendRemark : showName;
  }

  List<V2TimFriendInfo> _getFilteredFriendList() {
    return filterFriendsByKeyword(friendList, _searchKeyword);
  }

  bool get _showsMemberSelectionLimit =>
      widget.selectGroupTypeAfterMembers ||
      (widget.convType != GroupTypeForUIKit.single &&
          widget.convType != GroupTypeForUIKit.chat);

  int get _memberSelectionMaxCount {
    if (widget.selectGroupTypeAfterMembers) {
      // 类型未定时按普通群上限；选 Community 后确认页不再扩选。
      return kStandardGroupMemberLimit;
    }
    if (widget.convType == GroupTypeForUIKit.community) {
      return kSuperGroupMemberLimit;
    }
    if (widget.convType == GroupTypeForUIKit.single) {
      return 1;
    }
    return kStandardGroupMemberLimit;
  }

  String get _memberSelectionCountLabel =>
      '${selectedFriendList.length}/$_memberSelectionMaxCount';

  Widget _buildMemberSelectionCountText(TUITheme theme) {
    return Text(
      _memberSelectionCountLabel,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: theme.weakTextColor ??
            theme.appbarTextColor?.withValues(alpha: 0.65) ??
            const Color(0xFF999999),
      ),
    );
  }

  Future<void> _openCreateGroupConfirmPage() async {
    final showSelector = widget.convType == GroupTypeForUIKit.community ||
        widget.convType == GroupTypeForUIKit.public;
    await _openCreateGroupConfirmPageForType(
      widget.convType,
      showGroupTypeSelector: showSelector,
    );
  }

  Future<void> _openCreateGroupConfirmPageForType(
    GroupTypeForUIKit uiType, {
    bool showGroupTypeSelector = false,
  }) async {
    final groupType = _sdkGroupTypeOf(uiType);
    if (groupType == null) {
      return;
    }
    final allowTypeSwitch = showGroupTypeSelector &&
        (uiType == GroupTypeForUIKit.community ||
            uiType == GroupTypeForUIKit.public);
    final confirmPage = _CreateGroupConfirmPage(
      members: selectedFriendList,
      showGroupTypeSelector: allowTypeSwitch,
      initialGroupType: allowTypeSwitch ? GroupType.Public : groupType,
      embeddedInDesktopPopup: DesktopModalLayout.isDesktop(context),
      onCreate: (draft) async {
        String? avatarFaceUrl = draft.faceUrl;
        final hasLocalAvatar = draft.localAvatarPath.isNotEmpty ||
            (draft.localAvatarBytes != null &&
                draft.localAvatarBytes!.isNotEmpty);
        if (hasLocalAvatar) {
          try {
            final GroupAvatarUploadResult uploadResult;
            if (draft.localAvatarBytes != null &&
                draft.localAvatarBytes!.isNotEmpty) {
              uploadResult =
                  await UploadApi.instance.uploadPendingGroupAvatarBytes(
                bytes: draft.localAvatarBytes!,
              );
            } else if (kIsWeb) {
              final bytes = await XFile(draft.localAvatarPath).readAsBytes();
              uploadResult = await UploadApi.instance
                  .uploadPendingGroupAvatarBytes(bytes: bytes);
            } else {
              uploadResult = await UploadApi.instance.uploadPendingGroupAvatar(
                file: File(draft.localAvatarPath),
              );
            }
            avatarFaceUrl = uploadResult.thumbUrl;
            debugPrint(
                "pending group avatar thumbUrl: ${uploadResult.thumbUrl}");
          } on DioError catch (e) {
            if (!mounted) return;
            ToastUtils.toast(_dioMsg(e));
            return;
          } catch (e) {
            debugPrint("upload pending group avatar failed: $e");
            if (!mounted) return;
            ToastUtils.toast(DioErrorMessage.forApp(e));
            return;
          }
        }
        await _createGroup(
          draft.groupType,
          customGroupName: draft.groupName,
          faceUrl: avatarFaceUrl,
          memberUserIds: draft.memberUserIds,
        );
      },
    );
    if (DesktopModalLayout.isDesktop(context)) {
      // 桌面选人已在 WidePopup 内：用同窗 Navigator 推进确认页，
      // 才能露出与移动端一致的「普通群 / 超级大群」切换；
      // 勿再开第二层 WidePopup（isShow 互斥会直接吞掉）。
      await Navigator.of(context).push(
        AppMaterialPageRoute(builder: (context) => confirmPage),
      );
    } else {
      await Navigator.push<_CreateGroupDraft>(
        context,
        AppMaterialPageRoute(builder: (context) => confirmPage),
      );
    }
  }

  String? _sdkGroupTypeOf(GroupTypeForUIKit uiType) {
    switch (uiType) {
      case GroupTypeForUIKit.community:
        return GroupType.Community;
      case GroupTypeForUIKit.meeting:
        return GroupType.Meeting;
      case GroupTypeForUIKit.work:
        return GroupType.Work;
      case GroupTypeForUIKit.public:
        return GroupType.Public;
      case GroupTypeForUIKit.single:
      case GroupTypeForUIKit.chat:
        return null;
    }
  }

  /// 选完好友后直接进「新建群聊」确认页（普通群 / 超级大群切换）。
  Future<void> _submitThenChooseGroupType() async {
    if (selectedFriendList.isEmpty) {
      return;
    }
    await _openCreateGroupConfirmPageForType(
      GroupTypeForUIKit.public,
      showGroupTypeSelector: true,
    );
  }

  bool _isCreateLimitGroupType(String groupType) {
    return groupType == GroupType.Work ||
        groupType == GroupType.Public ||
        groupType == GroupType.Community;
  }

  Future<bool> _ensureCanCreateGroupType(String groupType) async {
    if (!_isCreateLimitGroupType(groupType)) {
      return true;
    }
    try {
      final limits = await GroupCreateLimitApi.instance.fetch();
      if (!limits.canStartCreateAsOwner(groupType)) {
        if (!mounted) {
          return false;
        }
        ToastUtils.toastForce(
          GroupCreateLimitMessage.blockedForCreateOwner(
            groupType: groupType,
            limits: limits,
          ),
          context: context,
        );
        return false;
      }
      return true;
    } catch (e) {
      debugPrint('fetch group create limits failed: $e');
      return true;
    }
  }

  Future<void> _createGroup(
    String groupType, {
    String? customGroupName,
    String? faceUrl,
    List<String> memberUserIds = const <String>[],
  }) async {
    if (_creatingGroup || GroupCreateService.instance.isCreating) {
      return;
    }
    try {
      final trimmedGroupName = customGroupName?.trim() ?? "";
      if (trimmedGroupName.isEmpty) {
        if (!mounted) return;
        ToastUtils.toast(AppI18n.of(context).t(
          zhHans: '请输入群名称',
          zhHant: '請輸入群名稱',
          en: 'Enter group name',
          ja: 'グループ名を入力',
          ko: '그룹 이름 입력',
        ));
        return;
      }
      final String groupName = trimmedGroupName;
      if (!await _ensureCanCreateGroupType(groupType)) {
        return;
      }
      final memberIds = memberUserIds
          .map(ChatIdFormat.rawUserUid)
          .where((id) => id.isNotEmpty)
          .toList(growable: false);
      final flowGeneration = GroupCreateService.instance.beginCreateFlow();
      _creatingGroup = true;
      GroupCreateOutcome? outcome;
      Object? createError;
      DioError? dioError;
      try {
        outcome = await GroupCreateService.instance.createWithRecovery(
          GroupCreateParams(
            groupType: groupType,
            groupName: groupName,
            memberUserIds: memberIds,
            avatarUrl: faceUrl,
          ),
        );
      } on DioError catch (e) {
        createError = e;
        dioError = e;
      } catch (e) {
        createError = e;
      }

      if (outcome == null || outcome.record.groupId.trim().isEmpty) {
        outcome = await GroupCreateService.instance.recoverAfterFailure();
      }

      if (!mounted) return;
      if (!GroupCreateService.instance.isLatestCreateFlow(flowGeneration)) {
        return;
      }
      final record = outcome?.record;
      final isNewGroup = outcome?.isNewGroup ?? false;
      if (record != null && record.groupId.trim().isNotEmpty) {
        if (!isNewGroup) {
          ToastUtils.toast(AppI18n.of(context).t(
            zhHans: '创建失败，请稍后重试',
            zhHant: '建立失敗，請稍後重試',
            en: 'Create failed. Please try again later.',
            ja: '作成に失敗しました。しばらくしてから再試行してください。',
            ko: '생성 실패. 잠시 후 다시 시도해 주세요.',
          ));
          return;
        }
        if (dioError != null &&
            memberIds.isNotEmpty &&
            record.memberCount < 1 + memberIds.length) {
          ToastUtils.toast(AppI18n.of(context).t(
            zhHans: '群已创建，部分成员可能未加入，请在群资料中重新邀请',
            zhHant: '群已建立，部分成員可能未加入，請在群資料中重新邀請',
            en: 'Group created, but some members may not have joined. Re-invite from group profile.',
            ja: 'グループは作成されましたが、一部のメンバーが参加していない可能性があります。グループ情報から再招待してください。',
            ko: '그룹이 생성되었지만 일부 멤버가 참가하지 않았을 수 있습니다. 그룹 정보에서 다시 초대하세요.',
          ));
        }
        await _sendMessageToNewlyCreatedGroup(groupType, record.groupId.trim());
        if (!mounted) return;
        if (!GroupCreateService.instance.isLatestCreateFlow(flowGeneration)) {
          return;
        }
        await _finishCreatedGroup(
          flowGeneration: flowGeneration,
          record: record,
          groupType: groupType,
          groupName: groupName,
          faceUrl: faceUrl,
        );
        return;
      }

      if (dioError != null) {
        final code = MeGroupApi.readDioCode(dioError);
        final quotaError =
            GroupQuotaLimitError.tryParse(dioError.response?.data);
        final limitMessage = quotaError != null
            ? GroupCreateLimitMessage.fromQuotaError(
                quotaError,
                groupType: groupType,
              )
            : GroupCreateLimitMessage.fromApiCode(
                code: code,
                groupType: groupType,
              );
        if (limitMessage != null) {
          ToastUtils.toastForce(limitMessage, context: context);
        } else {
          ToastUtils.toast(
            DioErrorMessage.sanitizeUserText(
              code,
              fallback: AppI18n.of(context).t(
                zhHans: '创建失败，请稍后重试',
                zhHant: '建立失敗，請稍後重試',
                en: 'Create failed. Please try again later.',
                ja: '作成に失敗しました。しばらくしてから再試行してください。',
                ko: '생성 실패. 잠시 후 다시 시도해 주세요.',
              ),
            ),
          );
        }
        debugPrint('createGroup REST failed: code=$code');
        return;
      }
      if (createError != null) {
        debugPrint('createGroup REST exception: $createError');
        ToastUtils.toast(AppI18n.of(context).t(
          zhHans: '创建失败，请稍后重试',
          zhHant: '建立失敗，請稍後重試',
          en: 'Create failed. Please try again later.',
          ja: '作成に失敗しました。しばらくしてから再試行してください。',
          ko: '생성 실패. 잠시 후 다시 시도해 주세요.',
        ));
      }
    } catch (e) {
      debugPrint("createGroup exception: $e");
    } finally {
      _creatingGroup = false;
    }
  }

  Future<void> _finishCreatedGroup({
    required int flowGeneration,
    required MeGroupRecord record,
    required String groupType,
    required String groupName,
    String? faceUrl,
  }) async {
    _safeSetState(() {
      selectedFriendList = [];
      _contactListGeneration++;
    });
    await GroupMembershipSyncService.instance.upsertCreatedGroup(record);
    if (!mounted) return;
    final groupID = record.groupId.trim();
    if (groupID.isEmpty) {
      return;
    }
    final resolvedFaceUrl =
        record.avatarUrl.isNotEmpty ? record.avatarUrl : faceUrl;
    final conversationID = "group_$groupID";
    final convRes = await _sdkInstance
        .getConversationManager()
        .getConversation(conversationID: conversationID);
    if (!mounted) return;
    final conversation = (convRes.code == 0 && convRes.data != null)
        ? convRes.data!
        : V2TimConversation(
            conversationID: conversationID,
            type: 2,
            showName: groupName,
            groupType: groupType,
            groupID: groupID);
    // 建群 REST 返回的 groupId 为准；SDK getConversation 的 groupID 可能滞后，
    // 聊天页按 groupID 拉历史，不校正会标题是新群名、消息却是旧群。
    conversation.conversationID = conversationID;
    conversation.groupID = groupID;
    conversation.type = 2;
    conversation.groupType = groupType;
    conversation.showName = groupName;
    if (resolvedFaceUrl != null && resolvedFaceUrl.isNotEmpty) {
      conversation.faceUrl = resolvedFaceUrl;
    }

    conversation.unreadCount = 0;
    final orderKey = conversation.orderkey ?? 0;
    if (orderKey <= 0) {
      conversation.orderkey = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    }
    final merged = await ConversationLocalStore.instance.upsertBatch(
      conversations: [conversation],
    );
    await ConversationListNotifier.instance.applyConversationsFromStore(
      upserted: merged,
      // 新建群不一定满足“已加载窗口内热会话”的准入条件；创建成功后
      // 必须强制插入群聊列表，否则本地库已有记录但当前 UI 窗口仍看不到。
      forceAdmitIds: <String>{conversationID},
    );
    ConversationRefreshBus.instance.requestRefresh(
      reason: 'group_created',
      conversationId: conversationID,
    );

    if (!GroupCreateService.instance.isLatestCreateFlow(flowGeneration)) {
      return;
    }

    // 创建页键盘未收起就跳转时，聊天页会误读 viewInsets，输入栏悬空。
    FocusManager.instance.primaryFocus?.unfocus();

    if (widget.directToChat != null) {
      widget.directToChat!(conversation);
    } else {
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
      if (!GroupCreateService.instance.isLatestCreateFlow(flowGeneration)) {
        return;
      }
      Navigator.pushAndRemoveUntil(context, appChatRoute(conversation),
          ModalRoute.withName("/homePage"));
    }
  }

  Future<void> _sendMessageToNewlyCreatedGroup(
    String groupType,
    String groupID,
  ) async {
    final loginUserInfo = _coreInstance.loginUserInfo;
    V2TimMsgCreateInfoResult? res = await _messageService.createCustomMessage(
        data: json.encode({
      "businessID": "group_create",
      "version": 4,
      "opUser": loginUserInfo?.nickName ?? loginUserInfo!.userID,
      "content": groupType == GroupType.Community
          ? AppI18n.of(context).t(
              zhHans: '创建社群',
              zhHant: '建立社群',
              en: 'Created community',
              ja: 'コミュニティを作成',
              ko: '커뮤니티 생성',
            )
          : AppI18n.of(context).t(
              zhHans: '创建群组',
              zhHant: '建立群組',
              en: 'Created group',
              ja: 'グループを作成',
              ko: '그룹 생성',
            ),
      "cmd": groupType == GroupType.Community ? 1 : 0
    }));
    if (res != null) {
      final sent = await ChatExternalMessageSender.sendCreatedMessage(
        messageInfo: res.messageInfo,
        receiverUserId: '',
        groupId: groupID,
        reason: 'group_create_message_sent',
        isExcludedFromUnreadCount: true,
      );
      if (sent) {
        unawaited(
          GroupChangeEventSyncService.instance.syncForGroup(
            groupID,
            reason: 'group_create',
          ),
        );
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _friendshipViewModel.addListener(_onFriendListChanged);
    PeerProfileRefreshBus.instance.revision.addListener(_onPeerProfileRefresh);
    _getConversationList();
  }

  void _onFriendListChanged() {
    _scheduleFriendListRefresh();
  }

  void _onPeerProfileRefresh() {
    _scheduleFriendListRefresh();
  }

  @override
  void dispose() {
    _friendListRequestGen++;
    _friendListRefreshTimer?.cancel();
    _friendshipViewModel.removeListener(_onFriendListChanged);
    PeerProfileRefreshBus.instance.revision
        .removeListener(_onPeerProfileRefresh);
    _searchController.dispose();
    super.dispose();
  }

  void onSubmit() {
    if (widget.selectGroupTypeAfterMembers) {
      unawaited(_submitThenChooseGroupType());
      return;
    }
    final isCommunity = widget.convType == GroupTypeForUIKit.community;
    if (!isCommunity && selectedFriendList.isEmpty) return;
    switch (widget.convType) {
      case GroupTypeForUIKit.single:
        _createSingleConversation();
        break;
      case GroupTypeForUIKit.chat:
        break;
      case GroupTypeForUIKit.community:
        _openCreateGroupConfirmPage();
        break;
      case GroupTypeForUIKit.meeting:
        _openCreateGroupConfirmPage();
        break;
      case GroupTypeForUIKit.work:
        _openCreateGroupConfirmPage();
        break;
      case GroupTypeForUIKit.public:
        _openCreateGroupConfirmPage();
        break;
    }
  }

  Widget _buildDesktopPopupHeader(TUITheme theme) {
    final i18n = AppI18n.of(context);
    final titleColor = theme.darkTextColor ?? const Color(0xFF111827);
    final weak = theme.weakTextColor ?? const Color(0xFF9CA3AF);
    final divider = theme.weakDividerColor ?? const Color(0xFFE8EAED);
    return Container(
      height: 56,
      padding: const EdgeInsets.fromLTRB(20, 0, 8, 0),
      decoration: BoxDecoration(
        color: theme.wideBackgroundColor ?? Colors.white,
        border: Border(
          bottom: BorderSide(color: divider.withValues(alpha: 0.85)),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              i18n.t(
                zhHans: '创建群聊',
                zhHant: '建立群聊',
                en: 'Create Group',
                ja: 'グループを作成',
                ko: '그룹 만들기',
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: titleColor,
              ),
            ),
          ),
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: widget.onDesktopClose,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Icon(Icons.close_rounded, size: 22, color: weak),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopSearchBar(TUITheme theme) {
    final fillColor = theme.inputFillColor ?? const Color(0xFFF3F4F6);
    final iconColor = theme.weakTextColor ?? const Color(0xFF9CA3AF);
    final textColor = theme.darkTextColor ?? const Color(0xFF111827);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
      child: Container(
        height: 44,
        decoration: BoxDecoration(
          color: fillColor,
          borderRadius: BorderRadius.circular(22),
        ),
        child: TextField(
          controller: _searchController,
          style: TextStyle(fontSize: 14, color: textColor, height: 1.2),
          decoration: InputDecoration(
            isDense: true,
            hintText: AppI18n.of(context).t(
              zhHans: '搜索',
              zhHant: '搜尋',
              en: 'Search',
              ja: '検索',
              ko: '검색',
            ),
            hintStyle: TextStyle(color: iconColor, fontSize: 14),
            prefixIcon: Icon(Icons.search_rounded, size: 20, color: iconColor),
            prefixIconConstraints:
                const BoxConstraints(minWidth: 44, minHeight: 44),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 12),
          ),
          onChanged: (value) {
            _safeSetState(() {
              _searchKeyword = value.trim();
            });
          },
        ),
      ),
    );
  }

  Widget _buildDesktopSelectedPanel(TUITheme theme) {
    final dividerColor = theme.weakDividerColor ?? const Color(0xFFE8EAED);
    final weakText = theme.weakTextColor ?? const Color(0xFF9CA3AF);
    final titleColor = theme.darkTextColor ?? const Color(0xFF111827);

    return Container(
      width: 260,
      decoration: BoxDecoration(
        color: theme.selectPanelBgColor ??
            theme.inputFillColor?.withValues(alpha: 0.35) ??
            const Color(0xFFF9FAFB),
        border: Border(
          left: BorderSide(color: dividerColor.withValues(alpha: 0.85)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                Text(
                  AppI18n.of(context).t(
                    zhHans: '已选成员',
                    zhHant: '已選成員',
                    en: 'Selected',
                    ja: '選択済み',
                    ko: '선택됨',
                  ),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: titleColor,
                  ),
                ),
                const Spacer(),
                if (_showsMemberSelectionLimit)
                  Text(
                    _memberSelectionCountLabel,
                    style: TextStyle(fontSize: 12, color: weakText),
                  ),
              ],
            ),
          ),
          Expanded(
            child: selectedFriendList.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Text(
                        AppI18n.of(context).t(
                          zhHans: '从左侧列表选择成员',
                          zhHant: '從左側列表選擇成員',
                          en: 'Select members from the list',
                          ja: '左のリストから選択',
                          ko: '왼쪽 목록에서 선택',
                        ),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          color: weakText,
                          height: 1.4,
                        ),
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
                    itemCount: selectedFriendList.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 2),
                    itemBuilder: (context, index) {
                      final friend = selectedFriendList[index];
                      final showName = _getShowName(friend);
                      final faceUrl = friend.userProfile?.faceUrl ?? '';
                      return Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(10),
                          onTap: () {
                            _contactListKey.currentState
                                ?.deselectByUserId(friend.userID);
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 6,
                            ),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 32,
                                  height: 32,
                                  child: Avatar(
                                    faceUrl: faceUrl,
                                    showName: showName,
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    showName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      color: titleColor,
                                    ),
                                  ),
                                ),
                                Icon(
                                  Icons.close_rounded,
                                  size: 16,
                                  color: weakText,
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: SizedBox(
              width: double.infinity,
              height: 40,
              child: FilledButton(
                onPressed: () {
                  final isCommunity =
                      widget.convType == GroupTypeForUIKit.community;
                  if (!isCommunity &&
                      !widget.selectGroupTypeAfterMembers &&
                      selectedFriendList.isEmpty) {
                    return;
                  }
                  onSubmit();
                },
                style: FilledButton.styleFrom(
                  backgroundColor:
                      theme.primaryColor ?? const Color(0xFF1E90FF),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: Text(
                  widget.convType == GroupTypeForUIKit.single
                      ? AppI18n.of(context).t(
                          zhHans: '确定',
                          zhHant: '確定',
                          en: 'OK',
                          ja: 'OK',
                          ko: '확인',
                        )
                      : AppI18n.of(context).t(
                          zhHans: '下一步',
                          zhHant: '下一步',
                          en: 'Next',
                          ja: '次へ',
                          ko: '다음',
                        ),
                  style: const TextStyle(
                    fontSize: 14,
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

  Widget _buildContactList({
    required TUITheme theme,
    required bool isDarkBackground,
    required bool isWideScreen,
    required List<V2TimFriendInfo> filteredFriendList,
    required PresenceProvider presence,
    required TUIFriendShipViewModel friendship,
  }) {
    return ContactList(
      key: isWideScreen ? _contactListKey : ValueKey(_contactListGeneration),
      bgColor: isDarkBackground
          ? (isWideScreen
              ? theme.wideBackgroundColor
              : theme.weakBackgroundColor)
          : Colors.white,
      contactList: filteredFriendList,
      selectionContactList: friendList,
      isCanSelectMemberItem: true,
      maxSelectNum: _memberSelectionMaxCount,
      initialSelectedUserIds: selectedFriendList
          .map((friend) => friend.userID.trim())
          .where((id) => id.isNotEmpty)
          .toList(growable: false),
      isShowOnlineStatus: true,
      presenceListenable: presence,
      presenceLabelBuilder: (userId, imOnline) => presence.listLabelFor(
        userId: userId,
        imOnline: imOnline,
        isMutualFriend: friendCanMessage(friendship, userId),
      ),
      presenceLoadingChecker: (userId, imOnline) =>
          presence.isLastSeenLoading(userId: userId, imOnline: imOnline),
      onContactListLoaded: (userIds) {
        _schedulePresenceLoad(presence, userIds);
      },
      onSelectedMemberItemChange: (selectedMember) {
        _safeSetState(() {
          selectedFriendList = selectedMember;
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<DefaultThemeData>(context).theme;
    final appBarBaseColor =
        theme.appbarBgColor ?? theme.wideBackgroundColor ?? Colors.white;
    final isDarkBackground =
        ThemeData.estimateBrightnessForColor(appBarBaseColor) ==
            Brightness.dark;
    final isWideScreen =
        TUIKitScreenUtils.getFormFactor(context) == DeviceType.Desktop;
    final filteredFriendList = _getFilteredFriendList();
    final presence = Provider.of<PresenceProvider>(context, listen: false);
    final friendship = serviceLocator<TUIFriendShipViewModel>();

    Widget buildSearchBar() {
      return buildAppSearchBarInset(
        context: context,
        controller: _searchController,
        hint: AppI18n.of(context).t(
          zhHans: '搜索',
          zhHant: '搜尋',
          en: 'Search',
          ja: '検索',
          ko: '검색',
        ),
        onChanged: (value) {
          _safeSetState(() {
            _searchKeyword = value;
          });
        },
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
      );
    }

    Widget chooseMembers() {
      return Column(
        children: [
          if (isWideScreen) _buildDesktopSearchBar(theme) else buildSearchBar(),
          Expanded(
            child: _buildContactList(
              theme: theme,
              isDarkBackground: isDarkBackground,
              isWideScreen: isWideScreen,
              filteredFriendList: filteredFriendList,
              presence: presence,
              friendship: friendship,
            ),
          ),
        ],
      );
    }

    return TUIKitScreenUtils.getDeviceWidget(
        context: context,
        desktopWidget: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.onDesktopClose != null) _buildDesktopPopupHeader(theme),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: chooseMembers()),
                  _buildDesktopSelectedPanel(theme),
                ],
              ),
            ),
          ],
        ),
        defaultWidget: Scaffold(
          appBar: AppBar(
              centerTitle: true,
              title: _showsMemberSelectionLimit
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          AppI18n.of(context).t(
                            zhHans: '选择联系人',
                            zhHant: '選擇聯絡人',
                            en: 'Select Contacts',
                            ja: '連絡先を選択',
                            ko: '연락처 선택',
                          ),
                          style: TextStyle(
                            color: theme.appbarTextColor ??
                                theme.darkTextColor ??
                                Colors.black,
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        _buildMemberSelectionCountText(theme),
                      ],
                    )
                  : Text(
                      AppI18n.of(context).t(
                        zhHans: '选择联系人',
                        zhHant: '選擇聯絡人',
                        en: 'Select Contacts',
                        ja: '連絡先を選択',
                        ko: '연락처 선택',
                      ),
                      style: TextStyle(
                        color: theme.appbarTextColor ??
                            theme.darkTextColor ??
                            Colors.black,
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
              shadowColor: theme.weakDividerColor,
              backgroundColor: theme.appbarBgColor ??
                  theme.weakBackgroundColor ??
                  Colors.white,
              surfaceTintColor: Colors.transparent,
              actions: [
                TextButton(
                  onPressed: onSubmit,
                  child: Text(
                    widget.convType == GroupTypeForUIKit.single
                        ? AppI18n.of(context).t(
                            zhHans: '确定',
                            zhHant: '確定',
                            en: 'OK',
                            ja: 'OK',
                            ko: '확인',
                          )
                        : AppI18n.of(context).t(
                            zhHans: '下一步',
                            zhHant: '下一步',
                            en: 'Next',
                            ja: '次へ',
                            ko: '다음',
                          ),
                    style: TextStyle(
                      color: theme.appbarTextColor ??
                          theme.darkTextColor ??
                          Colors.black,
                      fontSize: 16,
                    ),
                  ),
                )
              ],
              iconTheme: IconThemeData(
                color: theme.primaryColor ?? const Color(0xFF1E90FF),
              )),
          body: chooseMembers(),
        ));
  }
}

class _CreateGroupDraft {
  final String groupName;
  final String faceUrl;
  final String localAvatarPath;
  final Uint8List? localAvatarBytes;
  final String groupType;
  final List<String> memberUserIds;

  const _CreateGroupDraft({
    required this.groupName,
    required this.faceUrl,
    required this.localAvatarPath,
    this.localAvatarBytes,
    required this.groupType,
    required this.memberUserIds,
  });
}

class _CreateGroupConfirmPage extends StatefulWidget {
  final List<V2TimFriendInfo> members;
  final bool showGroupTypeSelector;
  final String initialGroupType;
  final Future<void> Function(_CreateGroupDraft draft) onCreate;

  /// Web 弹窗内嵌：单层顶栏，避免与外层弹窗标题叠成双头。
  final bool embeddedInDesktopPopup;

  const _CreateGroupConfirmPage({
    required this.members,
    required this.showGroupTypeSelector,
    required this.initialGroupType,
    required this.onCreate,
    this.embeddedInDesktopPopup = false,
  });

  @override
  State<_CreateGroupConfirmPage> createState() =>
      _CreateGroupConfirmPageState();
}

class _CreateGroupConfirmPageState extends State<_CreateGroupConfirmPage> {
  late final TextEditingController _nameController;
  late final FocusNode _nameFocusNode;
  late String _selectedGroupType;
  String _selectedAvatarUrl = "";
  String _selectedLocalAvatarPath = "";
  Uint8List? _selectedLocalAvatarBytes;

  bool _submitting = false;
  bool _nameFocused = false;
  GroupCreateLimitsResponse? _createLimits;

  bool get _isCommunitySelected => _selectedGroupType == GroupType.Community;

  bool _shouldTrackCreateLimits() {
    return widget.showGroupTypeSelector ||
        _selectedGroupType == GroupType.Work ||
        _selectedGroupType == GroupType.Public ||
        _selectedGroupType == GroupType.Community;
  }

  GroupTypeCreateLimitInfo? _selectedTypeLimitInfo() {
    return _createLimits?.infoForGroupType(_selectedGroupType);
  }

  GroupTypeCreateLimitInfo? _selectedJoinLimitInfo() {
    return _createLimits?.joinInfoForGroupType(_selectedGroupType);
  }

  bool _canCreateSelectedType() {
    return _createLimits?.canStartCreateAsOwner(_selectedGroupType) ?? true;
  }

  @override
  void initState() {
    super.initState();
    _selectedGroupType = widget.initialGroupType;
    _nameController = TextEditingController();
    _nameFocusNode = FocusNode()..addListener(_onNameFocusChanged);
    _nameController.addListener(_onNameTextChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _applyImmersiveSystemUi();
      if (_shouldTrackCreateLimits()) {
        _loadCreateLimits();
      }
    });
    GroupCreateLimitRefreshBus.instance.revision
        .addListener(_onCreateLimitsRefresh);
  }

  void _onCreateLimitsRefresh() {
    if (!_shouldTrackCreateLimits()) {
      return;
    }
    unawaited(_loadCreateLimits());
  }

  Future<void> _loadCreateLimits() async {
    try {
      final limits = await GroupCreateLimitApi.instance.fetch();
      if (!mounted) {
        return;
      }
      setState(() => _createLimits = limits);
    } catch (e) {
      debugPrint('load group create limits failed: $e');
    }
  }

  @override
  void dispose() {
    GroupCreateLimitRefreshBus.instance.revision
        .removeListener(_onCreateLimitsRefresh);
    LaunchSystemUi.restoreFromContext(context);
    _nameController.removeListener(_onNameTextChanged);
    _nameFocusNode.removeListener(_onNameFocusChanged);
    _nameFocusNode.dispose();
    _nameController.dispose();
    super.dispose();
  }

  void _applyImmersiveSystemUi() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }

  SystemUiOverlayStyle _buildPageOverlayStyle({
    required bool isDarkBackground,
    required Color pageBackgroundColor,
  }) {
    final navigationBarIsDark =
        ThemeData.estimateBrightnessForColor(pageBackgroundColor) ==
            Brightness.dark;
    return SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: pageBackgroundColor,
      statusBarIconBrightness:
          isDarkBackground ? Brightness.light : Brightness.dark,
      statusBarBrightness:
          isDarkBackground ? Brightness.dark : Brightness.light,
      systemNavigationBarIconBrightness:
          navigationBarIsDark ? Brightness.light : Brightness.dark,
      systemNavigationBarDividerColor: Colors.transparent,
    );
  }

  void _onNameFocusChanged() {
    final focused = _nameFocusNode.hasFocus;
    if (focused != _nameFocused && mounted) {
      setState(() => _nameFocused = focused);
    }
  }

  void _onNameTextChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  void _clearGroupName() {
    _nameController.clear();
    _nameFocusNode.requestFocus();
  }

  String _getShowName(V2TimFriendInfo item) {
    final friendRemark = item.friendRemark ?? "";
    final nickName = item.userProfile?.nickName ?? "";
    final userID = item.userID;
    final showName = nickName.isNotEmpty ? nickName : userID;
    return friendRemark.isNotEmpty ? friendRemark : showName;
  }

  Future<void> _pickAvatarFromGallery() async {
    final file = await AppGalleryPicker.pickSingleImage(context);
    final picked = file == null ? null : XFile(file.path);
    if (picked == null || !mounted) {
      return;
    }
    await _applyPickedAvatarFile(picked);
  }

  Future<void> _pickAvatarFromCamera() async {
    final allowed = await PermissionGuard.cameraForPhoto(context);
    if (!allowed || !mounted) {
      return;
    }
    final picker = ImagePicker();
    final XFile? picked = await picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 90,
    );
    if (picked == null || !mounted) {
      return;
    }
    await _applyPickedAvatarFile(picked);
  }

  /// Web / 桌面：跳过手机 ActionSheet，直接打开系统文件选择。
  Future<void> _pickAvatarFromDesktopOrWeb() async {
    final picker = ImagePicker();
    final XFile? picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 90,
      maxWidth: 1920,
      maxHeight: 1920,
      requestFullMetadata: false,
    );
    if (picked == null || !mounted) {
      return;
    }
    await _applyPickedAvatarFile(picked);
  }

  Future<void> _applyPickedAvatarFile(XFile picked) async {
    final path = picked.path;
    Uint8List? bytes;
    if (kIsWeb || path.isEmpty) {
      bytes = await picked.readAsBytes();
      if (bytes.isEmpty) {
        return;
      }
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _selectedLocalAvatarPath = path;
      _selectedLocalAvatarBytes = bytes;
      _selectedAvatarUrl = "";
    });
  }

  Future<void> _onTapGroupAvatar(TUITheme theme) async {
    // Web / 宽屏：不要套 iOS ActionSheet（拍照 / 从手机相册）。
    if (kIsWeb || DesktopModalLayout.isDesktop(context)) {
      await _pickAvatarFromDesktopOrWeb();
      return;
    }
    final result = await showCupertinoModalPopup<String>(
      context: context,
      builder: (BuildContext context) {
        return CupertinoActionSheet(
          cancelButton: CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(context, "cancel");
            },
            child: Text(AppI18n.of(context).t(
              zhHans: '取消',
              zhHant: '取消',
              en: 'Cancel',
              ja: 'キャンセル',
              ko: '취소',
            )),
          ),
          actions: [
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.pop(context, "camera");
              },
              child: Text(
                AppI18n.of(context).t(
                  zhHans: '拍照',
                  zhHant: '拍照',
                  en: 'Take Photo',
                  ja: '写真を撮る',
                  ko: '사진 촬영',
                ),
                style: TextStyle(color: theme.primaryColor),
              ),
            ),
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.pop(context, "gallery");
              },
              child: Text(
                AppI18n.of(context).t(
                  zhHans: '从手机相册选择',
                  zhHant: '從手機相簿選擇',
                  en: 'Choose from Gallery',
                  ja: 'ギャラリーから選択',
                  ko: '갤러리에서 선택',
                ),
                style: TextStyle(color: theme.primaryColor),
              ),
            ),
          ],
        );
      },
    );
    if (result == "camera") {
      await _pickAvatarFromCamera();
    } else if (result == "gallery") {
      await _pickAvatarFromGallery();
    }
  }

  Widget _buildLocalAvatarImage() {
    if (_selectedLocalAvatarBytes != null &&
        _selectedLocalAvatarBytes!.isNotEmpty) {
      return Image.memory(
        _selectedLocalAvatarBytes!,
        fit: BoxFit.cover,
      );
    }
    final path = _selectedLocalAvatarPath;
    if (path.isEmpty) {
      return const SizedBox.shrink();
    }
    if (kIsWeb ||
        path.startsWith('blob:') ||
        path.startsWith('http://') ||
        path.startsWith('https://')) {
      return Image.network(path, fit: BoxFit.cover);
    }
    return Image.file(File(path), fit: BoxFit.cover);
  }

  Widget _buildGroupAvatar(TUITheme theme) {
    return InkWell(
      onTap: () => _onTapGroupAvatar(theme),
      child: Row(
        children: [
          Text(
            AppI18n.of(context).t(
              zhHans: '群头像',
              zhHant: '群頭像',
              en: 'Group Avatar',
              ja: 'グループアイコン',
              ko: '그룹 프로필',
            ),
            style: TextStyle(
              fontSize: 16,
              color: theme.darkTextColor ?? Colors.black,
            ),
          ),
          const Spacer(),
          SizedBox(
            width: 52,
            height: 52,
            child: (_selectedLocalAvatarPath.isNotEmpty ||
                    (_selectedLocalAvatarBytes?.isNotEmpty ?? false))
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(26),
                    child: _buildLocalAvatarImage(),
                  )
                : Avatar(
                    faceUrl: _selectedAvatarUrl,
                    showName: _nameController.text.trim(),
                    type: 2,
                    borderRadius: BorderRadius.circular(26),
                    isFromLocalAsset: _selectedAvatarUrl.startsWith("assets/"),
                  ),
          ),
          const SizedBox(width: 8),
          Icon(
            Icons.keyboard_arrow_right,
            color: theme.weakTextColor,
            size: 20,
          ),
        ],
      ),
    );
  }

  Widget _buildGroupNameInput(TUITheme theme) {
    final fillColor = theme.inputFillColor ??
        theme.selectPanelBgColor ??
        const Color(0xFFF1F2F6);
    final hintColor = theme.weakTextColor ?? const Color(0xFF999999);
    final hintText = _isCommunitySelected
        ? AppI18n.of(context).t(
            zhHans: '请输入群聊名称',
            zhHant: '請輸入群聊名稱',
            en: 'Enter group chat name',
            ja: 'グループチャット名を入力',
            ko: '그룹 채팅 이름 입력',
          )
        : AppI18n.of(context).t(
            zhHans: '请输入群名称',
            zhHant: '請輸入群名稱',
            en: 'Enter group name',
            ja: 'グループ名を入力',
            ko: '그룹 이름 입력',
          );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          AppI18n.of(context).t(
            zhHans: '群名称',
            zhHant: '群名稱',
            en: 'Group Name',
            ja: 'グループ名',
            ko: '그룹 이름',
          ),
          style: TextStyle(
            fontSize: 16,
            color: theme.darkTextColor ?? Colors.black,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: fillColor,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _nameController,
                  focusNode: _nameFocusNode,
                  maxLength: 20,
                  decoration: InputDecoration(
                    counterText: "",
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 14,
                    ),
                    hintText: hintText,
                    hintStyle: TextStyle(
                      color: hintColor,
                      fontSize: 15,
                    ),
                  ),
                  style: TextStyle(
                    fontSize: 15,
                    color: theme.darkTextColor ?? Colors.black,
                  ),
                ),
              ),
              if (_nameFocused)
                GestureDetector(
                  onTap: _clearGroupName,
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: Icon(
                      Icons.cancel,
                      size: 18,
                      color: hintColor,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildGroupTypeOption({
    required TUITheme theme,
    required String value,
    required String label,
    String? subtitle,
  }) {
    final selected = _selectedGroupType == value;
    final primary = theme.primaryColor ?? const Color(0xFF1E90FF);
    final fillColor = theme.inputFillColor ??
        theme.selectPanelBgColor ??
        const Color(0xFFF1F2F6);
    return Expanded(
      child: InkWell(
        onTap: () {
          if (_selectedGroupType == value) {
            return;
          }
          setState(() => _selectedGroupType = value);
        },
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          decoration: BoxDecoration(
            color: selected ? primary.withValues(alpha: 0.12) : fillColor,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected ? primary : Colors.transparent,
              width: 1.5,
            ),
          ),
          alignment: Alignment.center,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  color: selected
                      ? primary
                      : (theme.darkTextColor ?? Colors.black),
                ),
              ),
              if (subtitle != null && subtitle.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.2,
                    color: selected
                        ? primary.withValues(alpha: 0.85)
                        : (theme.weakTextColor ?? const Color(0xFF999999)),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSelectedGroupTypeDescription(TUITheme theme) {
    final limitsEnabled = _createLimits?.enabled ?? false;
    final info = _selectedTypeLimitInfo();
    final joinInfo = _selectedJoinLimitInfo();
    final description = GroupCreateLimitMessage.selectedTypeDescription(
      groupType: _selectedGroupType,
      limitsEnabled: limitsEnabled,
      info: info,
      joinInfo: joinInfo,
    );
    final createBlocked =
        limitsEnabled && info != null && info.max > 0 && info.remaining <= 0;
    final joinBlocked = limitsEnabled &&
        joinInfo != null &&
        joinInfo.max > 0 &&
        joinInfo.remaining <= 0;
    final isBlocked = createBlocked || joinBlocked;
    final fillColor = theme.inputFillColor ??
        theme.selectPanelBgColor ??
        const Color(0xFFF7F8FA);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: fillColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        description,
        style: TextStyle(
          fontSize: 13,
          height: 1.45,
          color: isBlocked
              ? (theme.cautionColor ?? const Color(0xFFE54545))
              : (theme.weakTextColor ?? const Color(0xFF666666)),
        ),
      ),
    );
  }

  Widget _buildCreateGroupDeclaration(TUITheme theme) {
    return Text(
      GroupCreateLimitMessage.createGroupDeclaration(),
      style: TextStyle(
        fontSize: 12,
        height: 1.45,
        color: theme.weakTextColor ?? const Color(0xFF999999),
      ),
    );
  }

  Widget _buildGroupTypeSelector(TUITheme theme) {
    final i18n = AppI18n.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          i18n.t(
            zhHans: '群类型',
            zhHant: '群類型',
            en: 'Group Type',
            ja: 'グループタイプ',
            ko: '그룹 유형',
          ),
          style: TextStyle(
            fontSize: 16,
            color: theme.darkTextColor ?? Colors.black,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _buildGroupTypeOption(
              theme: theme,
              value: GroupType.Public,
              label: i18n.t(
                zhHans: '普通群',
                zhHant: '普通群',
                en: 'Standard Group',
                ja: '通常グループ',
                ko: '일반 그룹',
              ),
              subtitle: GroupCreateLimitMessage.memberCapacityShortHint(
                GroupType.Public,
              ),
            ),
            const SizedBox(width: 12),
            _buildGroupTypeOption(
              theme: theme,
              value: GroupType.Community,
              label: i18n.t(
                zhHans: '超级大群',
                zhHant: '超級大群',
                en: 'Super Group',
                ja: 'スーパーグループ',
                ko: '슈퍼 그룹',
              ),
              subtitle: GroupCreateLimitMessage.memberCapacityShortHint(
                GroupType.Community,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        _buildSelectedGroupTypeDescription(theme),
      ],
    );
  }

  Widget _buildCreateLimitHint(TUITheme theme) {
    return _buildSelectedGroupTypeDescription(theme);
  }

  Widget _buildMemberItem(V2TimFriendInfo item, TUITheme theme) {
    final showName = _getShowName(item);
    return SizedBox(
      width: 60,
      child: Column(
        children: [
          SizedBox(
            width: 44,
            height: 44,
            child: Avatar(
              faceUrl: item.userProfile?.faceUrl ?? "",
              showName: showName,
              type: 1,
              borderRadius: BorderRadius.circular(22),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            showName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: theme.weakTextColor,
            ),
          ),
        ],
      ),
    );
  }

  void _showQuotaBlockedNotice(BuildContext context) {
    final limits = _createLimits;
    ToastUtils.toastForce(
      limits == null
          ? GroupCreateLimitMessage.blockedJoinMessage(_selectedGroupType)
          : GroupCreateLimitMessage.blockedForCreateOwner(
              groupType: _selectedGroupType,
              limits: limits,
            ),
      context: context,
    );
  }

  Future<void> _handleCreatePressed(BuildContext pageContext) async {
    if (_submitting) {
      return;
    }
    FocusManager.instance.primaryFocus?.unfocus();
    final groupName = _nameController.text.trim();
    if (groupName.isEmpty) {
      ToastUtils.toastForce(
        _isCommunitySelected
            ? AppI18n.of(pageContext).t(
                zhHans: '请输入群聊名称',
                zhHant: '請輸入群聊名稱',
                en: 'Enter group chat name',
                ja: 'グループチャット名を入力',
                ko: '그룹 채팅 이름 입력',
              )
            : AppI18n.of(pageContext).t(
                zhHans: '请输入群名称',
                zhHant: '請輸入群名稱',
                en: 'Enter group name',
                ja: 'グループ名を入力',
                ko: '그룹 이름 입력',
              ),
        context: pageContext,
      );
      return;
    }
    if (!_canCreateSelectedType()) {
      _showQuotaBlockedNotice(pageContext);
      return;
    }
    setState(() => _submitting = true);
    try {
      await widget.onCreate(
        _CreateGroupDraft(
          groupName: groupName,
          faceUrl: _selectedAvatarUrl,
          localAvatarPath: _selectedLocalAvatarPath,
          localAvatarBytes: _selectedLocalAvatarBytes,
          groupType: _selectedGroupType,
          memberUserIds: normalizeMemberUserIds(widget.members),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  String _pageTitle(AppI18n i18n) {
    return _isCommunitySelected
        ? i18n.t(
            zhHans: '新建社群',
            zhHant: '新建社群',
            en: 'New Community',
            ja: 'コミュニティを作成',
            ko: '커뮤니티 만들기',
          )
        : i18n.t(
            zhHans: '新建群聊',
            zhHant: '新建群聊',
            en: 'New Group',
            ja: 'グループを作成',
            ko: '그룹 만들기',
          );
  }

  Widget _buildFormBody({
    required AppI18n i18n,
    required TUITheme theme,
    required Color cardBackgroundColor,
    required Color pageBackgroundColor,
    required Color dividerColor,
    EdgeInsetsGeometry cardPadding = const EdgeInsets.fromLTRB(16, 18, 16, 18),
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          color: cardBackgroundColor,
          padding: cardPadding,
          child: Column(
            children: [
              _buildGroupAvatar(theme),
              Divider(
                height: 28,
                thickness: 1,
                color: dividerColor,
              ),
              _buildGroupNameInput(theme),
              if (!widget.showGroupTypeSelector) ...[
                const SizedBox(height: 12),
                _buildCreateLimitHint(theme),
              ],
              if (widget.showGroupTypeSelector) ...[
                Divider(
                  height: 28,
                  thickness: 1,
                  color: dividerColor,
                ),
                _buildGroupTypeSelector(theme),
              ],
            ],
          ),
        ),
        Container(
          height: 14,
          color: pageBackgroundColor,
        ),
        Container(
          color: cardBackgroundColor,
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                i18n.format(
                  zhHans: '群成员({option1})',
                  zhHant: '群成員({option1})',
                  en: 'Members ({option1})',
                  ja: 'メンバー({option1})',
                  ko: '멤버({option1})',
                  vars: {'option1': '${widget.members.length}'},
                ),
                style: TextStyle(
                  fontSize: 16,
                  color: theme.darkTextColor ?? Colors.black,
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 16,
                runSpacing: 14,
                children: widget.members
                    .map((item) => _buildMemberItem(item, theme))
                    .toList(),
              ),
              const SizedBox(height: 16),
              _buildCreateGroupDeclaration(theme),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDesktopConfirmChrome({
    required AppI18n i18n,
    required TUITheme theme,
    required Color pageBackgroundColor,
    required Color cardBackgroundColor,
    required Color dividerColor,
  }) {
    final titleColor = theme.darkTextColor ?? const Color(0xFF111827);
    final primary = theme.primaryColor ?? const Color(0xFF1E90FF);
    final weak = theme.weakTextColor ?? const Color(0xFF9CA3AF);

    Widget sectionCard({required Widget child}) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
        decoration: BoxDecoration(
          color: cardBackgroundColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: dividerColor.withValues(alpha: 0.7)),
        ),
        child: child,
      );
    }

    final leftPane = AbsorbPointer(
      absorbing: _submitting,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 12, 20),
        children: [
          sectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildGroupAvatar(theme),
                Divider(height: 28, thickness: 1, color: dividerColor),
                _buildGroupNameInput(theme),
                if (!widget.showGroupTypeSelector) ...[
                  const SizedBox(height: 12),
                  _buildCreateLimitHint(theme),
                ],
              ],
            ),
          ),
          const SizedBox(height: 14),
          sectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  i18n.format(
                    zhHans: '群成员({option1})',
                    zhHant: '群成員({option1})',
                    en: 'Members ({option1})',
                    ja: 'メンバー({option1})',
                    ko: '멤버({option1})',
                    vars: {'option1': '${widget.members.length}'},
                  ),
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: titleColor,
                  ),
                ),
                const SizedBox(height: 14),
                if (widget.members.isEmpty)
                  Text(
                    i18n.t(
                      zhHans: '暂无其他成员，创建后可再邀请',
                      zhHant: '暫無其他成員，建立後可再邀請',
                      en: 'No other members yet. You can invite later.',
                      ja: '他のメンバーはいません。後で招待できます。',
                      ko: '다른 멤버 없음. 나중에 초대할 수 있습니다.',
                    ),
                    style: TextStyle(fontSize: 13, color: weak, height: 1.4),
                  )
                else
                  Wrap(
                    spacing: 14,
                    runSpacing: 12,
                    children: widget.members
                        .map((item) => _buildMemberItem(item, theme))
                        .toList(),
                  ),
                const SizedBox(height: 14),
                _buildCreateGroupDeclaration(theme),
              ],
            ),
          ),
        ],
      ),
    );

    final rightPane = AbsorbPointer(
      absorbing: _submitting,
      child: Container(
        margin: const EdgeInsets.fromLTRB(8, 16, 20, 20),
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
        decoration: BoxDecoration(
          color: cardBackgroundColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: dividerColor.withValues(alpha: 0.7)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              i18n.t(
                zhHans: '群类型',
                zhHant: '群類型',
                en: 'Group Type',
                ja: 'グループタイプ',
                ko: '그룹 유형',
              ),
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: titleColor,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              i18n.t(
                zhHans: '创建后类型不可更改，请按规模选择',
                zhHant: '建立後類型不可更改，請按規模選擇',
                en: 'Type can’t be changed later. Pick by size.',
                ja: '作成後は変更できません。規模で選んでください。',
                ko: '생성 후 유형 변경 불가. 규모에 맞게 선택하세요.',
              ),
              style: TextStyle(fontSize: 12, color: weak, height: 1.35),
            ),
            const SizedBox(height: 16),
            if (widget.showGroupTypeSelector)
              _buildDesktopGroupTypeOptions(theme)
            else
              _buildCreateLimitHint(theme),
            const SizedBox(height: 14),
            _buildSelectedGroupTypeDescription(theme),
            const Spacer(),
            SizedBox(
              height: 44,
              child: FilledButton(
                onPressed:
                    _submitting ? null : () => _handleCreatePressed(context),
                style: FilledButton.styleFrom(
                  backgroundColor: primary,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: primary.withValues(alpha: 0.45),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: _submitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        i18n.t(
                          zhHans: '创建',
                          zhHant: '建立',
                          en: 'Create',
                          ja: '作成',
                          ko: '만들기',
                        ),
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );

    return Material(
      color: pageBackgroundColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: 56,
            padding: const EdgeInsets.fromLTRB(8, 0, 20, 0),
            decoration: BoxDecoration(
              color: cardBackgroundColor,
              border: Border(
                bottom: BorderSide(color: dividerColor.withValues(alpha: 0.85)),
              ),
            ),
            child: Row(
              children: [
                IconButton(
                  tooltip: i18n.t(
                    zhHans: '返回',
                    zhHant: '返回',
                    en: 'Back',
                    ja: '戻る',
                    ko: '뒤로',
                  ),
                  onPressed: _submitting
                      ? null
                      : () => Navigator.of(context).maybePop(),
                  icon: Icon(
                    Icons.arrow_back_ios_new_rounded,
                    size: 18,
                    color: primary,
                  ),
                ),
                Expanded(
                  child: Text(
                    _pageTitle(i18n),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: titleColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(flex: 11, child: leftPane),
                Container(width: 1, color: dividerColor.withValues(alpha: 0.7)),
                Expanded(flex: 9, child: rightPane),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Web 右侧栏：群类型纵向选项，比手机横排更易扫读。
  Widget _buildDesktopGroupTypeOptions(TUITheme theme) {
    final i18n = AppI18n.of(context);
    return Column(
      children: [
        _buildDesktopGroupTypeOption(
          theme: theme,
          value: GroupType.Public,
          label: i18n.t(
            zhHans: '普通群',
            zhHant: '普通群',
            en: 'Standard Group',
            ja: '通常グループ',
            ko: '일반 그룹',
          ),
          subtitle: GroupCreateLimitMessage.memberCapacityShortHint(
            GroupType.Public,
          ),
        ),
        const SizedBox(height: 10),
        _buildDesktopGroupTypeOption(
          theme: theme,
          value: GroupType.Community,
          label: i18n.t(
            zhHans: '超级大群',
            zhHant: '超級大群',
            en: 'Super Group',
            ja: 'スーパーグループ',
            ko: '슈퍼 그룹',
          ),
          subtitle: GroupCreateLimitMessage.memberCapacityShortHint(
            GroupType.Community,
          ),
        ),
      ],
    );
  }

  Widget _buildDesktopGroupTypeOption({
    required TUITheme theme,
    required String value,
    required String label,
    String? subtitle,
  }) {
    final selected = _selectedGroupType == value;
    final primary = theme.primaryColor ?? const Color(0xFF1E90FF);
    final fillColor = theme.inputFillColor ??
        theme.selectPanelBgColor ??
        const Color(0xFFF1F2F6);
    final titleColor = theme.darkTextColor ?? Colors.black;
    final weak = theme.weakTextColor ?? const Color(0xFF999999);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          if (_selectedGroupType == value) {
            return;
          }
          setState(() => _selectedGroupType = value);
        },
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
          decoration: BoxDecoration(
            color: selected ? primary.withValues(alpha: 0.10) : fillColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? primary : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight:
                            selected ? FontWeight.w600 : FontWeight.w500,
                        color: selected ? primary : titleColor,
                      ),
                    ),
                    if (subtitle != null && subtitle.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.2,
                          color:
                              selected ? primary.withValues(alpha: 0.85) : weak,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Icon(
                selected ? Icons.check_circle_rounded : Icons.circle_outlined,
                size: 22,
                color: selected ? primary : weak.withValues(alpha: 0.7),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final i18n = AppI18n.of(context);
    final theme = Provider.of<DefaultThemeData>(context).theme;
    final appBarBaseColor =
        theme.appbarBgColor ?? theme.wideBackgroundColor ?? Colors.white;
    final isDarkBackground =
        ThemeData.estimateBrightnessForColor(appBarBaseColor) ==
            Brightness.dark;
    const lightBackgroundColor = Color(0xFFF1F1F1);
    final pageBackgroundColor = isDarkBackground
        ? (theme.weakBackgroundColor ?? appBarBaseColor)
        : lightBackgroundColor;
    final appBarBackgroundColor = isDarkBackground
        ? (theme.appbarBgColor ?? theme.weakBackgroundColor ?? Colors.white)
        : lightBackgroundColor;
    final cardBackgroundColor = isDarkBackground
        ? (theme.conversationItemBgColor ??
            theme.wideBackgroundColor ??
            const Color(0xFF1C1C1E))
        : Colors.white;
    final dividerColor = theme.weakDividerColor ?? const Color(0xFFE5E5E5);
    final overlayStyle = _buildPageOverlayStyle(
      isDarkBackground: isDarkBackground,
      pageBackgroundColor: pageBackgroundColor,
    );

    if (widget.embeddedInDesktopPopup) {
      return _buildDesktopConfirmChrome(
        i18n: i18n,
        theme: theme,
        pageBackgroundColor: pageBackgroundColor,
        cardBackgroundColor: cardBackgroundColor,
        dividerColor: dividerColor,
      );
    }

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: overlayStyle,
      child: Scaffold(
        backgroundColor: pageBackgroundColor,
        appBar: AppBar(
          systemOverlayStyle: overlayStyle,
          elevation: 0,
          scrolledUnderElevation: 0,
          title: Text(
            _pageTitle(i18n),
            style: TextStyle(
              color:
                  theme.appbarTextColor ?? theme.darkTextColor ?? Colors.black,
              fontSize: 17,
              fontWeight: FontWeight.w600,
            ),
          ),
          shadowColor: theme.weakDividerColor,
          backgroundColor: appBarBackgroundColor,
          surfaceTintColor: Colors.transparent,
          iconTheme: IconThemeData(
            color: theme.primaryColor ?? const Color(0xFF1E90FF),
          ),
          actions: [
            TextButton(
              onPressed:
                  _submitting ? null : () => _handleCreatePressed(context),
              child: _submitting
                  ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: theme.primaryColor ?? const Color(0xFF1E90FF),
                      ),
                    )
                  : Text(
                      AppI18n.of(context).t(
                        zhHans: '创建',
                        zhHant: '建立',
                        en: 'Create',
                        ja: '作成',
                        ko: '만들기',
                      ),
                      style: TextStyle(
                        color: theme.primaryColor ?? const Color(0xFF1E90FF),
                        fontSize: 16,
                      ),
                    ),
            ),
          ],
        ),
        body: AbsorbPointer(
          absorbing: _submitting,
          child: SingleChildScrollView(
            child: _buildFormBody(
              i18n: i18n,
              theme: theme,
              cardBackgroundColor: cardBackgroundColor,
              pageBackgroundColor: pageBackgroundColor,
              dividerColor: dividerColor,
            ),
          ),
        ),
      ),
    );
  }
}
