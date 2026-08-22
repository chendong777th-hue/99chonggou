// ignore_for_file: unnecessary_getters_setters, avoid_print

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:tencent_cloud_chat_sdk/enum/group_add_opt_type.dart';
import 'package:tencent_cloud_chat_sdk/enum/group_member_filter_enum.dart';
import 'package:tencent_cloud_chat_sdk/enum/group_member_role.dart';
import 'package:tencent_cloud_chat_sdk/enum/group_member_role_enum.dart';
import 'package:tencent_cloud_chat_sdk/enum/group_type.dart';
import 'package:tencent_cloud_chat_sdk/enum/receive_message_opt_enum.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_callback.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_callback.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_conversation.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_conversation.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_friend_info.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_friend_info.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_group_info.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_group_info.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_group_member_full_info.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_group_member_full_info.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_group_member_info.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_group_member_info.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_group_member_operation_result.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_group_member_operation_result.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_group_member_search_param.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_group_member_search_param.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_group_member_search_result.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_group_member_search_result.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_value_callback.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_value_callback.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/life_cycle/group_profile_life_cycle.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/services/group_member_store.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/view_models/tui_friendship_view_model.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/view_models/tui_conversation_view_model.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/services/display_name_store.dart';
import 'package:tencent_cloud_chat_uikit/data_services/conversation/conversation_services.dart';
import 'package:tencent_cloud_chat_uikit/data_services/core/core_services_implements.dart';
import 'package:tencent_cloud_chat_uikit/data_services/friendShip/friendship_services.dart';
import 'package:tencent_cloud_chat_uikit/data_services/group/group_services.dart';
import 'package:tencent_cloud_chat_uikit/data_services/group/self_hosted_group_invite_bridge.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/group_role_policy.dart';
import 'package:tencent_cloud_chat_uikit/data_services/group/self_hosted_group_bridge.dart';
import 'package:tencent_cloud_chat_uikit/data_services/message/message_services.dart';
import 'package:tencent_cloud_chat_uikit/data_services/services_locatar.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/logger.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/picker_user_filter.dart';

class TUIGroupProfileModel extends ChangeNotifier {
  final CoreServicesImpl _coreServices = serviceLocator<CoreServicesImpl>();
  final GroupServices _groupServices = serviceLocator<GroupServices>();
  final ConversationService _conversationService =
      serviceLocator<ConversationService>();
  final MessageService _messageService = serviceLocator<MessageService>();
  final FriendshipServices _friendshipServices =
      serviceLocator<FriendshipServices>();
  GroupProfileLifeCycle? _lifeCycle;

  V2TimConversation? _conversation;
  String _groupID = "";
  List<V2TimFriendInfo>? _contactList;
  List<V2TimGroupMemberFullInfo?>? _groupMemberList;
  String _groupMemberListSeq = "0";
  bool _groupMemberListLoading = false;
  bool _groupMemberListLoadingMore = false;
  V2TimGroupInfo? _groupInfo;
  Function(V2TimGroupMemberFullInfo groupMemberFullInfo,
      TapDownDetails? tapDetails)? onClickUser;

  GroupProfileLifeCycle? get lifeCycle => _lifeCycle;

  set lifeCycle(GroupProfileLifeCycle? value) {
    _lifeCycle = value;
  }

  V2TimConversation? get conversation => _conversation;

  set conversation(V2TimConversation? value) {
    _conversation = value;
  }

  String get groupID => _groupID;

  set groupID(String value) {
    _groupID = value;
  }

  List<V2TimFriendInfo> get contactList => _contactList ?? [];

  set contactList(List<V2TimFriendInfo> value) {
    _contactList = value;
  }

  List<V2TimGroupMemberFullInfo?> get groupMemberList => _groupMemberList ?? [];

  bool get isGroupMemberListLoading => _groupMemberListLoading;

  bool get isGroupMemberListLoadingMore => _groupMemberListLoadingMore;

  /// 当前分页窗口是否还有下一页（非「全群已齐」语义）。
  bool get hasMoreGroupMembers {
    final seq = _groupMemberListSeq.trim();
    return seq.isNotEmpty && seq != '0';
  }

  set groupMemberList(List<V2TimGroupMemberFullInfo?> value) {
    _groupMemberList = value;
  }

  V2TimGroupInfo? get groupInfo => _groupInfo;

