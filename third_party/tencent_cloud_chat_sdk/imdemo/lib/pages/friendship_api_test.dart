import 'package:flutter/material.dart';
import 'package:tencent_cloud_chat_sdk/enum/friend_application_type_enum.dart';
import 'package:tencent_cloud_chat_sdk/enum/friend_response_type_enum.dart';
import 'package:tencent_cloud_chat_sdk/enum/friend_type_enum.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_friend_info.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_friend_info.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_friend_info_result.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_friend_info_result.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_friend_search_param.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_friend_search_param.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_value_callback.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_value_callback.dart';
import 'package:tencent_cloud_chat_sdk/tencent_im_sdk_plugin.dart';
import 'package:tencent_cloud_chat_sdk_example/utils/log_manager.dart';
import 'base_api_test.dart';

class FriendshipAPITest extends StatefulWidget {
  const FriendshipAPITest({Key? key}) : super(key: key);

  @override
  State<FriendshipAPITest> createState() => _FriendshipAPITestState();
}

class _FriendshipAPITestState extends State<FriendshipAPITest> {
  final TextEditingController _userIDController = TextEditingController();
  final TextEditingController _addFriendWithGroupController = TextEditingController();
  final TextEditingController _addWordingController = TextEditingController();
  final TextEditingController _addSourceController = TextEditingController();
  final TextEditingController _addTypeController = TextEditingController(text: '1');
  final TextEditingController _userIDListController = TextEditingController();
  final TextEditingController _deleteTypeController = TextEditingController(text: '1');
  final TextEditingController _checkTypeController = TextEditingController(text: '2');
  final TextEditingController _responseTypeController = TextEditingController(text: '1');
  final TextEditingController _applicationTypeController = TextEditingController(text: '1');
  final TextEditingController _groupNameController = TextEditingController();
  final TextEditingController _oldNameController = TextEditingController();
  final TextEditingController _newNameController = TextEditingController();
  final TextEditingController _officialAccountIDController = TextEditingController();
  final TextEditingController _searchKeywordController = TextEditingController();
  final TextEditingController _searchFriendController = TextEditingController();
  final TextEditingController _friendCustomInfoController = TextEditingController();
  final TextEditingController _friendApplicationRemarkController = TextEditingController();
  final TextEditingController _friendRemarkController = TextEditingController();
  final TextEditingController _friendApplicationIDController = TextEditingController();
  final TextEditingController _followUserListController = TextEditingController();

  // 使用全局日志管理器和监听器管理器
  final LogManager _logManager = LogManager();

  // 搜索选项
  bool isSearchUserID = true;
  bool isSearchNickName = true;
  bool isSearchRemark = true;

  @override
  void initState() {
    super.initState();
    _userIDController.text = 'teacher13';
    _userIDListController.text = 'teacher13,teacher15';
    _groupNameController.text = 'new-group';
    _followUserListController.text = "teacher20,teacher21";
  }

  // 添加日志的帮助方法
  void _addLog(String log) {
    _logManager.updateLogText(log);
  }

  // 清空日志
  void _clearLog() {
    _logManager.clearAllLogs();
  }

  // 获取好友列表
  Future<void> _getFriendList() async {
    try {
      V2TimValueCallback<List<V2TimFriendInfo>> result = await TencentImSDKPlugin.v2TIMManager.getFriendshipManager().getFriendList();
      if (result.code == 0) {
        String friendLog = '';
        for (V2TimFriendInfo friendInfo in result.data!) {
          friendLog += '${friendInfo.toLogString()}\n';
        }
        _addLog('获取好友列表: $friendLog');
      } else {
        _addLog('获取好友列表失败, code: ${result.code}, desc: ${result.desc}');
      }
    } catch (e) {
      _addLog('获取好友列表失败: $e');
    }
  }

