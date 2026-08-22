import 'package:tencent_chat_i18n_tool/tencent_chat_i18n_tool.dart';
import 'package:tencent_cloud_chat_sdk/enum/V2TimFriendshipListener.dart';
import 'package:tencent_cloud_chat_sdk/enum/friend_application_type_enum.dart';
import 'package:tencent_cloud_chat_sdk/enum/friend_response_type_enum.dart';
import 'package:tencent_cloud_chat_sdk/enum/friend_type_enum.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_callback.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_callback.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_friend_application_result.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_friend_application_result.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_friend_check_result.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_friend_check_result.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_friend_info.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_friend_info.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_friend_info_result.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_friend_info_result.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_friend_operation_result.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_friend_operation_result.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_friend_search_param.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_friend_search_param.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_user_full_info.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_user_full_info.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_user_status.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_user_status.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_value_callback.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_value_callback.dart';
import 'package:tencent_cloud_chat_sdk/tencent_im_sdk_plugin.dart';
import 'package:tencent_cloud_chat_uikit/base_widgets/tim_callback.dart';
import 'package:tencent_cloud_chat_uikit/data_services/core/core_services_implements.dart';
import 'package:tencent_cloud_chat_uikit/data_services/friendShip/friendship_services.dart';
import 'package:tencent_cloud_chat_uikit/data_services/friendShip/self_hosted_friendship_bridge.dart';
import 'package:tencent_cloud_chat_uikit/data_services/profile/user_profile_local_bridge.dart';
import 'package:tencent_cloud_chat_uikit/data_services/services_locatar.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/error_message_converter.dart';

class FriendshipServicesImpl implements FriendshipServices {
  final CoreServicesImpl _coreService = serviceLocator<CoreServicesImpl>();

  @override
  Future<List<V2TimFriendInfoResult>?> getFriendsInfo({
    required List<String> userIDList,
  }) async {
    final hostedById = await _loadHostedFriendMap();
    if (SelfHostedFriendshipBridge.enabled) {
      final results = <V2TimFriendInfoResult>[];
      for (final uid in userIDList) {
        final id = uid.trim();
        if (id.isEmpty) {
          continue;
        }
        final hosted = hostedById[id];
        final relationType =
            await SelfHostedFriendshipBridge.resolveFriendResultType(id);
        results.add(
          V2TimFriendInfoResult(
            resultCode: 0,
            resultInfo: '',
            relation: relationType,
            friendInfo: hosted ?? V2TimFriendInfo(userID: id),
          ),
        );
      }
      return results;
    }
    final res = await TencentImSDKPlugin.v2TIMManager
        .getFriendshipManager()
        .getFriendsInfo(userIDList: userIDList);
    if (res.code == 0 && res.data != null) {
      if (hostedById.isNotEmpty) {
        for (final item in res.data!) {
          final uid = item.friendInfo?.userID.trim() ?? '';
          final hosted = hostedById[uid];
          if (hosted == null) {
            continue;
          }
          item.friendInfo = _mergeHostedFriendInfo(item.friendInfo, hosted);
        }
      }
      return res.data;
    }
    if (hostedById.isEmpty) {
      _coreService.callOnCallback(TIMCallback(
          type: TIMCallbackType.API_ERROR, errorMsg: res.desc, errorCode: res.code));
      return null;
    }
    return userIDList
        .map((uid) {
          final id = uid.trim();
          final hosted = hostedById[id];
          return V2TimFriendInfoResult(
            resultCode: hosted != null ? 0 : res.code,
            resultInfo: hosted != null ? '' : res.desc,
            relation: _hostedRelationType(hosted),
            friendInfo: hosted ?? V2TimFriendInfo(userID: id),
          );
        })
        .toList(growable: false);
  }

  @override
  Future<List<V2TimUserFullInfo>?> getUsersInfo({
    required List<String> userIDList,
  }) async {
    final res = await TencentImSDKPlugin.v2TIMManager.getUsersInfo(userIDList: userIDList);
    if (res.code == 0) {
      final data = res.data;
      if (data != null) {
        for (final item in data) {
          await UserProfileLocalBridge.saveUserInfo(item);
        }
      }
      return data;
    } else {
      _coreService
          .callOnCallback(TIMCallback(type: TIMCallbackType.API_ERROR, errorMsg: res.desc, errorCode: res.code));
      return null;
    }
  }

  @override
  Future<List<V2TimFriendOperationResult>?> addToBlackList({
    required List<String> userIDList,
  }) async {
    final res = await TencentImSDKPlugin.v2TIMManager.getFriendshipManager().addToBlackList(userIDList: userIDList);
    if (res.code == 0) {
      return res.data;
    } else {
      _coreService
          .callOnCallback(TIMCallback(type: TIMCallbackType.API_ERROR, errorMsg: res.desc, errorCode: res.code));
      return null;
    }
  }