  set groupInfo(V2TimGroupInfo? value) {
    _groupInfo = value;
  }

  void loadData(String groupID) {
    _groupID = groupID;
    loadGroupInfo(groupID);
    loadGroupMemberList(groupID: groupID);
    _loadConversation();
    _loadContactList();
  }

  loadGroupInfo(String groupID) async {
    final groupInfo =
        await _groupServices.getGroupsInfo(groupIDList: [groupID]);
    if (groupInfo != null) {
      final groupRes = groupInfo.first;
      if (groupRes.resultCode == 0) {
        _groupInfo = groupRes.groupInfo;
        await _ensureCommunityInviteApprovalEnabled();
      }
    }
    notifyListeners();
  }

  Future<void> _ensureCommunityInviteApprovalEnabled() async {
    // 99chat: Community 加群/邀请方式由服务端 REST `join-options` 管理。
    return;
  }

  /// 首页拉取后自动翻完剩余页（触底不可靠时仍保证名单完整）。
  Future<void> loadGroupMemberList(
      {required String groupID, int count = 100, String? seq}) async {
    final isFirstPage = seq == null || seq == "" || seq == "0";
    if (isFirstPage) {
      _groupMemberListLoading = true;
      await _hydrateGroupMemberListFromCache(groupID);
      notifyListeners();
    }
    try {
      await _loadGroupMemberListFunction(
          groupID: groupID, seq: seq, count: count);
      if (isFirstPage) {
        await _drainRemainingGroupMemberPages(groupID: groupID, count: count);
      }
    } finally {
      if (isFirstPage) {
        _groupMemberListLoading = false;
        notifyListeners();
      }
    }
  }

  /// 自动续页直到 nextSeq=0；上限防死循环。
  Future<void> _drainRemainingGroupMemberPages({
    required String groupID,
    int count = 100,
  }) async {
    var guard = 0;
    while (hasMoreGroupMembers && guard < 100) {
      guard++;
      await _loadGroupMemberListFunction(
        groupID: groupID,
        seq: _groupMemberListSeq,
        count: count,
      );
    }
  }

  Future<bool> loadMoreGroupMembers({int count = 100}) async {
    final groupID = _groupID.trim();
    if (groupID.isEmpty ||
        !hasMoreGroupMembers ||
        _groupMemberListLoading ||
        _groupMemberListLoadingMore) {
      return false;
    }
    _groupMemberListLoadingMore = true;
    notifyListeners();
    try {
      await _loadGroupMemberListFunction(
        groupID: groupID,
        seq: _groupMemberListSeq,
        count: count,
      );
      return hasMoreGroupMembers;
    } finally {
      _groupMemberListLoadingMore = false;
      notifyListeners();
    }
  }

  Future<void> _hydrateGroupMemberListFromCache(String groupID) async {
    const pageSize = 100;
    if (SelfHostedGroupBridge.enabled) {
      final cached =
          await SelfHostedGroupBridge.loadCachedGroupMemberList(groupID);
      if (cached.isNotEmpty) {
        final window =
            cached.length > pageSize ? cached.sublist(0, pageSize) : cached;
        _groupMemberList = window;
        GroupMemberStore.instance.putMembers(groupID, window, notify: false);
      }
      return;
    }
    final memory = GroupMemberStore.instance.membersForGroup(groupID);
    if (memory.isNotEmpty) {
      _groupMemberList =
          memory.length > pageSize ? memory.sublist(0, pageSize) : memory;
    }
  }

  /// 清空窗口后只重拉第一页（不再整表）。
  Future<void> reloadGroupMembers(String groupID) async {
    _groupMemberListSeq = "0";
    _groupMemberList = [];
    await loadGroupMemberList(groupID: groupID);
  }

