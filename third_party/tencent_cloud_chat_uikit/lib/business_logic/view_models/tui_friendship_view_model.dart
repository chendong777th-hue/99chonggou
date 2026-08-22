import 'dart:async';
import 'dart:math';

import 'package:flutter/cupertino.dart';
import 'package:tencent_cloud_chat_sdk/enum/V2TimFriendshipListener.dart';
import 'package:tencent_cloud_chat_sdk/enum/friend_application_type_enum.dart';
import 'package:tencent_cloud_chat_sdk/enum/friend_response_type_enum.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_friend_application.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_friend_application.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_friend_info.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_friend_info.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_friend_operation_result.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_friend_operation_result.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_group_info.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_group_info.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_group_member_full_info.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_group_member_full_info.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_user_status.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_user_status.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/life_cycle/block_list_life_cycle.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/life_cycle/friend_list_life_cycle.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/life_cycle/new_contact_life_cycle.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/services/display_name_store.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/services/group_member_store.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/view_models/tui_conversation_view_model.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/view_models/tui_self_info_view_model.dart';
import 'package:tencent_cloud_chat_uikit/data_services/friendShip/friendship_services.dart';
import 'package:tencent_cloud_chat_uikit/data_services/friendShip/self_hosted_friendship_bridge.dart';
import 'package:tencent_cloud_chat_uikit/data_services/group/group_services.dart';
import 'package:tencent_cloud_chat_uikit/data_services/profile/user_profile_local_bridge.dart';
import 'package:tencent_cloud_chat_uikit/data_services/services_locatar.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/picker_user_filter.dart';

class TUIFriendShipViewModel extends ChangeNotifier {
  final FriendshipServices _friendshipServices =
      serviceLocator<FriendshipServices>();
  final GroupServices _groupServices = serviceLocator<GroupServices>();
  final TUISelfInfoViewModel selfInfoViewModel =
      serviceLocator<TUISelfInfoViewModel>();
  late V2TimFriendshipListener friendShipListener;
  List<V2TimFriendApplication?>? _friendApplicationList;
  List<V2TimFriendInfo>? _friendList;
  List<V2TimGroupInfo>? _groupList;
  List<V2TimUserStatus>? _userStatusList;
  int _friendApplicationAmount = 0;
  List<V2TimFriendInfo>? _blockList;
  bool _isLoadingContactList = false;
  bool _hasLoadedContactList = false;
  Future<void>? _loadingContactListFuture;
  int _contactListLoadGeneration = 0;
  NewContactLifeCycle? _newContactLifeCycle;
  FriendListLifeCycle? _contactListLifeCycle;
  BlockListLifeCycle? _blockListLifeCycle;

  set newContactLifeCycle(NewContactLifeCycle? value) {
    _newContactLifeCycle = value;
  }

  set contactListLifeCycle(FriendListLifeCycle? value) {
    _contactListLifeCycle = value;
  }

  set blockListLifeCycle(BlockListLifeCycle? value) {
    _blockListLifeCycle = value;
  }

  void _onDisplayNameChanged() {
    final change = DisplayNameStore.instance.lastChange;
    if (change == null) {
      return;
    }
    if (change.type == 'group') {
      updateGroupNameLocal(change.id, change.name);
      return;
    }
    if (change.type == 'c2c') {
      notifyListeners();
    }
  }

  bool updateFriendRemarkLocal(String userID, String remark) {
    final uid = _rawUserUid(userID);
    if (uid.isEmpty || _friendList == null) {
      return false;
    }
    var updated = false;
    for (final item in _friendList!) {
      if (_rawUserUid(item.userID) == uid) {
        item.friendRemark = remark.trim();
        updated = true;
      }
    }
    if (updated) {
      GroupMemberStore.instance.putFriendRemarkForUser(uid, remark.trim());
      notifyListeners();
    }
    return updated;
  }

  /// 与 app 侧 ChatIdFormat.rawUserUid 对齐：去首尾空白与前导 @。
  static String _rawUserUid(String? input) {
    final trimmed = input?.trim() ?? '';
    if (trimmed.isEmpty) {
      return '';
    }
    if (trimmed.startsWith('@')) {
      return trimmed.substring(1);
    }
    return trimmed;
  }