  @override
  Future<V2TimValueCallback<V2TimFriendOperationResult>> addFriend({
    required String userID,
    required FriendTypeEnum addType,
    String? remark,
    String? friendGroup,
    String? addSource,
    String? addWording,
  }) async {
    if (SelfHostedFriendshipBridge.enabled) {
      return _addFriendViaSelfHostedBackend(
        userID: userID,
        addSource: addSource,
        addWording: addWording,
      );
    }

    final result = await TencentImSDKPlugin.v2TIMManager.getFriendshipManager().addFriend(
          userID: userID,
          addType: addType,
          remark: remark,
          addWording: addWording,
          friendGroup: friendGroup,
          addSource: addSource,
        );
    if (result.code != 0) {
      _coreService.callOnCallback(TIMCallback(
        type: TIMCallbackType.API_ERROR,
        errorMsg: result.desc,
        errorCode: result.code,
        infoRecommendText: TIM_t("好友添加失败"),
      ));
    } else if (result.code == 0 && result.data?.resultCode != 0) {
      String recommendText = "";
      if (result.data != null && result.data!.resultCode != null) {
        recommendText = ErrorMessageConverter.getErrorMessage(
            result.data!.resultCode!, result.data?.resultInfo);
      }

      _coreService.callOnCallback(TIMCallback(
        type: TIMCallbackType.API_ERROR,
        errorMsg: result.code == 0 ? result.data?.resultInfo : result.desc,
        errorCode: result.code == 0 ? result.data?.resultCode : result.code,
        infoRecommendText: recommendText,
      ));
    } else {
      _coreService.callOnCallback(TIMCallback(
        type: TIMCallbackType.API_ERROR,
        errorMsg: result.desc,
        errorCode: result.code,
        infoRecommendText: TIM_t("好友添加成功"),
      ));
    }

    return result;
  }

  Future<V2TimValueCallback<V2TimFriendOperationResult>>
      _addFriendViaSelfHostedBackend({
    required String userID,
    String? addSource,
    String? addWording,
  }) async {
    final peer = userID.trim();
    if (peer.isEmpty) {
      return V2TimValueCallback<V2TimFriendOperationResult>(
        code: 1,
        desc: TIM_t("好友添加失败"),
        data: V2TimFriendOperationResult(
          userID: userID,
          resultCode: 1,
          resultInfo: TIM_t("好友添加失败"),
        ),
      );
    }

    try {
      final request = await SelfHostedFriendshipBridge.createFriendRequest(
        userID: peer,
        addSource: addSource,
        addWording: addWording,
      );
      final operationCode = request.isPending ? 30539 : 0;
      final operationInfo = request.isPending
          ? TIM_t("好友申请已发送")
          : request.isRestored
              ? TIM_t("已恢复好友关系")
              : TIM_t("好友添加成功");
      final result = V2TimValueCallback<V2TimFriendOperationResult>(
        code: 0,
        desc: 'OK',
        data: V2TimFriendOperationResult(
          userID: peer,
          resultCode: operationCode,
          resultInfo: operationInfo,
        ),
      );
      _coreService.callOnCallback(TIMCallback(
        type: TIMCallbackType.API_ERROR,
        errorCode: operationCode,
        infoRecommendText: operationInfo,
      ));
      return result;
    } catch (e) {
      final message = e.toString();
      _coreService.callOnCallback(TIMCallback(
        type: TIMCallbackType.API_ERROR,
        errorMsg: message,
        errorCode: 1,
        infoRecommendText: TIM_t("好友添加失败"),
      ));
      return V2TimValueCallback<V2TimFriendOperationResult>(
        code: 1,
        desc: message,
        data: V2TimFriendOperationResult(
          userID: peer,
          resultCode: 1,
          resultInfo: message,
        ),
      );
    }
  }

  @override
  Future<List<V2TimFriendOperationResult>?> deleteFromBlackList({
    required List<String> userIDList,
  }) async {
    final res =
        await TencentImSDKPlugin.v2TIMManager.getFriendshipManager().deleteFromBlackList(userIDList: userIDList);
    if (res.code == 0) {
      return res.data;
    } else {
      _coreService
          .callOnCallback(TIMCallback(type: TIMCallbackType.API_ERROR, errorMsg: res.desc, errorCode: res.code));
      return null;
    }
  }