  Future<String?> _loadGroupMemberListFunction(
      {required String groupID, int count = 100, String? seq}) async {
    final isFirstPage = seq == null || seq == "" || seq == "0";
    final res = await _groupServices.getGroupMemberList(
        groupID: groupID,
        filter: GroupMemberFilterTypeEnum.V2TIM_GROUP_MEMBER_FILTER_ALL,
        count: count,
        nextSeq: seq ?? _groupMemberListSeq);
    final groupMemberListRes = res.data;
    if (res.code == 0 && groupMemberListRes != null) {
      final groupMemberListTemp = groupMemberListRes.memberInfoList ?? [];
      outputLogger.i(
          "loadGroupMemberListfinish,groupMemberListTemp, ${groupMemberListRes.nextSeq},  ${groupMemberListTemp.length}");
      final uniqueNewMembers = groupMemberListTemp
          .where((member) => member.userID.trim().isNotEmpty)
          .toList(growable: false);
      if (isFirstPage) {
        _groupMemberList = uniqueNewMembers;
      } else {
        final existingUserIds = _groupMemberList
                ?.map((member) => member?.userID)
                .whereType<String>()
                .toSet() ??
            <String>{};
        final appended = uniqueNewMembers
            .where((member) => !existingUserIds.contains(member.userID.trim()))
            .toList(growable: false);
        _groupMemberList = [...?_groupMemberList, ...appended];
      }
      _groupMemberListSeq = groupMemberListRes.nextSeq ?? "0";
      GroupMemberStore.instance.putMembers(groupID, groupMemberListTemp);
      notifyListeners();
    }
    return groupMemberListRes?.nextSeq;
  }

  Future<void> processGroupMemberListEnter(
      {required String groupID,
      required List<V2TimGroupMemberInfo> memberList}) async {
    final List<V2TimGroupMemberFullInfo> fullInfoList =
        memberList.where((member) => member.userID != null).map((member) {
      return V2TimGroupMemberFullInfo(
        userID: member.userID!,
        nickName: member.nickName,
        nameCard: member.nameCard,
        friendRemark: member.friendRemark,
        faceUrl: member.faceUrl,
        onlineDevices: member.onlineDevices,
      );
    }).toList();

    for (final fullInfo in fullInfoList) {
      final exists =
          _groupMemberList?.any((e) => e?.userID == fullInfo.userID) ?? false;
      if (!exists) {
        _groupMemberList = [...?_groupMemberList, fullInfo];
      }
    }
    GroupMemberStore.instance.putMembers(groupID, fullInfoList);
  }

  Future<void> processGroupMemberListLeave(
      {required String groupID,
      required List<V2TimGroupMemberInfo> memberList}) async {
    final userIDsToRemove = memberList
        .map((member) => _normalizeMemberUserId(member.userID))
        .where((id) => id.isNotEmpty)
        .toSet();

    _groupMemberList?.removeWhere((member) {
      final id = _normalizeMemberUserId(member?.userID);
      return id.isNotEmpty && userIDsToRemove.contains(id);
    });
    GroupMemberStore.instance
        .removeMembers(groupID, userIDsToRemove, notify: false);
  }

  String _normalizeMemberUserId(String? userId) {
    return userId?.trim() ?? '';
  }

  _loadConversation() async {
    final raw = _groupID.trim();
    if (raw.isEmpty) {
      return;
    }
    final candidates = <String>{
      'group_$raw',
      if (raw.startsWith('group_')) raw,
    };
    for (final conversationID in candidates) {
      final loaded = await _conversationService.getConversation(
        conversationID: conversationID,
      );
      if (loaded != null) {
        conversation = loaded;
        notifyListeners();
        return;
      }
    }
  }

  _loadContactList() async {
    final res = await _friendshipServices.getFriendList();
    _contactList = filterFriendListForPickers(res ?? []);
  }

  pinedConversation(bool isPined) async {
    await _conversationService.pinConversation(
        conversationID: "group_$_groupID", isPinned: isPined);
    conversation?.isPinned = isPined;
    notifyListeners();
  }

  Future<V2TimCallback> setMessageDisturb(bool value) async {
    final groupId = _groupID.trim();
    final res = await _messageService.setGroupReceiveMessageOpt(
        groupID: groupId,
        opt: value
            ? ReceiveMsgOptEnum.V2TIM_RECEIVE_NOT_NOTIFY_MESSAGE
            : ReceiveMsgOptEnum.V2TIM_RECEIVE_MESSAGE);
    if (res.code == 0) {
      final optIndex = (value
              ? ReceiveMsgOptEnum.V2TIM_RECEIVE_NOT_NOTIFY_MESSAGE
              : ReceiveMsgOptEnum.V2TIM_RECEIVE_MESSAGE)
          .index;
      if (conversation != null) {
        conversation!.recvOpt = optIndex;
      }
    }
    notifyListeners();
    return res;
  }

