// ignore_for_file: avoid_print

import 'package:flutter/material.dart';
import 'package:tencent_cloud_chat_sdk/enum/friend_type_enum.dart';
import 'package:tencent_cloud_chat_sdk/enum/receive_message_opt_enum.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_callback.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_callback.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_conversation.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_conversation.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_friend_info.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_friend_info.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_friend_operation_result.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_friend_operation_result.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_user_full_info.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_user_full_info.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/life_cycle/profile_life_cycle.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/services/display_name_store.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/model/profile_model.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/view_models/tui_friendship_view_model.dart';
import 'package:tencent_cloud_chat_uikit/data_services/conversation/conversation_services.dart';
import 'package:tencent_cloud_chat_uikit/data_services/core/core_services_implements.dart';
import 'package:tencent_cloud_chat_uikit/data_services/friendShip/friendship_services.dart';
import 'package:tencent_cloud_chat_uikit/data_services/message/message_services.dart';
import 'package:tencent_cloud_chat_uikit/data_services/profile/user_profile_local_bridge.dart';
import 'package:tencent_cloud_chat_uikit/data_services/services_locatar.dart';

class TUIProfileViewModel extends ChangeNotifier {
  final ConversationService _conversationService =
      serviceLocator<ConversationService>();
  final FriendshipServices _friendshipServices =
      serviceLocator<FriendshipServices>();
  final TUIFriendShipViewModel _friendShipViewModel =
      serviceLocator<TUIFriendShipViewModel>();
  final CoreServicesImpl _coreServices = serviceLocator<CoreServicesImpl>();
  final MessageService _messageService = serviceLocator<MessageService>();

  UserProfile? _userProfile;
  ProfileLifeCycle? _lifeCycle;
  bool? _shouldAddToBlackList;
  int _friendType = 0;
  bool? _isDisturb;

  UserProfile? get userProfile {
    return _userProfile;
  }

  set userProfile(UserProfile? value) {
    _userProfile = value;
    notifyListeners();
  }

  bool? get isDisturb {
    return _isDisturb;
  }

  bool? get isAddToBlackList {
    return _shouldAddToBlackList;
  }

  int get friendType {
    return _friendType;
  }

  void applyFriendCheckResultType(int resultType) {
    if (resultType == 0 || resultType == _friendType) {
      return;
    }
    _friendType = resultType;
    notifyListeners();
  }

  set lifeCycle(ProfileLifeCycle? value) {
    _lifeCycle = value;
  }