  // 获取指定好友资料
  Future<void> _getFriendsInfo() async {
    if (_userIDListController.text.isEmpty) {
      _addLog('请输入用户ID列表，用逗号分隔');
      return;
    }
    try {
      V2TimValueCallback<List<V2TimFriendInfoResult>> result = await TencentImSDKPlugin.v2TIMManager.getFriendshipManager().getFriendsInfo(
        userIDList: _userIDListController.text.split(','),
      );
      if (result.code == 0) {
        String friendLog = '';
        for (V2TimFriendInfoResult friendInfoResult in result.data!) {
          friendLog += '${friendInfoResult.toLogString()}\n\n';
        }
        _addLog('获取指定好友资料: $friendLog');
      } else {
        _addLog('获取指定好友资料失败, code = ${result.code}, desc = ${result.desc}');
      }
    } catch (e) {
      _addLog('获取指定好友资料失败: $e');
    }
  }

  // 设置指定好友资料
  Future<void> _setFriendInfo() async {
    if (_userIDController.text.isEmpty) {
      _addLog('请输入用户ID');
      return;
    }
    try {
      Map<String, String> customInfo = {"Str" : "Str friend value"};
      final result = await TencentImSDKPlugin.v2TIMManager.getFriendshipManager().setFriendInfo(
        userID: _userIDController.text,
        friendRemark: _friendRemarkController.text.isEmpty ? null : _friendRemarkController.text,
        friendCustomInfo: customInfo,
      );
      _addLog('设置指定好友资料成功: ${result.toJson()}');
    } catch (e) {
      _addLog('设置指定好友资料失败: $e');
    }
  }

  // 添加好友
  Future<void> _addFriend() async {
    if (_userIDController.text.isEmpty || _addTypeController.text.isEmpty) {
      _addLog('请输入用户ID和添加类型');
      return;
    }
    try {
      final result = await TencentImSDKPlugin.v2TIMManager.getFriendshipManager().addFriend(
        userID: _userIDController.text,
        remark: _friendApplicationRemarkController.text.isEmpty ? null : _friendApplicationRemarkController.text,
        friendGroup: _addFriendWithGroupController.text.isEmpty ? null : _addFriendWithGroupController.text,
        addWording: _addWordingController.text.isEmpty ? null : _addWordingController.text,
        addSource: _addSourceController.text.isEmpty ? null : _addSourceController.text,
        addType: FriendTypeEnum.values[int.parse(_addTypeController.text)],
      );
      _addLog('添加好友成功: ${result.toJson()}');
    } catch (e) {
      _addLog('添加好友失败: $e');
    }
  }

  // 删除好友
  Future<void> _deleteFromFriendList() async {
    if (_userIDListController.text.isEmpty || _deleteTypeController.text.isEmpty) {
      _addLog('请输入用户ID列表和删除类型');
      return;
    }
    try {
      final result = await TencentImSDKPlugin.v2TIMManager.getFriendshipManager().deleteFromFriendList(
        userIDList: _userIDListController.text.split(','),
        deleteType: FriendTypeEnum.values[int.parse(_deleteTypeController.text)],
      );
      _addLog('删除好友成功: ${result.toJson()}');
    } catch (e) {
      _addLog('删除好友失败: $e');
    }
  }

  // 检查指定用户的好友关系
  Future<void> _checkFriend() async {
    if (_userIDListController.text.isEmpty || _checkTypeController.text.isEmpty) {
      _addLog('请输入用户ID列表和检查类型');
      return;
    }
    try {
      final result = await TencentImSDKPlugin.v2TIMManager.getFriendshipManager().checkFriend(
        userIDList: _userIDListController.text.split(','),
        checkType: FriendTypeEnum.values[int.parse(_checkTypeController.text)],
      );
      _addLog('检查好友关系成功: ${result.toJson()}');
    } catch (e) {
      _addLog('检查好友关系失败: $e');
    }
  }