  bool updateGroupNameLocal(String groupID, String groupName) {
    final gid = groupID.trim();
    final name = groupName.trim();
    if (gid.isEmpty || name.isEmpty || _groupList == null) {
      return false;
    }
    var updated = false;
    for (final item in _groupList!) {
      if (item.groupID == gid) {
        item.groupName = name;
        updated = true;
      }
    }
    if (updated) {
      notifyListeners();
    }
    return updated;
  }

  void _applyGroupNameOverrides() {
    final list = _groupList;
    if (list == null || list.isEmpty) {
      return;
    }
    for (final item in list) {
      final name = DisplayNameStore.instance.group(item.groupID ?? '');
      if (name != null && name.isNotEmpty) {
        item.groupName = name;
      }
    }
  }

  set userStatusList(List<V2TimUserStatus> value) {
    _userStatusList = value;
    notifyListeners();
  }

  List<V2TimUserStatus> get userStatusList => _userStatusList ?? [];

  List<V2TimFriendInfo> get blockList {
    return _blockList ?? [];
  }

  List<V2TimGroupInfo> get groupList {
    return _groupList ?? [];
  }

  List<V2TimFriendInfo>? get friendList {
    return _friendList;
  }

  int get friendApplicationAmount => _friendApplicationAmount;

  List<V2TimFriendApplication?>? get friendApplicationList =>
      _friendApplicationList;

  bool get isLoadingContactList => _isLoadingContactList;

  bool get hasLoadedContactList => _hasLoadedContactList;

  TUIFriendShipViewModel() {
    DisplayNameStore.instance.addListener(_onDisplayNameChanged);
    friendShipListener = V2TimFriendshipListener(
      onFriendApplicationListAdded: (applicationList) {
        loadContactApplicationData();
      },
      onFriendApplicationListDeleted: (userIDList) {
        loadContactApplicationData();
      },
      onFriendApplicationListRead: () {
        loadContactApplicationData();
      },
      onFriendInfoChanged: (infoList) {
        // Always persist public nick/face. SelfHosted must not apply IM SNS
        // remarks into DisplayNameStore, but must not skip public profile either.
        for (final info in infoList) {
          final userID = info.userID.trim();
          if (userID.isEmpty) {
            continue;
          }
          final profile = info.userProfile;
          if (profile == null) {
            continue;
          }
          unawaited(
            UserProfileLocalBridge.upsertPublicProfileFromSnapshot(
              userId: userID,
              nickName: profile.nickName,
              faceUrl: profile.faceUrl,
            ),
          );
        }
        if (SelfHostedFriendshipBridge.enabled) {
          // 备注以自托管为准，不把 IM SNS 里未清空的旧备注写回 Store。
          loadContactListData();
          return;
        }
        var storeChanged = false;
        for (final info in infoList) {
          final userID = info.userID.trim();
          if (userID.isEmpty) {
            continue;
          }
          final remark = info.friendRemark?.trim() ?? '';
          final nickName = info.userProfile?.nickName?.trim() ?? '';
          updateFriendRemarkLocal(userID, remark);
          storeChanged = DisplayNameStore.instance.applyImFriendShowName(
                userID: userID,
                imRemark: remark,
                imNickName: nickName,
                notify: false,
              ) ||
              storeChanged;
        }
        if (storeChanged) {
          DisplayNameStore.instance.notifyBatch();
        }
        loadContactListData();
      },
      onFriendListAdded: (users) async {
        await reloadContactListData();
        loadUserStatus();
      },
      onFriendListDeleted: (userList) async {
        await reloadContactListData();
        loadUserStatus();
      },
      onBlackListAdd: (infoList) async {
        await loadBlockListData();
        loadUserStatus();
      },
      onBlackListDeleted: (userList) async {
        await loadBlockListData();
        loadUserStatus();
      },
    );
  }

  initFriendShipModel() {
    loadData();
  }

  loadData() async {
    loadContactApplicationData();
    loadBlockListData();
    await loadContactListData();
    loadUserStatus();
  }