  loadData({required String userID, bool isNeedConversation = true}) async {
    if (userID.isEmpty) {
      return;
    }

    // Sync seed from memory cache so the first Consumer frame can paint
    // nick/avatar instead of loading dots when the peer was seen recently.
    final existingId = _userProfile?.friendInfo?.userID?.trim() ?? '';
    if (existingId != userID) {
      final snap = UserProfileLocalBridge.readCached(userID);
      if (snap != null) {
        final avatar = snap.avatarUrl.trim();
        final nick = snap.nickname.trim();
        final remark = snap.remark.trim();
        if (avatar.isNotEmpty || nick.isNotEmpty || remark.isNotEmpty) {
          _userProfile = UserProfile(
            friendInfo: V2TimFriendInfo(
              userID: userID,
              friendRemark: remark.isNotEmpty ? remark : null,
              userProfile: V2TimUserFullInfo(
                userID: userID,
                nickName: nick.isNotEmpty ? nick : null,
                faceUrl: avatar.isNotEmpty ? avatar : null,
              ),
            ),
            conversation: null,
          );
          notifyListeners();
        }
      }
    }

    final conversationFuture = isNeedConversation
        ? _conversationService.getConversation(
            conversationID: "c2c_$userID",
          )
        : Future<V2TimConversation?>.value(null);

    final localFriend = await UserProfileLocalBridge.loadLocal(userID);
    if (localFriend != null) {
      _userProfile = UserProfile(
        friendInfo: localFriend,
        // The profile card does not need conversation metadata to render.
        // Publish the local card before waiting for the SDK conversation query.
        conversation: null,
      );
      if (_friendShipViewModel.friendList
              ?.any((element) => element.userID == userID) ??
          false) {
        if (_friendType == 0) {
          _friendType = 3;
        }
      }
      notifyListeners();
    }

    var conversation = await conversationFuture;
    _isDisturb = conversation?.recvOpt == 2;

    V2TimFriendInfo? friendUserInfo;
    final userInfoList =
        await _friendshipServices.getFriendsInfo(userIDList: [userID]);
    final checkFriend = await _friendshipServices.checkFriend(
      userIDList: [userID],
      checkType: FriendTypeEnum.V2TIM_FRIEND_TYPE_SINGLE,
    );

    if (checkFriend != null) {
      final res = checkFriend.first;
      if (res.resultCode == 0) {
        _friendType = res.resultType;
      }
    }

    if (userInfoList != null) {
      friendUserInfo = userInfoList[0].friendInfo;
    }

    if (isNeedConversation && conversation == null) {
      conversation = await _conversationService.getConversation(
        conversationID: "c2c_$userID",
      );
      _isDisturb = conversation?.recvOpt == 2;
    }

    final imUsersFuture =
        _friendshipServices.getUsersInfo(userIDList: [userID]);
    var friendInfo =
        await _lifeCycle?.didGetFriendInfo(friendUserInfo) ?? friendUserInfo;
    friendInfo = await UserProfileLocalBridge.mergeHostedFriendRemark(
      userID,
      friendInfo,
    );
    final imUser = await _firstImUser(imUsersFuture, userID);
    friendInfo = UserProfileLocalBridge.mergeImPublicProfile(
      userId: userID,
      info: friendInfo,
      im: imUser,
    );
    await UserProfileLocalBridge.saveFriendInfo(friendInfo);
    var display = await UserProfileLocalBridge.loadLocal(userID) ??
        friendInfo ??
        V2TimFriendInfo(userID: userID);
    display = await UserProfileLocalBridge.mergeHostedFriendRemark(
          userID,
          display,
        ) ??
        display;
    display = UserProfileLocalBridge.mergeImPublicProfile(
      userId: userID,
      info: display,
      im: imUser,
    );

    _isDisturb = conversation?.recvOpt == 2;
    _userProfile = UserProfile(
      friendInfo: display,
      conversation: conversation,
    );

    _shouldAddToBlackList = _friendShipViewModel.blockList
            .indexWhere((element) => element.userID == userID) >
        -1;

    notifyListeners();
  }

  Future<V2TimCallback> pinedConversation(bool isPined, String convID) async {
    final res = await _conversationService.pinConversation(
        conversationID: convID, isPinned: isPined);
    _userProfile?.conversation!.isPinned = isPined;
    notifyListeners();
    return res;
  }

  Future<List<V2TimFriendOperationResult>?> addToBlackList(
      bool shouldAdd, String userID) async {
    if (_lifeCycle?.shouldAddToBlockList != null &&
        await _lifeCycle!.shouldAddToBlockList(userID) == false) {
      return null;
    }
    if (shouldAdd) {
      final res =
          await _friendshipServices.addToBlackList(userIDList: [userID]);
      if (res != null && res.isNotEmpty) {
        final result = res.first;
        if (result.resultCode == 0) {
          _shouldAddToBlackList = true;
          _friendType = 0;
        }
      }
      notifyListeners();
      return res;
    } else {
      final res =
          await _friendshipServices.deleteFromBlackList(userIDList: [userID]);
      if (res != null && res.isNotEmpty) {
        final result = res.first;
        if (result.resultCode == 0) {
          _shouldAddToBlackList = false;
          final checkFriend = await _friendshipServices.checkFriend(
              userIDList: [userID],
              checkType: FriendTypeEnum.V2TIM_FRIEND_TYPE_SINGLE);
          if (checkFriend != null) {
            final res = checkFriend.first;
            _friendType = res.resultType;
          }
        }
      }
      _friendShipViewModel.loadBlockListData();
      notifyListeners();
      return res;
    }
  }

  Future<V2TimFriendOperationResult?> deleteFriend(String userID,
      {bool needUpdateData = true}) async {
    if (_lifeCycle?.shouldDeleteFriend != null &&
        await _lifeCycle!.shouldDeleteFriend(userID) == false) {
      return null;
    }
    final res = await _friendshipServices.deleteFromFriendList(
        userIDList: [userID],
        deleteType: FriendTypeEnum.V2TIM_FRIEND_TYPE_BOTH);
    if (res != null) {
      _conversationService.deleteConversation(conversationID: "c2c_$userID");
      if (needUpdateData) {
        loadData(userID: userID);
      }
      return res.first;
    }

    return null;
  }