  // 获取好友申请列表
  Future<void> _getFriendApplicationList() async {
    try {
      final result = await TencentImSDKPlugin.v2TIMManager.getFriendshipManager().getFriendApplicationList();
      _addLog('获取好友申请列表成功: ${result.toJson()}');
    } catch (e) {
      _addLog('获取好友申请列表失败: $e');
    }
  }

  // 同意好友申请
  Future<void> _acceptFriendApplication() async {
    if (_userIDController.text.isEmpty || _responseTypeController.text.isEmpty || _applicationTypeController.text.isEmpty) {
      _addLog('请输入用户ID、响应类型和申请类型');
      return;
    }
    try {
      final result = await TencentImSDKPlugin.v2TIMManager.getFriendshipManager().acceptFriendApplication(
        responseType: FriendResponseTypeEnum.values[int.parse(_responseTypeController.text)],
        type: FriendApplicationTypeEnum.values[int.parse(_applicationTypeController.text)],
        userID: _userIDController.text,
      );
      _addLog('同意好友申请成功: ${result.toJson()}');
    } catch (e) {
      _addLog('同意好友申请失败: $e');
    }
  }

  // 拒绝好友申请
  Future<void> _refuseFriendApplication() async {
    if (_userIDController.text.isEmpty || _applicationTypeController.text.isEmpty) {
      _addLog('请输入用户ID和申请类型');
      return;
    }
    try {
      final result = await TencentImSDKPlugin.v2TIMManager.getFriendshipManager().refuseFriendApplication(
        type: FriendApplicationTypeEnum.values[int.parse(_applicationTypeController.text)],
        userID: _userIDController.text,
      );
      _addLog('拒绝好友申请成功: ${result.toJson()}');
    } catch (e) {
      _addLog('拒绝好友申请失败: $e');
    }
  }

  // 删除好友申请
  Future<void> _deleteFriendApplication() async {
    if (_userIDController.text.isEmpty || _applicationTypeController.text.isEmpty) {
      _addLog('请输入用户ID和申请类型');
      return;
    }
    try {
      final result = await TencentImSDKPlugin.v2TIMManager.getFriendshipManager().deleteFriendApplication(
        type: FriendApplicationTypeEnum.values[int.parse(_applicationTypeController.text)],
        userID: _userIDController.text,
      );
      _addLog('删除好友申请成功: ${result.toJson()}');
    } catch (e) {
      _addLog('删除好友申请失败: $e');
    }
  }

  // 设置好友申请已读
  Future<void> _setFriendApplicationRead() async {
    try {
      final result = await TencentImSDKPlugin.v2TIMManager.getFriendshipManager().setFriendApplicationRead();
      _addLog('设置好友申请已读成功: ${result.toJson()}');
    } catch (e) {
      _addLog('设置好友申请已读失败: $e');
    }
  }

  // 添加用户到黑名单
  Future<void> _addToBlackList() async {
    if (_userIDListController.text.isEmpty) {
      _addLog('请输入用户ID列表，用逗号分隔');
      return;
    }
    try {
      final result = await TencentImSDKPlugin.v2TIMManager.getFriendshipManager().addToBlackList(
        userIDList: _userIDListController.text.split(','),
      );
      _addLog('添加用户到黑名单成功: ${result.toJson()}');
    } catch (e) {
      _addLog('添加用户到黑名单失败: $e');
    }
  }

  // 把用户从黑名单中删除
  Future<void> _deleteFromBlackList() async {
    if (_userIDListController.text.isEmpty) {
      _addLog('请输入用户ID列表，用逗号分隔');
      return;
    }
    try {
      final result = await TencentImSDKPlugin.v2TIMManager.getFriendshipManager().deleteFromBlackList(
        userIDList: _userIDListController.text.split(','),
      );
      _addLog('把用户从黑名单中删除: ${result.toJson()}');
    } catch (e) {
      _addLog('把用户从黑名单中删除失败: $e');
    }
  }