  clearData() {
    _friendApplicationList = [];
    _friendApplicationAmount = 0;
    _friendList = [];
    _groupList = [];
    _userStatusList = [];
    _blockList = [];
    _isLoadingContactList = false;
    _hasLoadedContactList = false;
    notifyListeners();
  }

  loadUserStatus() async {
    if (selfInfoViewModel.globalConfig?.isShowOnlineStatus == false ||
        friendList == null ||
        friendList!.isEmpty) {
      return;
    }

    final List<List<String>> userIDSet = [];
    final int needHowManyRequest = ((friendList!.length) / 500).ceil();
    final int amountEachRequest =
        ((friendList!.length) / needHowManyRequest).ceil();

    for (int i = 0; i < needHowManyRequest; i++) {
      userIDSet.add(friendList!
          .getRange(i * amountEachRequest,
              min(friendList!.length, (i + 1) * amountEachRequest))
          .map((e) => e.userID)
          .toList());
    }

    final List<List<V2TimUserStatus>> userStatus = await Future.wait([
      ...userIDSet.map((userIDList) async {
        return await _friendshipServices.getUserStatus(userIDList: userIDList);
      })
    ]);

    final List<V2TimUserStatus> flatUserStatus = [];
    for (var e in userStatus) {
      flatUserStatus.addAll(e);
    }
    userStatusList = flatUserStatus;
  }

  loadContactApplicationData() async {
    final newContactRes = await _friendshipServices.getFriendApplicationList();
    // Only Received Application
    _friendApplicationList = newContactRes?.friendApplicationList
        ?.where((item) =>
            item!.type ==
            FriendApplicationTypeEnum.V2TIM_FRIEND_APPLICATION_COME_IN.index)
        .toList();
    _friendApplicationAmount = newContactRes?.unreadCount ?? 0;
    notifyListeners();
  }

  Future<void> markFriendApplicationAsRead() async {
    final res = await _friendshipServices.setFriendApplicationRead();
    if (res.code == 0) {
      _friendApplicationAmount = 0;
      notifyListeners();
    }
    await loadContactApplicationData();
  }

  Future<void> loadContactListData() async {
    if (_loadingContactListFuture != null) {
      return _loadingContactListFuture!;
    }
    _loadingContactListFuture = _loadContactListDataInternal();
    try {
      await _loadingContactListFuture;
    } finally {
      _loadingContactListFuture = null;
    }
  }

  /// 强制重新拉取通讯录（好友关系变更后避免命中进行中的旧请求）。
  Future<void> reloadContactListData() async {
    _contactListLoadGeneration++;
    _loadingContactListFuture = null;
    await loadContactListData();
  }

  /// 进入通讯录等数据源时先灌本地 SQLite 快照，避免等网络再出列表。
  bool applyLocalFriendSnapshot(List<V2TimFriendInfo> memberList) {
    if (memberList.isEmpty) {
      return false;
    }
    _friendList = filterFriendListForPickers(memberList);
    _hasLoadedContactList = true;
    _isLoadingContactList = false;
    notifyListeners();
    return true;
  }

  /// 乐观成友后立即写入通讯录快照，避免 reload 竞态窗口内列表缺人。
  void upsertFriendLocally(V2TimFriendInfo info) {
    final userID = info.userID.trim();
    if (userID.isEmpty) {
      return;
    }
    final current = List<V2TimFriendInfo>.from(_friendList ?? const []);
    final idx = current.indexWhere((item) => item.userID.trim() == userID);
    if (idx >= 0) {
      current[idx] = info;
    } else {
      current.add(info);
    }
    _friendList = filterFriendListForPickers(current);
    _hasLoadedContactList = true;
    notifyListeners();
  }