  Future<V2TimCallback> changeFriendVerificationMethod(int allowType) async {
    V2TimUserFullInfo userFullInfo = V2TimUserFullInfo();
    userFullInfo.allowType = allowType;
    final res = await _coreServices.setSelfInfo(userFullInfo: userFullInfo);
    if (res.code == 0) {
      _userProfile?.friendInfo!.userProfile!.allowType = allowType;
      notifyListeners();
    }
    return res;
  }

  Future<V2TimFriendOperationResult?> addFriend(
    String userID, {
    String? addSource,
  }) async {
    if (_lifeCycle?.shouldAddFriend != null &&
        await _lifeCycle!.shouldAddFriend(userID) == false) {
      return null;
    }
    final res = await _friendshipServices.addFriend(
      userID: userID,
      addType: FriendTypeEnum.V2TIM_FRIEND_TYPE_BOTH,
      addSource: addSource,
    );
    if (res.code == 0) {
      loadData(userID: userID);
      return res.data;
    }

    return null;
  }

  Future<V2TimCallback> updateRemarks(String userID, String remark) async {
    final res = await _friendshipServices.setFriendInfo(
        userID: userID, friendRemark: remark);

    if (res.code == 0) {
      _userProfile?.friendInfo!.friendRemark = remark;
      final nickName =
          _userProfile?.friendInfo?.userProfile?.nickName?.trim() ?? '';
      final fallback = nickName.isNotEmpty ? nickName : userID;
      final showName = remark.trim().isNotEmpty ? remark.trim() : fallback;
      _friendShipViewModel.updateFriendRemarkLocal(userID, remark);
      DisplayNameStore.instance.setC2C(userID, showName);
      await UserProfileLocalBridge.saveFriendInfo(_userProfile?.friendInfo);
      notifyListeners();
    }
    return res;
  }

  Future<V2TimCallback> setMessageDisturb(String userID, bool isDisturb) async {
    final res = await _messageService.setC2CReceiveMessageOpt(
        userIDList: [userID],
        opt: isDisturb
            ? ReceiveMsgOptEnum.V2TIM_RECEIVE_NOT_NOTIFY_MESSAGE
            : ReceiveMsgOptEnum.V2TIM_RECEIVE_MESSAGE);
    if (res.code == 0) {
      _isDisturb = isDisturb;
    }
    notifyListeners();
    return res;
  }

  updateUserInfo(V2TimUserFullInfo userFullInfo) {
    if (userFullInfo.nickName != null) {
      _userProfile?.friendInfo!.userProfile?.nickName = userFullInfo.nickName;
    }
    if (userFullInfo.faceUrl != null) {
      _userProfile?.friendInfo!.userProfile?.faceUrl = userFullInfo.faceUrl;
    }
    if (userFullInfo.selfSignature != null) {
      _userProfile?.friendInfo!.userProfile?.selfSignature =
          userFullInfo.selfSignature;
    }
    if (userFullInfo.gender != null) {
      _userProfile?.friendInfo!.userProfile?.gender = userFullInfo.gender;
    }
    if (userFullInfo.allowType != null) {
      _userProfile?.friendInfo!.userProfile?.allowType = userFullInfo.allowType;
    }
    if (userFullInfo.customInfo != null) {
      _userProfile?.friendInfo!.userProfile?.customInfo =
          userFullInfo.customInfo;
    }
    if (userFullInfo.role != null) {
      _userProfile?.friendInfo!.userProfile?.role = userFullInfo.role;
    }
    if (userFullInfo.level != null) {
      _userProfile?.friendInfo!.userProfile?.level = userFullInfo.level;
    }
    if (userFullInfo.birthday != null) {
      _userProfile?.friendInfo!.userProfile?.birthday = userFullInfo.birthday;
    }
  }

  Future<V2TimCallback> updateSelfInfo(V2TimUserFullInfo userFullInfo) async {
    final res = await _coreServices.setSelfInfo(userFullInfo: userFullInfo);

    if (res.code == 0) {
      updateUserInfo(userFullInfo);
      await UserProfileLocalBridge.saveFriendInfo(_userProfile?.friendInfo);
      notifyListeners();
    }

    return res;
  }

  Future<V2TimUserFullInfo?> _firstImUser(
    Future<List<V2TimUserFullInfo>?> pending,
    String userID,
  ) async {
    try {
      final users = await pending;
      if (users == null || users.isEmpty) {
        return null;
      }
      for (final item in users) {
        if ((item.userID ?? '').trim() == userID) {
          return item;
        }
      }
      return users.first;
    } catch (_) {
      return null;
    }
  }
}