  @override
  Future<List<V2TimFriendOperationResult>?> deleteFromFriendList({
    required List<String> userIDList,
    required FriendTypeEnum deleteType,
  }) async {
    if (SelfHostedFriendshipBridge.enabled) {
      try {
        for (final userID in userIDList) {
          await SelfHostedFriendshipBridge.deleteFriend(userID);
        }
        _coreService.callOnCallback(TIMCallback(
          type: TIMCallbackType.API_ERROR,
          errorCode: 0,
          infoRecommendText: TIM_t("好友删除成功"),
        ));
        return userIDList
            .map(
              (userID) => V2TimFriendOperationResult(
                userID: userID,
                resultCode: 0,
              ),
            )
            .toList(growable: false);
      } catch (e) {
        _coreService.callOnCallback(TIMCallback(
          type: TIMCallbackType.API_ERROR,
          errorMsg: e.toString(),
          infoRecommendText: TIM_t("好友删除失败"),
        ));
        return null;
      }
    }
    final res = await TencentImSDKPlugin.v2TIMManager
        .getFriendshipManager()
        .deleteFromFriendList(userIDList: userIDList, deleteType: deleteType);
    if (res.code == 0) {
      _coreService.callOnCallback(TIMCallback(
          type: TIMCallbackType.API_ERROR,
          errorMsg: res.desc,
          errorCode: res.code,
          infoRecommendText: TIM_t("好友删除成功")));
      return res.data;
    } else {
      _coreService.callOnCallback(TIMCallback(
          type: TIMCallbackType.API_ERROR,
          errorMsg: res.desc,
          errorCode: res.code,
          infoRecommendText: TIM_t("好友删除失败")));
      return null;
    }
  }

  @override
  Future<List<V2TimFriendInfo>?> getFriendList() async {
    if (SelfHostedFriendshipBridge.enabled) {
      try {
        return await SelfHostedFriendshipBridge.loadFriendList();
      } catch (e) {
        _coreService.callOnCallback(TIMCallback(
          type: TIMCallbackType.API_ERROR,
          errorMsg: e.toString(),
        ));
        return null;
      }
    }
    final res = await TencentImSDKPlugin.v2TIMManager.getFriendshipManager().getFriendList();
    if (res.code == 0) {
      return res.data;
    } else {
      _coreService
          .callOnCallback(TIMCallback(type: TIMCallbackType.API_ERROR, errorMsg: res.desc, errorCode: res.code));
      return null;
    }
  }

  @override
  Future<List<V2TimFriendInfo>?> getBlackList() async {
    final res = await TencentImSDKPlugin.v2TIMManager.getFriendshipManager().getBlackList();
    if (res.code == 0) {
      return res.data;
    } else {
      _coreService
          .callOnCallback(TIMCallback(type: TIMCallbackType.API_ERROR, errorMsg: res.desc, errorCode: res.code));
      return null;
    }
  }

  @override
  Future<List<V2TimFriendCheckResult>?> checkFriend({
    required List<String> userIDList,
    required FriendTypeEnum checkType,
  }) async {
    if (SelfHostedFriendshipBridge.enabled) {
      final results = <V2TimFriendCheckResult>[];
      for (final uid in userIDList) {
        final id = uid.trim();
        if (id.isEmpty) {
          continue;
        }
        final resultType =
            await SelfHostedFriendshipBridge.resolveFriendResultType(id);
        results.add(
          V2TimFriendCheckResult(
            userID: id,
            resultCode: 0,
            resultType: resultType,
          ),
        );
      }
      return results;
    }
    final res = await TencentImSDKPlugin.v2TIMManager
        .getFriendshipManager()
        .checkFriend(userIDList: userIDList, checkType: checkType);
    if (res.code == 0) {
      return res.data;
    } else {
      _coreService
          .callOnCallback(TIMCallback(type: TIMCallbackType.API_ERROR, errorMsg: res.desc, errorCode: res.code));
      return null;
    }
  }

  @override
  Future<void> addFriendListener({
    required V2TimFriendshipListener listener,
  }) {
    return TencentImSDKPlugin.v2TIMManager.getFriendshipManager().addFriendListener(listener: listener);
  }

  @override
  Future<void> removeFriendListener({
    V2TimFriendshipListener? listener,
  }) {
    return TencentImSDKPlugin.v2TIMManager.getFriendshipManager().removeFriendListener(listener: listener);
  }

  @override
  Future<V2TimFriendApplicationResult?> getFriendApplicationList() async {
    final res = await TencentImSDKPlugin.v2TIMManager.getFriendshipManager().getFriendApplicationList();
    if (res.code == 0) {
      return res.data;
    } else {
      _coreService
          .callOnCallback(TIMCallback(type: TIMCallbackType.API_ERROR, errorMsg: res.desc, errorCode: res.code));
      return null;
    }
  }