  Future<V2TimValueCallback<V2GroupMemberInfoSearchResult>> searchGroupMember(
      V2TimGroupMemberSearchParam searchParam) async {
    final res =
        await _groupServices.searchGroupMembers(searchParam: searchParam);

    if (res.code == 0) {}
    return res;
  }

  Future<V2TimCallback?> setGroupName(String groupName) async {
    if (_groupInfo != null) {
      String? originalGroupName = _groupInfo?.groupName;
      _groupInfo?.groupName = groupName;
      V2TimGroupInfo v2timGroupInfo =
          V2TimGroupInfo(groupID: _groupID, groupType: _groupInfo!.groupType);
      v2timGroupInfo.groupName = groupName;
      final response = await _groupServices.setGroupInfo(info: v2timGroupInfo);
      if (response.code == 0) {
        final name = groupName.trim();
        DisplayNameStore.instance.setGroup(_groupID, name);
        serviceLocator<TUIConversationViewModel>()
            .updateGroupShowName(_groupID, name);
        serviceLocator<TUIFriendShipViewModel>()
            .updateGroupNameLocal(_groupID, name);
      } else {
        _groupInfo?.groupName = originalGroupName;
      }
      notifyListeners();
      return response;
    }
    return null;
  }

  Future<V2TimCallback?> setGroupNotification(String notification) async {
    if (_groupInfo != null) {
      final originalNotification = _groupInfo?.notification;
      final originalCustomInfo = _groupInfo?.customInfo == null
          ? null
          : Map<String, String>.from(_groupInfo!.customInfo!);
      final originalLastInfoTime = _groupInfo?.lastInfoTime;
      V2TimGroupInfo v2timGroupInfo =
          V2TimGroupInfo(groupID: _groupID, groupType: _groupInfo!.groupType);
      v2timGroupInfo.notification = notification;
      final response = await _groupServices.setGroupInfo(info: v2timGroupInfo);
      if (response.code == 0) {
        _groupInfo?.notification = notification;
        final selfId = _coreServices.loginUserInfo?.userID?.trim() ?? '';
        if (selfId.isNotEmpty) {
          final custom = Map<String, String>.from(_groupInfo?.customInfo ?? {});
          custom['noticeUpdatedBy'] = selfId;
          _groupInfo?.customInfo = custom;
        }
        _groupInfo?.lastInfoTime =
            DateTime.now().millisecondsSinceEpoch ~/ 1000;
        notifyListeners();
      } else {
        _groupInfo?.notification = originalNotification;
        _groupInfo?.customInfo = originalCustomInfo;
        _groupInfo?.lastInfoTime = originalLastInfoTime;
      }
      return response;
    }
    return null;
  }

  String getSelfNameCard() {
    try {
      final loginUserID = _coreServices.loginUserInfo?.userID;
      String nameCard = "";
      if (_groupMemberList != null) {
        nameCard = groupMemberList
                .firstWhere((element) => element?.userID == loginUserID)
                ?.nameCard ??
            "";
      }

      return nameCard;
    } catch (err) {
      return "";
    }
  }

  Future<V2TimCallback?> setNameCard(String nameCard) async {
    final loginUserID = _coreServices.loginUserInfo?.userID;
    if (loginUserID == null || loginUserID.isEmpty) {
      return null;
    }

    final res = await _groupServices.setGroupMemberInfo(
        groupID: _groupID, userID: loginUserID, nameCard: nameCard);
    if (res.code != 0) {
      return res;
    }

    V2TimGroupMemberFullInfo? latest;
    final infoRes = await _groupServices.getGroupMembersInfo(
      groupID: _groupID,
      memberList: [loginUserID],
    );
    if (infoRes.code == 0 && infoRes.data != null && infoRes.data!.isNotEmpty) {
      latest = infoRes.data!.first;
    }

    GroupMemberStore.instance.putNameCard(
      groupID: _groupID,
      userID: loginUserID,
      nameCard: nameCard,
      member: latest,
      notify: false,
    );

    final targetIndex = _groupMemberList
        ?.indexWhere((element) => element?.userID == loginUserID);
    if (latest != null) {
      if (targetIndex != null && targetIndex >= 0) {
        _groupMemberList![targetIndex] = latest;
      } else {
        _groupMemberList = [...?_groupMemberList, latest];
      }
      GroupMemberStore.instance.putMember(_groupID, latest);
    } else {
      if (targetIndex != null && targetIndex >= 0) {
        _groupMemberList![targetIndex]?.nameCard = nameCard;
        GroupMemberStore.instance.putNameCard(
          groupID: _groupID,
          userID: loginUserID,
          nameCard: nameCard,
          member: _groupMemberList![targetIndex],
        );
      } else {
        GroupMemberStore.instance.putNameCard(
          groupID: _groupID,
          userID: loginUserID,
          nameCard: nameCard,
        );
      }
    }
    notifyListeners();
    return res;
  }