  // 获取黑名单列表
  Future<void> _getBlackList() async {
    try {
      V2TimValueCallback<List<V2TimFriendInfo>> result = await TencentImSDKPlugin.v2TIMManager.getFriendshipManager().getBlackList();
      if (result.code == 0) {
        String friendLog = '';
        for (V2TimFriendInfo friendInfo in result.data!) {
          friendLog += '${friendInfo.toLogString()}\n';
        }
        _addLog('获取黑名单列表: $friendLog');
      } else {
        _addLog('获取黑名单列表失败，code: ${result.code}, desc: ${result.desc}');
      }
    } catch (e) {
      _addLog('获取黑名单列表失败: $e');
    }
  }

  // 新建好友分组
  Future<void> _createFriendGroup() async {
    if (_groupNameController.text.isEmpty) {
      _addLog('请输入分组名称');
      return;
    }
    try {
      final result = await TencentImSDKPlugin.v2TIMManager.getFriendshipManager().createFriendGroup(
        groupName: _groupNameController.text,
        userIDList: _userIDListController.text.isEmpty ? null : _userIDListController.text.split(','),
      );
      _addLog('新建好友分组成功: ${result.toJson()}');
    } catch (e) {
      _addLog('新建好友分组失败: $e');
    }
  }

  // 获取分组信息
  Future<void> _getFriendGroups() async {
    try {
      final result = await TencentImSDKPlugin.v2TIMManager.getFriendshipManager().getFriendGroups(
        groupNameList: _groupNameController.text.isEmpty ? null : [_groupNameController.text],
      );
      _addLog('获取分组信息成功: ${result.toJson()}');
    } catch (e) {
      _addLog('获取分组信息失败: $e');
    }
  }

  // 删除好友分组
  Future<void> _deleteFriendGroup() async {
    if (_groupNameController.text.isEmpty) {
      _addLog('请输入分组名称');
      return;
    }
    try {
      final result = await TencentImSDKPlugin.v2TIMManager.getFriendshipManager().deleteFriendGroup(
        groupNameList: [_groupNameController.text],
      );
      _addLog('删除好友分组成功: ${result.toJson()}');
    } catch (e) {
      _addLog('删除好友分组失败: $e');
    }
  }

  // 修改好友分组的名称
  Future<void> _renameFriendGroup() async {
    if (_oldNameController.text.isEmpty || _newNameController.text.isEmpty) {
      _addLog('请输入原分组名称和新分组名称');
      return;
    }
    try {
      final result = await TencentImSDKPlugin.v2TIMManager.getFriendshipManager().renameFriendGroup(
        oldName: _oldNameController.text,
        newName: _newNameController.text,
      );
      _addLog('修改好友分组的名称成功: ${result.toJson()}');
    } catch (e) {
      _addLog('修改好友分组的名称失败: $e');
    }
  }

  // 添加好友到一个好友分组
  Future<void> _addFriendsToFriendGroup() async {
    if (_groupNameController.text.isEmpty || _userIDListController.text.isEmpty) {
      _addLog('请输入分组名称和用户ID列表');
      return;
    }
    try {
      final result = await TencentImSDKPlugin.v2TIMManager.getFriendshipManager().addFriendsToFriendGroup(
        groupName: _groupNameController.text,
        userIDList: _userIDListController.text.split(','),
      );
      _addLog('添加好友到一个好友分组成功: ${result.toJson()}');
    } catch (e) {
      _addLog('添加好友到一个好友分组失败: $e');
    }
  }

  // 从好友分组中删除好友
  Future<void> _deleteFriendsFromFriendGroup() async {
    if (_groupNameController.text.isEmpty || _userIDListController.text.isEmpty) {
      _addLog('请输入分组名称和用户ID列表');
      return;
    }
    try {
      final result = await TencentImSDKPlugin.v2TIMManager.getFriendshipManager().deleteFriendsFromFriendGroup(
        groupName: _groupNameController.text,
        userIDList: _userIDListController.text.split(','),
      );
      _addLog('从好友分组中删除好友成功: ${result.toJson()}');
    } catch (e) {
      _addLog('从好友分组中删除好友失败: $e');
    }
  }