  @override
  Future<V2TimCallback> setFriendApplicationRead() async {
    return TencentImSDKPlugin.v2TIMManager
        .getFriendshipManager()
        .setFriendApplicationRead();
  }

  @override
  Future<V2TimFriendOperationResult?> acceptFriendApplication({
    required FriendResponseTypeEnum responseType,
    required FriendApplicationTypeEnum type,
    required String userID,
  }) async {
    final res = await TencentImSDKPlugin.v2TIMManager.getFriendshipManager().acceptFriendApplication(
          responseType: responseType,
          type: type,
          userID: userID,
        );
    if (res.code == 0) {
      return res.data;
    } else {
      if (!ErrorMessageConverter.isLastRequestRunningError(res.desc)) {
        _coreService.callOnCallback(
            TIMCallback(type: TIMCallbackType.API_ERROR, errorMsg: res.desc, errorCode: res.code));
      }
      return null;
    }
  }

  @override
  Future<V2TimFriendOperationResult?> refuseFriendApplication(
      {required FriendApplicationTypeEnum type, required String userID}) async {
    final res = await TencentImSDKPlugin.v2TIMManager
        .getFriendshipManager()
        .refuseFriendApplication(type: type, userID: userID);
    if (res.code == 0) {
      return res.data;
    } else {
      if (!ErrorMessageConverter.isLastRequestRunningError(res.desc)) {
        _coreService.callOnCallback(
            TIMCallback(type: TIMCallbackType.API_ERROR, errorMsg: res.desc, errorCode: res.code));
      }
      return null;
    }
  }

  @override
  Future<V2TimCallback> setFriendInfo({
    required String userID,
    String? friendRemark,
    Map<String, String>? friendCustomInfo,
  }) async {
    if (SelfHostedFriendshipBridge.enabled && friendRemark != null) {
      try {
        await SelfHostedFriendshipBridge.updateRemark(
          userID: userID,
          remark: friendRemark,
        );
        return V2TimCallback(code: 0, desc: '');
      } catch (e) {
        final msg = e.toString();
        _coreService.callOnCallback(TIMCallback(
          type: TIMCallbackType.API_ERROR,
          errorMsg: msg,
        ));
        return V2TimCallback(code: -1, desc: msg);
      }
    }
    final res = await TencentImSDKPlugin.v2TIMManager
        .getFriendshipManager()
        .setFriendInfo(friendRemark: friendRemark, friendCustomInfo: friendCustomInfo, userID: userID);
    if (res.code != 0) {
      _coreService
          .callOnCallback(TIMCallback(type: TIMCallbackType.API_ERROR, errorMsg: res.desc, errorCode: res.code));
    }
    return res;
  }

  @override
  Future<List<V2TimFriendInfoResult>?> searchFriends({
    required V2TimFriendSearchParam searchParam,
  }) async {
    if (SelfHostedFriendshipBridge.enabled) {
      return _searchHostedFriends(searchParam);
    }
    final res = await TencentImSDKPlugin.v2TIMManager.getFriendshipManager().searchFriends(searchParam: searchParam);
    if (res.code == 0) {
      return res.data;
    } else {
      _coreService
          .callOnCallback(TIMCallback(type: TIMCallbackType.API_ERROR, errorMsg: res.desc, errorCode: res.code));
      return null;
    }
  }

  Future<List<V2TimFriendInfoResult>> _searchHostedFriends(
    V2TimFriendSearchParam searchParam,
  ) async {
    final keywords = _normalizeSearchKeywords(searchParam);
    if (keywords.isEmpty) {
      return const <V2TimFriendInfoResult>[];
    }

    try {
      final imFuture = TencentImSDKPlugin.v2TIMManager
          .getFriendshipManager()
          .searchFriends(searchParam: searchParam);
      final networkFuture =
          SelfHostedFriendshipBridge.loadFriendListFromNetwork();

      final imRes = await imFuture;
      final networkFriends = await networkFuture;
      final networkFriendIds = networkFriends
          .map((friend) => friend.userID.trim())
          .where((id) => id.isNotEmpty)
          .toSet();
      final byUserId = <String, V2TimFriendInfoResult>{};

      if (imRes.code == 0 && imRes.data != null) {
        for (final item in imRes.data!) {
          final id = item.friendInfo?.userID?.trim() ?? '';
          // 自托管好友以服务端列表为准；IM SDK 本地库删除后可能仍残留。
          if (id.isNotEmpty && networkFriendIds.contains(id)) {
            byUserId[id] = item;
          }
        }
      } else if (imRes.code != 0) {
        _coreService.callOnCallback(TIMCallback(
          type: TIMCallbackType.API_ERROR,
          errorMsg: imRes.desc,
          errorCode: imRes.code,
        ));
      }

      for (final friend in networkFriends) {
        if (!_hostedFriendMatchesSearch(friend, searchParam, keywords)) {
          continue;
        }
        final id = friend.userID.trim();
        if (id.isEmpty) {
          continue;
        }
        final existing = byUserId[id]?.friendInfo;
        byUserId[id] = V2TimFriendInfoResult(
          resultCode: 0,
          resultInfo: '',
          relation: _hostedRelationType(friend),
          friendInfo: _mergeHostedFriendInfo(existing, friend),
        );
      }

      return byUserId.values.toList(growable: false);
    } catch (e) {
      _coreService.callOnCallback(TIMCallback(
        type: TIMCallbackType.API_ERROR,
        errorMsg: e.toString(),
      ));
      return const <V2TimFriendInfoResult>[];
    }
  }