  Future<V2TimCallback?> setGroupAddOpt(int addOpt) async {
    if (_groupInfo != null) {
      int? originalAddopt = _groupInfo?.groupAddOpt;
      _groupInfo?.groupAddOpt = addOpt;
      V2TimGroupInfo v2timGroupInfo =
          V2TimGroupInfo(groupID: _groupID, groupType: _groupInfo!.groupType);
      v2timGroupInfo.groupAddOpt = addOpt;
      final response = await _groupServices.setGroupInfo(info: v2timGroupInfo);
      if (response.code != 0) {
        _groupInfo?.groupAddOpt = originalAddopt;
      }
      notifyListeners();
      return response;
    }
    return null;
  }

  Future<V2TimCallback> setMemberToNormal(String userID) async {
    final res = await _groupServices.setGroupMemberRole(
        groupID: _groupID,
        userID: userID,
        role: GroupMemberRoleTypeEnum.V2TIM_GROUP_MEMBER_ROLE_MEMBER);
    if (res.code == 0) {
      final targetIndex = _memberIndexByUserId(userID);
      if (targetIndex != -1) {
        final targetElem = _groupMemberList![targetIndex];
        targetElem?.role = GroupMemberRoleType.V2TIM_GROUP_MEMBER_ROLE_MEMBER;
        _groupMemberList![targetIndex] = targetElem;
      }
      notifyListeners();
    }
    return res;
  }

  Future<V2TimCallback> setMemberToAdmin(String userID) async {
    return setMembersToAdmin(<String>[userID]);
  }

  Future<V2TimCallback> setMembersToAdmin(List<String> userIDs) async {
    final normalized = userIDs
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
    if (normalized.isEmpty) {
      return V2TimCallback(code: -1, desc: 'INVALID_INPUT');
    }
    final res = await _groupServices.setGroupMemberRoles(
      groupID: _groupID,
      userIDList: normalized,
      role: GroupMemberRoleTypeEnum.V2TIM_GROUP_MEMBER_ROLE_ADMIN,
    );
    if (res.code == 0) {
      for (final userID in normalized) {
        final targetIndex = _memberIndexByUserId(userID);
        if (targetIndex != -1) {
          final targetElem = _groupMemberList![targetIndex];
          targetElem?.role = GroupMemberRoleType.V2TIM_GROUP_MEMBER_ROLE_ADMIN;
          _groupMemberList![targetIndex] = targetElem;
        }
      }
      notifyListeners();
    }
    return res;
  }

  int _memberIndexByUserId(String userID) {
    final target = userID.trim();
    if (target.isEmpty || _groupMemberList == null) {
      return -1;
    }
    return _groupMemberList!.indexWhere((member) {
      final id = member?.userID?.trim() ?? '';
      return id.isNotEmpty && id == target;
    });
  }

  void onOwnerChanged(String? userID) {
    if (userID == null) {
      return;
    }

    // 把之前的群主更新为普通成员
    final preOwnerIndex = _groupMemberList!.indexWhere(
        (e) => e!.role == GroupMemberRoleType.V2TIM_GROUP_MEMBER_ROLE_OWNER);
    if (preOwnerIndex != -1) {
      final preOwnerElem = _groupMemberList![preOwnerIndex];
      preOwnerElem?.role = GroupMemberRoleType.V2TIM_GROUP_MEMBER_ROLE_MEMBER;

      if (kDebugMode) {
        print("preOwnerUserID: ${preOwnerElem?.userID}");
      }
    }

    // 设置新的群主
    final targetIndex =
        _groupMemberList!.indexWhere((e) => e!.userID == userID);
    if (targetIndex != -1) {
      final targetElem = _groupMemberList![targetIndex];
      targetElem?.role = GroupMemberRoleType.V2TIM_GROUP_MEMBER_ROLE_OWNER;
      _groupMemberList![targetIndex] = targetElem;

      if (kDebugMode) {
        print("newOwnerUserID: ${targetElem?.userID}");
      }
    }

    notifyListeners();
  }