  // 搜索好友
  Future<void> _searchFriends() async {
    V2TimFriendSearchParam searchParam = V2TimFriendSearchParam(
      keywordList: [_searchFriendController.text],
      isSearchUserID: isSearchUserID,
      isSearchNickName: isSearchNickName,
      isSearchRemark: isSearchRemark,
    );

    V2TimValueCallback<List<V2TimFriendInfoResult>> searchFriendsRes =
        await TencentImSDKPlugin.v2TIMManager
            .getFriendshipManager()
            .searchFriends(searchParam: searchParam);

    if (searchFriendsRes.code == 0) {
      String friendLog = '';
      for (V2TimFriendInfoResult friendInfoResult in searchFriendsRes.data!) {
        friendLog += '${friendInfoResult.toJson()}\n\n';
      }
      _addLog('搜索好友: $friendLog');
    } else {
      _addLog('搜索好友失败，code: ${searchFriendsRes.code}, desc: ${searchFriendsRes.desc}');
    }
  }

  // 订阅公众号
  Future<void> _subscribeOfficialAccount() async {
    if (_officialAccountIDController.text.isEmpty) {
      _addLog('请输入公众号ID');
      return;
    }
    try {
      final result = await TencentImSDKPlugin.v2TIMManager.getFriendshipManager().subscribeOfficialAccount(
        officialAccountID: _officialAccountIDController.text,
      );
      _addLog('订阅公众号成功: ${result.toJson()}');
    } catch (e) {
      _addLog('订阅公众号失败: $e');
    }
  }

  // 取消订阅公众号
  Future<void> _unsubscribeOfficialAccount() async {
    if (_officialAccountIDController.text.isEmpty) {
      _addLog('请输入公众号ID');
      return;
    }
    try {
      final result = await TencentImSDKPlugin.v2TIMManager.getFriendshipManager().unsubscribeOfficialAccount(
        officialAccountID: _officialAccountIDController.text,
      );
      _addLog('取消订阅公众号成功: ${result.toJson()}');
    } catch (e) {
      _addLog('取消订阅公众号失败: $e');
    }
  }

  // 获取公众号列表
  Future<void> _getOfficialAccountsInfo() async {
    if (_userIDListController.text.isEmpty) {
      _addLog('请输入公众号ID列表，用逗号分隔');
      return;
    }
    try {
      final result = await TencentImSDKPlugin.v2TIMManager.getFriendshipManager().getOfficialAccountsInfo(
        officialAccountIDList: [],
      );
      _addLog('获取公众号列表成功: ${result.toJson()}');
    } catch (e) {
      _addLog('获取公众号列表失败: $e');
    }
  }

  // 关注用户
  Future<void> _followUser() async {
    if (_followUserListController.text.isEmpty) {
      _addLog('请输入关注ID列表，用逗号分隔');
      return;
    }
    try {
      final result = await TencentImSDKPlugin.v2TIMManager.getFriendshipManager().followUser(
        userIDList: _followUserListController.text.split(','),
      );
      _addLog('关注用户: ${result.toJson()}');
    } catch (e) {
      _addLog('关注用户失败: $e');
    }
  }

  // 取消关注用户
  Future<void> _unfollowUser() async {
    if (_followUserListController.text.isEmpty) {
      _addLog('请输入关注ID列表，用逗号分隔');
      return;
    }
    try {
      final result = await TencentImSDKPlugin.v2TIMManager.getFriendshipManager().unfollowUser(
        userIDList: _followUserListController.text.split(','),
      );
      _addLog('取消关注用户: ${result.toJson()}');
    } catch (e) {
      _addLog('取消关注用户失败: $e');
    }
  }