  List<String> _normalizeSearchKeywords(V2TimFriendSearchParam searchParam) {
    return searchParam.keywordList
        .map((keyword) => keyword.trim().toLowerCase())
        .where((keyword) => keyword.isNotEmpty)
        .toList(growable: false);
  }

  bool _hostedFriendMatchesSearch(
    V2TimFriendInfo friend,
    V2TimFriendSearchParam searchParam,
    List<String> keywords,
  ) {
    final userId = friend.userID.trim().toLowerCase();
    final remark = (friend.friendRemark ?? '').trim().toLowerCase();
    final nickName = (friend.userProfile?.nickName ?? '').trim().toLowerCase();

    for (final keyword in keywords) {
      var matched = false;
      if (searchParam.isSearchUserID && userId.contains(keyword)) {
        matched = true;
      }
      if (!matched && searchParam.isSearchRemark && remark.contains(keyword)) {
        matched = true;
      }
      if (!matched && searchParam.isSearchNickName && nickName.contains(keyword)) {
        matched = true;
      }
      if (matched) {
        return true;
      }
    }
    return false;
  }

  @override
  Future<List<V2TimUserStatus>> getUserStatus({
    required List<String> userIDList,
  }) async {
    final res = await TencentImSDKPlugin.v2TIMManager.getUserStatus(userIDList: userIDList);
    if (res.code == 0) {
      return res.data ?? [];
    } else {
      _coreService
          .callOnCallback(TIMCallback(type: TIMCallbackType.API_ERROR, errorMsg: res.desc, errorCode: res.code));
      return [];
    }
  }

  Future<Map<String, V2TimFriendInfo>> _loadHostedFriendMap() async {
    if (!SelfHostedFriendshipBridge.enabled) {
      return {};
    }
    try {
      final hostedFriends = await SelfHostedFriendshipBridge.loadFriendList();
      final out = <String, V2TimFriendInfo>{};
      for (final item in hostedFriends) {
        final id = item.userID.trim();
        if (id.isNotEmpty) {
          out[id] = item;
        }
      }
      return out;
    } catch (_) {
      return {};
    }
  }

  int _hostedRelationType(V2TimFriendInfo? hosted) {
    if (hosted == null) {
      return 0;
    }
    final canMessage = hosted.friendCustomInfo?['canMessage'] == '1';
    return canMessage ? 3 : 1;
  }

  V2TimFriendInfo _mergeHostedFriendInfo(
    V2TimFriendInfo? current,
    V2TimFriendInfo hosted,
  ) {
    if (current == null) {
      return hosted;
    }
    final remark = hosted.friendRemark?.trim() ?? '';
    if (remark.isNotEmpty) {
      current.friendRemark = remark;
    }
    final hostedCustom = hosted.friendCustomInfo;
    if (hostedCustom != null && hostedCustom.isNotEmpty) {
      current.friendCustomInfo = <String, String>{
        ...?current.friendCustomInfo,
        ...hostedCustom,
      };
    }
    final hostedProfile = hosted.userProfile;
    if (hostedProfile != null) {
      current.userProfile ??= V2TimUserFullInfo(userID: current.userID);
      final profile = current.userProfile!;
      final nick = hostedProfile.nickName?.trim() ?? '';
      if (nick.isNotEmpty) {
        profile.nickName = nick;
      }
      final faceUrl = hostedProfile.faceUrl?.trim() ?? '';
      if (faceUrl.isNotEmpty) {
        profile.faceUrl = faceUrl;
      }
    }
    return current;
  }
}