  bool canInviteMember() {
    final groupType = _groupInfo?.groupType;
    if (groupType == GroupType.Work ||
        groupType == "Private" ||
        groupType == GroupType.Public ||
        groupType == GroupType.Meeting ||
        groupType == GroupType.Community) {
      return true;
    }
    return false;
  }

  bool canKickOffMember() {
    return GroupRolePolicy.canKickMemberEntry(
      selfRole: _groupInfo?.role,
      groupType: _groupInfo?.groupType,
    );
  }

  Future<V2TimCallback?> setMuteAll(bool muteAll) async {
    if (_groupInfo != null) {
      final originalMuted = _groupInfo?.isAllMuted ?? false;
      _groupInfo?.isAllMuted = muteAll;
      V2TimGroupInfo v2timGroupInfo =
          V2TimGroupInfo(groupID: _groupID, groupType: _groupInfo!.groupType);
      v2timGroupInfo.isAllMuted = muteAll;
      final response = await _groupServices.setGroupInfo(info: v2timGroupInfo);
      if (response.code != 0) {
        _groupInfo?.isAllMuted = originalMuted;
      } else {
        await loadGroupInfo(_groupID);
        await reloadGroupMembers(_groupID);
      }
      notifyListeners();
      return response;
    }
    return null;
  }

  Future<V2TimCallback?> muteGroupMember(
      String userID, bool isMute, int? serverTime) async {
    const muteTime = 315360000;
    final res = await _groupServices.muteGroupMember(
        groupID: _groupID, userID: userID, seconds: isMute ? muteTime : 0);
    if (res.code == 0) {
      final targetIndex = _memberIndexByUserId(userID);
      if (targetIndex != -1) {
        final targetElem = _groupMemberList![targetIndex];
        final now = serverTime ?? DateTime.now().millisecondsSinceEpoch ~/ 1000;
        if (targetElem != null) {
          targetElem.muteUntil = isMute ? now + muteTime : 0;
          _groupMemberList![targetIndex] = targetElem;
          GroupMemberStore.instance.putMember(_groupID, targetElem);
        }
      }
      notifyListeners();
    }
    return null;
  }

  Future<V2TimCallback> kickOffMember(List<String> userIDs) async {
    final normalized = userIDs
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toList(growable: false);
    if (normalized.isEmpty) {
      return V2TimCallback(code: -1, desc: 'INVALID_INPUT');
    }
    final res = await _groupServices.kickGroupMember(
      groupID: _groupID,
      memberList: normalized,
    );
    if (res.code == 0) {
      if (SelfHostedGroupBridge.enabled ||
          res.desc?.toUpperCase() == 'PARTIAL_SUCCESS') {
        await reloadGroupMembers(_groupID);
        await loadGroupInfo(_groupID);
      } else {
        await processGroupMemberListLeave(
          groupID: _groupID,
          memberList:
              normalized.map((id) => V2TimGroupMemberInfo(userID: id)).toList(),
        );
        final currentCount = _groupInfo?.memberCount;
        if (currentCount != null && currentCount > 0) {
          _groupInfo!.memberCount =
              (currentCount - normalized.length).clamp(0, currentCount);
        }
      }
      notifyListeners();
    }
    return res;
  }

  Future<V2TimValueCallback<List<V2TimGroupMemberOperationResult>>>
      inviteUserToGroup(List<String> userIDS) async {
    final normalized =
        userIDS.map((id) => id.trim()).where((id) => id.isNotEmpty).toList();
    if (SelfHostedGroupInviteBridge.enabled) {
      final bridged = await SelfHostedGroupInviteBridge.tryInvite(
        groupID: _groupID,
        groupType: _groupInfo?.groupType,
        userList: normalized,
      );
      if (bridged != null) {
        return bridged;
      }
    }
    final res = await _groupServices.inviteUserToGroup(
        groupID: _groupID, userList: normalized);
    return res;
  }
}