  // 获取我的关注列表
  Future<void> _getMyFollowingList() async {
    try {
      final result = await TencentImSDKPlugin.v2TIMManager.getFriendshipManager().getMyFollowingList(
        nextCursor: '',
      );
      _addLog('获取我的关注列表: ${result.toJson()}');
    } catch (e) {
      _addLog('获取我的关注列表失败: $e');
    }
  }

  // 获取关注我的列表
  Future<void> _getMyFollowersList() async {
    try {
      final result = await TencentImSDKPlugin.v2TIMManager.getFriendshipManager().getMyFollowersList(
        nextCursor: '',
      );
      _addLog('获取关注我的列表成功: ${result.toJson()}');
    } catch (e) {
      _addLog('获取关注我的列表失败: $e');
    }
  }

  // 获取我的互关列表
  Future<void> _getMutualFollowersList() async {
    try {
      final result = await TencentImSDKPlugin.v2TIMManager.getFriendshipManager().getMutualFollowersList(
        nextCursor: '',
      );
      _addLog('获取我的互关列表成功: ${result.toJson()}');
    } catch (e) {
      _addLog('获取我的互关列表失败: $e');
    }
  }

  // 获取指定用户的关注/粉丝/互关数量信息
  Future<void> _getUserFollowInfo() async {
    if (_userIDListController.text.isEmpty) {
      _addLog('请输入用户ID列表，用逗号分隔');
      return;
    }
    try {
      final result = await TencentImSDKPlugin.v2TIMManager.getFriendshipManager().getUserFollowInfo(
        userIDList: _userIDListController.text.split(','),
      );
      _addLog('获取指定用户的关注/粉丝/互关数量信息成功: ${result.toJson()}');
    } catch (e) {
      _addLog('获取指定用户的关注/粉丝/互关数量信息失败: $e');
    }
  }