  Future<void> _loadContactListDataInternal() async {
    final generation = _contactListLoadGeneration;
    final notifyLoading = !_hasLoadedContactList;
    _isLoadingContactList = true;
    if (notifyLoading) {
      notifyListeners();
    }
    try {
      final res = await _friendshipServices.getFriendList();
      if (generation != _contactListLoadGeneration) {
        return;
      }
      if (res == null) {
        return;
      }
      final memberList =
          await _contactListLifeCycle?.friendListWillMount(res) ?? res;
      if (generation != _contactListLoadGeneration) {
        return;
      }
      // 自托管备注以好友库为准：空备注表示已清空，不能走 IM「空备注不降级」把旧备注留在 Store。
      if (!SelfHostedFriendshipBridge.enabled) {
        for (final info in memberList) {
          final userID = info.userID.trim();
          if (userID.isEmpty) {
            continue;
          }
          final remark = info.friendRemark?.trim() ?? '';
          final nickName = info.userProfile?.nickName?.trim() ?? '';
          DisplayNameStore.instance.applyImFriendShowName(
            userID: userID,
            imRemark: remark,
            imNickName: nickName,
            notify: false,
          );
        }
      }
      _friendList = filterFriendListForPickers(memberList);
      _hasLoadedContactList = true;
      try {
        serviceLocator<TUIConversationViewModel>().reapplyDisplayNameOverrides();
      } catch (_) {}
    } finally {
      if (generation == _contactListLoadGeneration) {
        _isLoadingContactList = false;
        notifyListeners();
      }
    }
    return;
  }

  Future<bool> isFriend(String userID) async {
    if (SelfHostedFriendshipBridge.enabled) {
      return SelfHostedFriendshipBridge.isFriend(userID);
    }
    final List<V2TimFriendInfo> res =
        await _friendshipServices.getFriendList() ?? [];
    for (V2TimFriendInfo info in res) {
      if (info.userID == userID) {
        return true;
      }
    }

    return false;
  }

  Future<void> loadBlockListData() async {
    final blockListRes = await _friendshipServices.getBlackList();
    _blockList = blockListRes ?? [];
    notifyListeners();
    return;
  }

  loadGroupListData() async {
    final groupListRes = await _groupServices.getJoinedGroupList();
    _groupList = groupListRes ?? [];
    _applyGroupNameOverrides();
    if (_groupList != null && _groupList!.isNotEmpty) {
      notifyListeners();
    }
    return;
  }

  Future<List<V2TimFriendOperationResult>?> deleteFromBlockList(
      List<String> userIDList) async {
    if (_blockListLifeCycle?.shouldDeleteFromBlockList != null &&
        await _blockListLifeCycle!.shouldDeleteFromBlockList(userIDList) ==
            false) {
      return null;
    }
    final res =
        await _friendshipServices.deleteFromBlackList(userIDList: userIDList);
    if (res != null) {
      return res;
    }
    return null;
  }

  Future<V2TimFriendOperationResult?> acceptFriendApplication(
    String userID,
    int type,
  ) async {
    if (_newContactLifeCycle?.shouldAcceptContactApplication != null &&
        await _newContactLifeCycle!.shouldAcceptContactApplication(userID) ==
            false) {
      return null;
    }
    final res = await _friendshipServices.acceptFriendApplication(
      responseType: FriendResponseTypeEnum.V2TIM_FRIEND_ACCEPT_AGREE_AND_ADD,
      type: FriendApplicationTypeEnum.values[type],
      userID: userID,
    );
    if (res != null) {
      return res;
    }
    return null;
  }

  Future<V2TimFriendOperationResult?> refuseFriendApplication(
    String userID,
    int type,
  ) async {
    if (_newContactLifeCycle?.shouldRefuseContactApplication != null &&
        await _newContactLifeCycle!.shouldRefuseContactApplication(userID) ==
            false) {
      return null;
    }
    final res = await _friendshipServices.refuseFriendApplication(
      type: FriendApplicationTypeEnum.values[type],
      userID: userID,
    );
    if (res != null) {
      return res;
    }
    return null;
  }

  Future<List<V2TimGroupMemberFullInfo?>> getGroupMembersInfo(
      {required String groupID, required List<String> memberList}) async {
    final res = await _groupServices.getGroupMembersInfo(
        groupID: groupID, memberList: memberList);
    return res.data ?? [];
  }

  addFriendListener({V2TimFriendshipListener? listener}) {
    _friendshipServices.addFriendListener(listener: friendShipListener);
  }

  removeFriendshipListener({V2TimFriendshipListener? listener}) {
    _friendshipServices.removeFriendListener(listener: friendShipListener);
  }
}