  // 检查指定用户的关注类型
  Future<void> _checkFollowType() async {
    if (_userIDListController.text.isEmpty) {
      _addLog('请输入用户ID列表，用逗号分隔');
      return;
    }
    try {
      final result = await TencentImSDKPlugin.v2TIMManager.getFriendshipManager().checkFollowType(
        userIDList: _userIDListController.text.split(','),
      );
      _addLog('检查指定用户的关注类型成功: ${result.toJson()}');
    } catch (e) {
      _addLog('检查指定用户的关注类型失败: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final inputFields = [
      // 用户ID和好友ID
      Row(
        children: [
          // 用户ID
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('用户ID:', style: TextStyle(fontSize: 12)),
                SizedBox(
                  height: 30,
                  child: TextField(
                    controller: _userIDController,
                    style: const TextStyle(fontSize: 13),
                    decoration: const InputDecoration(
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      const SizedBox(height: 4),
      
      // 好友ID列表和好友备注
      Row(
        children: [
          // 好友ID列表
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('好友ID列表:', style: TextStyle(fontSize: 12)),
                SizedBox(
                  height: 30,
                  child: TextField(
                    controller: _userIDListController,
                    style: const TextStyle(fontSize: 13),
                    decoration: const InputDecoration(
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      border: OutlineInputBorder(),
                      hintText: '用逗号分隔',
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // 好友备注
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('好友备注:', style: TextStyle(fontSize: 12)),
                SizedBox(
                  height: 30,
                  child: TextField(
                    controller: _friendRemarkController,
                    style: const TextStyle(fontSize: 13),
                    decoration: const InputDecoration(
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      const SizedBox(height: 4),
      
      // 好友分组和好友自定义信息
      Row(
        children: [
          // 好友分组
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('加好友带分组:', style: TextStyle(fontSize: 12)),
                SizedBox(
                  height: 30,
                  child: TextField(
                    controller: _addFriendWithGroupController,
                    style: const TextStyle(fontSize: 13),
                    decoration: const InputDecoration(
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // 好友自定义信息
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('好友自定义信息:', style: TextStyle(fontSize: 12)),
                SizedBox(
                  height: 30,
                  child: TextField(
                    controller: _friendCustomInfoController,
                    style: const TextStyle(fontSize: 13),
                    decoration: const InputDecoration(
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      const SizedBox(height: 4),
      
      // 好友申请ID和好友申请备注
      Row(
        children: [
          // 好友申请ID
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('好友申请ID:', style: TextStyle(fontSize: 12)),
                SizedBox(
                  height: 30,
                  child: TextField(
                    controller: _friendApplicationIDController,
                    style: const TextStyle(fontSize: 13),
                    decoration: const InputDecoration(
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // 好友申请备注
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('好友申请备注:', style: TextStyle(fontSize: 12)),
                SizedBox(
                  height: 30,
                  child: TextField(
                    controller: _friendApplicationRemarkController,
                    style: const TextStyle(fontSize: 13),
                    decoration: const InputDecoration(
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),

      Row(
        children: [
          // 好友申请附言
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('好友申请附言:', style: TextStyle(fontSize: 12)),
                SizedBox(
                  height: 30,
                  child: TextField(
                    controller: _addWordingController,
                    style: const TextStyle(fontSize: 13),
                    decoration: const InputDecoration(
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // 分组名称
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('分组名称:', style: TextStyle(fontSize: 12)),
                SizedBox(
                  height: 30,
                  child: TextField(
                    controller: _groupNameController,
                    style: const TextStyle(fontSize: 13),
                    decoration: const InputDecoration(
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      border: OutlineInputBorder(),
                      hintText: '好友分组名称',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      const SizedBox(height: 4),
      
      // 旧分组和新分组输入框
      Row(
        children: [
          // 旧分组名称
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('旧分组名称:', style: TextStyle(fontSize: 12)),
                SizedBox(
                  height: 30,
                  child: TextField(
                    controller: _oldNameController,
                    style: const TextStyle(fontSize: 13),
                    decoration: const InputDecoration(
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      border: OutlineInputBorder(),
                      hintText: '要修改的分组名称',
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // 新分组名称
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('新分组名称:', style: TextStyle(fontSize: 12)),
                SizedBox(
                  height: 30,
                  child: TextField(
                    controller: _newNameController,
                    style: const TextStyle(fontSize: 13),
                    decoration: const InputDecoration(
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      border: OutlineInputBorder(),
                      hintText: '修改后的分组名称',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      const SizedBox(height: 4),
      
      // 搜索好友关键字输入框
      Row(
        children: [
          // 搜索好友关键字
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('搜索好友关键字:', style: TextStyle(fontSize: 12)),
                SizedBox(
                  height: 30,
                  child: TextField(
                    controller: _searchFriendController,
                    style: const TextStyle(fontSize: 13),
                    decoration: const InputDecoration(
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      border: OutlineInputBorder(),
                      hintText: '输入搜索关键字',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      const SizedBox(height: 4),
      
      // 公众号ID和关注用户ID列表
      Row(
        children: [
          // 公众号ID列表
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('公众号ID:', style: TextStyle(fontSize: 12)),
                SizedBox(
                  height: 30,
                  child: TextField(
                    controller: _officialAccountIDController,
                    style: const TextStyle(fontSize: 13),
                    decoration: const InputDecoration(
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      border: OutlineInputBorder(),
                      hintText: '公众号ID',
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // 关注用户ID列表
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('关注用户ID列表:', style: TextStyle(fontSize: 12)),
                SizedBox(
                  height: 30,
                  child: TextField(
                    controller: _userIDListController,
                    style: const TextStyle(fontSize: 13),
                    decoration: const InputDecoration(
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      border: OutlineInputBorder(),
                      hintText: '用逗号分隔',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ];

    final buttons = [
      _buildDynamicButton('获取好友列表', _getFriendList),
      _buildDynamicButton('获取指定好友资料', _getFriendsInfo),
      _buildDynamicButton('设置指定好友资料', _setFriendInfo),
      _buildDynamicButton('添加好友', _addFriend),
      _buildDynamicButton('删除好友', _deleteFromFriendList),
      _buildDynamicButton('检查好友关系', _checkFriend),
      _buildDynamicButton('获取好友申请列表', _getFriendApplicationList),
      _buildDynamicButton('同意好友申请', _acceptFriendApplication),
      _buildDynamicButton('拒绝好友申请', _refuseFriendApplication),
      _buildDynamicButton('删除好友申请', _deleteFriendApplication),
      _buildDynamicButton('设置好友申请已读', _setFriendApplicationRead),
      _buildDynamicButton('添加用户到黑名单', _addToBlackList),
      _buildDynamicButton('把用户从黑名单中删除', _deleteFromBlackList),
      _buildDynamicButton('获取黑名单列表', _getBlackList),
      _buildDynamicButton('新建好友分组', _createFriendGroup),
      _buildDynamicButton('获取分组信息', _getFriendGroups),
      _buildDynamicButton('删除好友分组', _deleteFriendGroup),
      _buildDynamicButton('修改好友分组的名称', _renameFriendGroup),
      _buildDynamicButton('添加好友到一个好友分组', _addFriendsToFriendGroup),
      _buildDynamicButton('从好友分组中删除好友', _deleteFriendsFromFriendGroup),
      _buildDynamicButton('搜索好友', _searchFriends),
      _buildDynamicButton('订阅公众号', _subscribeOfficialAccount),
      _buildDynamicButton('取消订阅公众号', _unsubscribeOfficialAccount),
      _buildDynamicButton('获取公众号列表', _getOfficialAccountsInfo),
      _buildDynamicButton('关注用户', _followUser),
      _buildDynamicButton('取消关注用户', _unfollowUser),
      _buildDynamicButton('获取我的关注列表', _getMyFollowingList),
      _buildDynamicButton('获取关注我的列表', _getMyFollowersList),
      _buildDynamicButton('获取我的互关列表', _getMutualFollowersList),
      _buildDynamicButton('获取指定用户的关注/粉丝/互关数量信息', _getUserFollowInfo),
      _buildDynamicButton('检查指定用户的关注类型', _checkFollowType),
    ];

    return BaseAPITest(
      title: '好友管理',
      inputFields: inputFields,
      buttons: buttons,
      onClearLog: _clearLog,
    );
  }

  Widget _buildDynamicButton(String text, VoidCallback onPressed) {
    return Container(
      margin: const EdgeInsets.only(bottom: 1.0),
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 5.0, vertical: 3.0),
          minimumSize: Size(text.length * 6.0 + 12.0, 30.0),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity: VisualDensity.compact,
          textStyle: const TextStyle(fontSize: 12.0),
          foregroundColor: Colors.white,
          backgroundColor: Colors.blue,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(4.0),
          ),
        ),
        child: Text(text),
      ),
    );
  }

  @override
  void dispose() {
    _userIDController.dispose();
    _addFriendWithGroupController.dispose();
    _addWordingController.dispose();
    _addSourceController.dispose();
    _addTypeController.dispose();
    _userIDListController.dispose();
    _deleteTypeController.dispose();
    _checkTypeController.dispose();
    _responseTypeController.dispose();
    _applicationTypeController.dispose();
    _groupNameController.dispose();
    _oldNameController.dispose();
    _newNameController.dispose();
    _officialAccountIDController.dispose();
    _searchKeywordController.dispose();
    _searchFriendController.dispose();
    _friendCustomInfoController.dispose();
    _friendApplicationRemarkController.dispose();
    _friendRemarkController.dispose();
    _friendApplicationIDController.dispose();
    _followUserListController.dispose();
    super.dispose();
  }
} 