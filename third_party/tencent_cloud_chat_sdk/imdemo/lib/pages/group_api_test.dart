import 'package:flutter/material.dart';
import 'package:tencent_cloud_chat_sdk/enum/group_add_opt_enum.dart';
import 'package:tencent_cloud_chat_sdk/enum/group_application_type_enum.dart';
import 'package:tencent_cloud_chat_sdk/enum/group_member_filter_enum.dart';
import 'package:tencent_cloud_chat_sdk/enum/group_member_role_enum.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_group_info.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_group_info.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_group_member.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_group_member.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_group_member_full_info.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_group_member_full_info.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_group_member_info_result.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_group_member_info_result.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_group_member_search_param.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_group_member_search_param.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_group_search_param.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_group_search_param.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_group_search_result.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_group_search_result.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_value_callback.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_value_callback.dart';
import 'package:tencent_cloud_chat_sdk/tencent_im_sdk_plugin.dart';
import 'package:tencent_cloud_chat_sdk_example/utils/log_manager.dart';
import 'base_api_test.dart';

class GroupAPITest extends StatefulWidget {
  const GroupAPITest({Key? key}) : super(key: key);

  @override
  State<GroupAPITest> createState() => _GroupAPITestState();
}

class _GroupAPITestState extends State<GroupAPITest> {
  final TextEditingController _groupIDController = TextEditingController();
  final TextEditingController _groupNameController = TextEditingController();
  final TextEditingController _groupTypeController = TextEditingController();
  final TextEditingController _userIDListController = TextEditingController();
  final TextEditingController _groupIntroductionController = TextEditingController();
  final TextEditingController _groupNotificationController = TextEditingController();
  final TextEditingController _groupFaceURLController = TextEditingController();
  final TextEditingController _notificationController = TextEditingController();
  final TextEditingController _introductionController = TextEditingController();
  final TextEditingController _faceUrlController = TextEditingController();
  final TextEditingController _isAllMutedController = TextEditingController();
  final TextEditingController _isSupportTopicController = TextEditingController();
  final TextEditingController _addOptController = TextEditingController();
  final TextEditingController _approveOptController = TextEditingController();
  final TextEditingController _isEnablePermissionGroupController = TextEditingController();
  final TextEditingController _defaultPermissionsController = TextEditingController();
  final TextEditingController _nextSeqController = TextEditingController();
  final TextEditingController _countController = TextEditingController();
  final TextEditingController _nameCardController = TextEditingController();
  final TextEditingController _userIDController = TextEditingController();
  final TextEditingController _secondsController = TextEditingController();
  final TextEditingController _reasonController = TextEditingController();
  final TextEditingController _fromUserController = TextEditingController();
  final TextEditingController _toUserController = TextEditingController();
  final TextEditingController _addTimeController = TextEditingController();
  final TextEditingController _typeController = TextEditingController();
  final TextEditingController _roleController = TextEditingController();

  bool _isSearchGroupID = true;
  bool _isSearchGroupName = true;
  bool _isSearchMemberUserID = true;
  bool _isSearchMemberNickName = true;
  bool _isSearchMemberRemark = true;
  bool _isSearchMemberNameCard = true;

  // 使用全局日志管理器
  final LogManager _logManager = LogManager();

  @override
  void initState() {
    super.initState();
    _groupIDController.text = 'public15';
    _groupNameController.text = '群组测试名称';
    _nameCardController.text = '群名片修改测试';
  }

  // 添加日志的帮助方法
  void _addLog(String log) {
    _logManager.updateLogText(log);
  }

  // 清空日志
  void _clearLog() {
    _logManager.clearAllLogs();
  }

  // 创建群组
  Future<void> _createGroup() async {
    if (_groupIDController.text.isEmpty || _groupTypeController.text.isEmpty || _groupNameController.text.isEmpty) {
      _addLog('请输入群组ID、群组类型和群组名称');
      return;
    }
    try {
      final result = await TencentImSDKPlugin.v2TIMManager.getGroupManager().createGroup(
        groupID: _groupIDController.text,
        groupType: _groupTypeController.text,
        groupName: _groupNameController.text,
        notification: _notificationController.text.isEmpty ? null : _notificationController.text,
        introduction: _introductionController.text.isEmpty ? null : _introductionController.text,
        faceUrl: _faceUrlController.text.isEmpty ? null : _faceUrlController.text,
        isAllMuted: _isAllMutedController.text == 'true',
        isSupportTopic: _isSupportTopicController.text == 'true',
        addOpt: _addOptController.text.isEmpty ? null : GroupAddOptTypeEnum.values[int.parse(_addOptController.text)],
        memberList: _userIDListController.text.isEmpty ? null : _userIDListController.text.split(',').map((e) => V2TimGroupMember(userID: e, role: GroupMemberRoleTypeEnum.V2TIM_GROUP_MEMBER_ROLE_MEMBER)).toList(),
        approveOpt: _approveOptController.text.isEmpty ? null : GroupAddOptTypeEnum.values[int.parse(_approveOptController.text)],
        isEnablePermissionGroup: _isEnablePermissionGroupController.text == 'true',
        defaultPermissions: _defaultPermissionsController.text.isEmpty ? null : int.parse(_defaultPermissionsController.text),
      );
      _addLog('创建群组成功: ${result.toJson()}');
    } catch (e) {
      _addLog('创建群组失败: $e');
    }
  }

  // 初始化群属性
  Future<void> _initGroupAttributes() async {
    if (_groupIDController.text.isEmpty) {
      _addLog('请输入群组ID');
      return;
    }
    try {
      final result = await TencentImSDKPlugin.v2TIMManager.getGroupManager().initGroupAttributes(
        groupID: _groupIDController.text,
        attributes: {
          'key1': 'value1',
          'key2': 'value2',
        },
      );
      _addLog('初始化群属性: ${result.toJson()}');
    } catch (e) {
      _addLog('初始化群属性失败: $e');
    }
  }

  // 设置群属性
  Future<void> _setGroupAttributes() async {
    if (_groupIDController.text.isEmpty) {
      _addLog('请输入群组ID');
      return;
    }
    try {
      final result = await TencentImSDKPlugin.v2TIMManager.getGroupManager().setGroupAttributes(
        groupID: _groupIDController.text,
        attributes: {
          'key1': 'value1',
          'key2': 'value2',
        },
      );
      _addLog('设置群属性: ${result.toJson()}');
    } catch (e) {
      _addLog('设置群属性失败: $e');
    }
  }

  // 删除群属性
  Future<void> _deleteGroupAttributes() async {
    if (_groupIDController.text.isEmpty) {
      _addLog('请输入群组ID');
      return;
    }
    try {
      final result = await TencentImSDKPlugin.v2TIMManager.getGroupManager().deleteGroupAttributes(
        groupID: _groupIDController.text,
        keys: ['key1', 'key2'],
      );
      _addLog('删除群属性: ${result.toJson()}');
    } catch (e) {
      _addLog('删除群属性失败: $e');
    }
  }

  // 获取群属性
  Future<void> _getGroupAttributes() async {
    if (_groupIDController.text.isEmpty) {
      _addLog('请输入群组ID');
      return;
    }
    try {
      final result = await TencentImSDKPlugin.v2TIMManager.getGroupManager().getGroupAttributes(
        groupID: _groupIDController.text,
        keys: ['key1', 'key2'],
      );
      _addLog('获取群属性: ${result.toJson()}');
    } catch (e) {
      _addLog('获取群属性失败: $e');
    }
  }

  // 获取群成员列表（循环分页拉取）
  Future<void> _getGroupMemberList() async {
    if (_groupIDController.text.isEmpty) {
      _addLog('请输入群组ID');
      return;
    }

    String groupID = _groupIDController.text;
    int count = _countController.text.isEmpty ? 30 : int.parse(_countController.text);

    String currentNextSeq = '0';
    int page = 0;
    int totalMembers = 0;

    try {
      do {
        page++;
        _addLog('--- 第 $page 页，nextSeq: $currentNextSeq ---');

        V2TimValueCallback<V2TimGroupMemberInfoResult> result = await TencentImSDKPlugin.v2TIMManager.getGroupManager().getGroupMemberList(
          groupID: groupID,
          filter: GroupMemberFilterTypeEnum.V2TIM_GROUP_MEMBER_FILTER_ALL,
          nextSeq: currentNextSeq,
          count: count,
        );

        if (result.code == 0) {
          int memberCount = result.data?.memberInfoList?.length ?? 0;
          totalMembers += memberCount;
          String groupMemberListLog = '返回 nextSeq: ${result.data?.nextSeq}, 本页成员数: $memberCount\n';
          for (V2TimGroupMemberFullInfo memberFullInfo in result.data?.memberInfoList ?? []) {
            groupMemberListLog += 'memberFullInfo: ${memberFullInfo.toJson()}\n\n';
          }
          _addLog('第 $page 页结果: $groupMemberListLog');

          currentNextSeq = result.data?.nextSeq ?? '0';
        } else {
          _addLog('获取群成员列表失败: ${result.toJson()}');
          break;
        }
      } while (currentNextSeq != '0' && currentNextSeq.isNotEmpty);

      _addLog('=== 拉取完成，共 $page 页，总成员数: $totalMembers ===');
    } catch (e) {
      _addLog('获取群成员列表失败: $e');
    }
  }

  // 获取群成员资料
  Future<void> _getGroupMembersInfo() async {
    if (_groupIDController.text.isEmpty || _userIDListController.text.isEmpty) {
      _addLog('请输入群组ID和成员ID列表');
      return;
    }
    try {
      final result = await TencentImSDKPlugin.v2TIMManager.getGroupManager().getGroupMembersInfo(
        groupID: _groupIDController.text,
        memberList: _userIDListController.text.split(','),
      );
      _addLog('获取群成员资料成功: ${result.toJson()}');
    } catch (e) {
      _addLog('获取群成员资料失败: $e');
    }
  }

  // 修改群成员资料
  Future<void> _setGroupMemberInfo() async {
    if (_groupIDController.text.isEmpty || _userIDController.text.isEmpty) {
      _addLog('请输入群组ID和用户ID');
      return;
    }
    try {
      final result = await TencentImSDKPlugin.v2TIMManager.getGroupManager().setGroupMemberInfo(
        groupID: _groupIDController.text,
        userID: _userIDController.text,
        nameCard: _nameCardController.text.isEmpty ? null : _nameCardController.text,
        customInfo: {'group_member_p': 'value1', 'group_member_p2': 'value2'},
      );
      _addLog('修改群成员资料成功: ${result.toJson()}');
    } catch (e) {
      _addLog('修改群成员资料失败: $e');
    }
  }

  // 禁言群成员
  Future<void> _muteGroupMember() async {
    if (_groupIDController.text.isEmpty || _userIDController.text.isEmpty || _secondsController.text.isEmpty) {
      _addLog('请输入群组ID、用户ID和禁言时长');
      return;
    }
    try {
      final result = await TencentImSDKPlugin.v2TIMManager.getGroupManager().muteGroupMember(
        groupID: _groupIDController.text,
        userID: _userIDController.text,
        seconds: int.parse(_secondsController.text),
      );
      _addLog('禁言群成员成功: ${result.toJson()}');
    } catch (e) {
      _addLog('禁言群成员失败: $e');
    }
  }

  // 禁言全体群成员
  Future<void> _muteAllGroupMembers(bool isMute) async {
    if (_groupIDController.text.isEmpty) {
      _addLog('请输入群组ID');
      return;
    }
    try {
      final result = await TencentImSDKPlugin.v2TIMManager.getGroupManager().muteAllGroupMembers(
        groupID: _groupIDController.text,
        isMute: isMute,
      );
      _addLog('${isMute ? "禁言" : "解除禁言"}全体群成员: ${result.toJson()}');
    } catch (e) {
      _addLog('${isMute ? "禁言" : "解除禁言"}全体群成员失败: $e');
    }
  }

  // 邀请他人入群
  Future<void> _inviteUserToGroup() async {
    if (_groupIDController.text.isEmpty || _userIDListController.text.isEmpty) {
      _addLog('请输入群组ID和用户ID列表');
      return;
    }
    try {
      final result = await TencentImSDKPlugin.v2TIMManager.getGroupManager().inviteUserToGroup(
        groupID: _groupIDController.text,
        userList: _userIDListController.text.split(','),
      );
      _addLog('邀请他人入群成功: ${result.toJson()}');
    } catch (e) {
      _addLog('邀请他人入群失败: $e');
    }
  }

  // 踢人
  Future<void> _kickGroupMember() async {
    if (_groupIDController.text.isEmpty || _userIDListController.text.isEmpty) {
      _addLog('请输入群组ID和用户ID列表');
      return;
    }
    try {
      final result = await TencentImSDKPlugin.v2TIMManager.getGroupManager().kickGroupMember(
        groupID: _groupIDController.text,
        memberList: _userIDListController.text.split(','),
        reason: _reasonController.text.isEmpty ? null : _reasonController.text,
      );
      _addLog('踢人成功: ${result.toJson()}');
    } catch (e) {
      _addLog('踢人失败: $e');
    }
  }

  // 设置群成员角色
  Future<void> _setGroupMemberRole() async {
    if (_groupIDController.text.isEmpty || _userIDController.text.isEmpty || _roleController.text.isEmpty) {
      _addLog('请输入群组ID、用户ID和角色');
      return;
    }
    try {
      final result = await TencentImSDKPlugin.v2TIMManager.getGroupManager().setGroupMemberRole(
        groupID: _groupIDController.text,
        userID: _userIDController.text,
        role: GroupMemberRoleTypeEnum.values[int.parse(_roleController.text)],
      );
      _addLog('设置群成员角色成功: ${result.toJson()}');
    } catch (e) {
      _addLog('设置群成员角色失败: $e');
    }
  }

  // 转让群主
  Future<void> _transferGroupOwner() async {
    if (_groupIDController.text.isEmpty || _userIDController.text.isEmpty) {
      _addLog('请输入群组ID和用户ID');
      return;
    }
    try {
      final result = await TencentImSDKPlugin.v2TIMManager.getGroupManager().transferGroupOwner(
        groupID: _groupIDController.text,
        userID: _userIDController.text,
      );
      _addLog('转让群主成功: ${result.toJson()}');
    } catch (e) {
      _addLog('转让群主失败: $e');
    }
  }

  // 标记群成员
  Future<void> _markGroupMemberList() async {
    if (_groupIDController.text.isEmpty || _userIDController.text.isEmpty) {
      _addLog('请输入群组ID和用户ID');
      return;
    }
    try {
      final result = await TencentImSDKPlugin.v2TIMManager.getGroupManager().markGroupMemberList(
        groupID: _groupIDController.text,
        memberIDList: [_userIDController.text],
        markType: 1001,
        enableMark: true,
      );
      _addLog('标记群成员成功: ${result.toJson()}');
    } catch (e) {
      _addLog('标记群成员失败: $e');
    }
  }

  // 接受加群申请
  Future<void> _acceptGroupApplication() async {
    if (_groupIDController.text.isEmpty || _fromUserController.text.isEmpty || _toUserController.text.isEmpty || _addTimeController.text.isEmpty || _typeController.text.isEmpty) {
      _addLog('请输入群组ID、请求者ID、处理者ID、添加时间和申请类型');
      return;
    }
    try {
      final result = await TencentImSDKPlugin.v2TIMManager.getGroupManager().acceptGroupApplication(
        groupID: _groupIDController.text,
        fromUser: _fromUserController.text,
        toUser: _toUserController.text,
        addTime: int.parse(_addTimeController.text),
        type: GroupApplicationTypeEnum.values[int.parse(_typeController.text)],
        reason: _reasonController.text.isEmpty ? null : _reasonController.text,
      );
      _addLog('接受加群申请成功: ${result.toJson()}');
    } catch (e) {
      _addLog('接受加群申请失败: $e');
    }
  }

  // 拒绝加群申请
  Future<void> _refuseGroupApplication() async {
    if (_groupIDController.text.isEmpty || _fromUserController.text.isEmpty || _toUserController.text.isEmpty || _addTimeController.text.isEmpty || _typeController.text.isEmpty) {
      _addLog('请输入群组ID、请求者ID、处理者ID、添加时间和申请类型');
      return;
    }
    try {
      final result = await TencentImSDKPlugin.v2TIMManager.getGroupManager().refuseGroupApplication(
        groupID: _groupIDController.text,
        fromUser: _fromUserController.text,
        toUser: _toUserController.text,
        addTime: int.parse(_addTimeController.text),
        type: GroupApplicationTypeEnum.values[int.parse(_typeController.text)],
        reason: _reasonController.text.isEmpty ? null : _reasonController.text,
      );
      _addLog('拒绝加群申请成功: ${result.toJson()}');
    } catch (e) {
      _addLog('拒绝加群申请失败: $e');
    }
  }

  // 获取已加入的群组列表
  Future<void> _getJoinedGroupList() async {
    try {
      final result = await TencentImSDKPlugin.v2TIMManager.getGroupManager().getJoinedGroupList();
      _addLog('获取已加入的群组列表成功: ${result.toJson()}');
    } catch (e) {
      _addLog('获取已加入的群组列表失败: $e');
    }
  }

  // 获取群组信息
  Future<void> _getGroupsInfo() async {
    if (_groupIDController.text.isEmpty) {
      _addLog('请输入群组ID');
      return;
    }
    try {
      final result = await TencentImSDKPlugin.v2TIMManager.getGroupManager().getGroupsInfo(
        groupIDList: [_groupIDController.text],
      );
      _addLog('获取群组信息: ${result.toJson()}');
    } catch (e) {
      _addLog('获取群组信息失败: $e');
    }
  }

  // 设置群组信息
  Future<void> _setGroupInfo() async {
    if (_groupIDController.text.isEmpty) {
      _addLog('请输入群组ID');
      return;
    }
    try {
      final info = V2TimGroupInfo(
        groupID: _groupIDController.text,
        groupType: _groupTypeController.text.isEmpty ? "Public" : _groupTypeController.text,
        groupName: _groupNameController.text,
        introduction: _groupIntroductionController.text.isEmpty ? null : _groupIntroductionController.text,
        notification: _groupNotificationController.text.isEmpty ? null : _groupNotificationController.text,
        faceUrl: _groupFaceURLController.text.isEmpty ? null : _groupFaceURLController.text,
        customInfo: {'group_test': 'value1', 'group_info': 'value2'},
      );
      final result = await TencentImSDKPlugin.v2TIMManager.getGroupManager().setGroupInfo(
        info: info,
      );
      _addLog('设置群组信息: ${result.toJson()}');
    } catch (e) {
      _addLog('设置群组信息失败: $e');
    }
  }

  // 获取群组在线人数
  Future<void> _getGroupOnlineMemberCount() async {
    if (_groupIDController.text.isEmpty) {
      _addLog('请输入群组ID');
      return;
    }
    try {
      final result = await TencentImSDKPlugin.v2TIMManager.getGroupManager().getGroupOnlineMemberCount(
        groupID: _groupIDController.text,
      );
      _addLog('获取群组在线人数: ${result.toJson()}');
    } catch (e) {
      _addLog('获取群组在线人数失败: $e');
    }
  }

  // 获取群组申请列表
  Future<void> _getGroupApplicationList() async {
    try {
      final result = await TencentImSDKPlugin.v2TIMManager.getGroupManager().getGroupApplicationList();
      _addLog('获取群组申请列表成功: ${result.toJson()}');
    } catch (e) {
      _addLog('获取群组申请列表失败: $e');
    }
  }

  // 标记群组申请为已读
  Future<void> _setGroupApplicationRead() async {
    try {
      final result = await TencentImSDKPlugin.v2TIMManager.getGroupManager().setGroupApplicationRead();
      _addLog('标记群组申请为已读成功: ${result.toJson()}');
    } catch (e) {
      _addLog('标记群组申请为已读失败: $e');
    }
  }

  // 搜索群组
  Future<void> _searchGroups() async {
    if (_groupNameController.text.isEmpty) {
      _addLog('请输入群组名称');
      return;
    }
    try {
      final searchParam = V2TimGroupSearchParam(
        keywordList: [_groupNameController.text],
        isSearchGroupID: _isSearchGroupID,
        isSearchGroupName: _isSearchGroupName,
      );
      V2TimValueCallback<List<V2TimGroupInfo>> result = await TencentImSDKPlugin.v2TIMManager.getGroupManager().searchGroups(
        searchParam: searchParam,
      );
      if (result.code == 0) {
        String groupLog = '';
        for (V2TimGroupInfo groupInfo in result.data ?? [])  {
          groupLog += '${groupInfo.toLogString()}\n\n';
        }
        _addLog('搜索群组: $groupLog');
      } else {
        _addLog('搜索群组失败，code: ${result.code} desc: ${result.desc}');
      }
    } catch (e) {
      _addLog('搜索群组失败: $e');
    }
  }

  // 搜索群组
  Future<void> _searchCloudGroups() async {
    if (_groupNameController.text.isEmpty) {
      _addLog('请输入群组名称');
      return;
    }
    try {
      final searchParam = V2TimGroupSearchParam(
        keywordList: [_groupNameController.text],
        keywordListMatchType: V2TimGroupSearchParam.V2TIM_KEYWORD_LIST_MATCH_TYPE_AND,
        searchCount: 20,
        searchCursor: "",
      );

      V2TimValueCallback<V2TimGroupSearchResult> result = await TencentImSDKPlugin.v2TIMManager.getGroupManager().searchCloudGroups(
        searchParam: searchParam,
      );
      if (result.code == 0) {
        String groupLog = 'isFinished: ${result.data?.isFinished}, totalCount: ${result.data?.totalCount}, searchCursor: ${result.data?.nextCursor}\n';
        for (V2TimGroupInfo groupInfo in result.data?.groupList ?? [])  {
          groupLog += '${groupInfo.toLogString()}\n\n';
        }
        _addLog('_searchCloudGroups: $groupLog');
      } else {
        _addLog('_searchCloudGroups failed，code: ${result.code} desc: ${result.desc}');
      }
    } catch (e) {
      _addLog('_searchCloudGroups failed: $e');
    }
  }

  // 搜索群成员
  Future<void> _searchGroupMembers() async {
    if (_groupIDController.text.isEmpty || _userIDController.text.isEmpty) {
      _addLog('请输入群组ID和用户ID');
      return;
    }
    try {
      final searchParam = V2TimGroupMemberSearchParam(
        keywordList: [_userIDController.text],
        groupIDList: [_groupIDController.text],
        isSearchMemberUserID: _isSearchMemberUserID,
        isSearchMemberNickName: _isSearchMemberNickName,
        isSearchMemberRemark: _isSearchMemberRemark,
        isSearchMemberNameCard: _isSearchMemberNameCard,
      );
      final result = await TencentImSDKPlugin.v2TIMManager.getGroupManager().searchGroupMembers(
        param: searchParam,
      );
      _addLog('搜索群成员: ${result.data?.toLogString()}');
    } catch (e) {
      _addLog('搜索群成员失败: $e');
    }
  }

  // 搜索云端群成员
  Future<void> _searchCloudGroupMembers() async {
    if (_groupIDController.text.isEmpty || _userIDController.text.isEmpty) {
      _addLog('请输入群组ID和用户ID');
      return;
    }
    try {
      final searchParam = V2TimGroupMemberSearchParam(
        keywordList: [_userIDController.text],
        groupIDList: [_groupIDController.text],
        keywordListMatchType: V2TimGroupMemberSearchParam.V2TIM_KEYWORD_LIST_MATCH_TYPE_AND,
        searchCount: 2,
        searchCursor: "",
      );
      final result = await TencentImSDKPlugin.v2TIMManager.getGroupManager().searchCloudGroupMembers(
        param: searchParam,
      );

      if (result.code == 0) {
        String groupLog = 'isFinished: ${result.data?.isFinished}, totalCount: ${result.data?.totalCount}, searchCursor: ${result.data?.nextCursor}\n';
        result.data?.groupMemberSearchResultItems?.forEach((groupId, memberList) {
          groupLog += '群组ID: $groupId, 成员数量: ${memberList.length}, 成员信息: \n';
          // 遍历每个成员
          for (V2TimGroupMemberFullInfo member in memberList) {
            groupLog += '${member.toLogString()}\n\n';
          }
          groupLog += '\n';
        });
        _addLog('_searchCloudGroups: $groupLog');
      } else {
        _addLog('_searchCloudGroups failed，code: ${result.code} desc: ${result.desc}');
      }
    } catch (e) {
      _addLog('_searchCloudGroupMembers failed: $e');
    }
  }

  // 设置群计数器
  Future<void> _setGroupCounters() async {
    if (_groupIDController.text.isEmpty) {
      _addLog('请输入群组ID');
      return;
    }
    try {
      final result = await TencentImSDKPlugin.v2TIMManager.getGroupManager().setGroupCounters(
        groupID: _groupIDController.text,
        counters: {
          'counterKey1': 1,
          'counterKey2': 2,
        },
      );
      _addLog('设置群计数器成功: ${result.toJson()}');
    } catch (e) {
      _addLog('设置群计数器失败: $e');
    }
  }

  // 获取群计数器
  Future<void> _getGroupCounters() async {
    if (_groupIDController.text.isEmpty) {
      _addLog('请输入群组ID');
      return;
    }
    try {
      final result = await TencentImSDKPlugin.v2TIMManager.getGroupManager().getGroupCounters(
        groupID: _groupIDController.text,
        keys: ['counterKey1', 'counterKey2'],
      );
      _addLog('获取群计数器成功: ${result.toJson()}');
    } catch (e) {
      _addLog('获取群计数器失败: $e');
    }
  }

  // 递增群计数器
  Future<void> _increaseGroupCounter() async {
    if (_groupIDController.text.isEmpty) {
      _addLog('请输入群组ID');
      return;
    }
    try {
      final result = await TencentImSDKPlugin.v2TIMManager.getGroupManager().increaseGroupCounter(
        groupID: _groupIDController.text,
        key: 'counterKey1',
        value: 1,
      );
      _addLog('递增群计数器成功: ${result.toJson()}');
    } catch (e) {
      _addLog('递增群计数器失败: $e');
    }
  }

  // 递减群计数器
  Future<void> _decreaseGroupCounter() async {
    if (_groupIDController.text.isEmpty) {
      _addLog('请输入群组ID');
      return;
    }
    try {
      final result = await TencentImSDKPlugin.v2TIMManager.getGroupManager().decreaseGroupCounter(
        groupID: _groupIDController.text,
        key: 'counterKey1',
        value: 1,
      );
      _addLog('递减群计数器成功: ${result.toJson()}');
    } catch (e) {
      _addLog('递减群计数器失败: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final inputFields = [
      // 群组ID和群组名称
      Row(
        children: [
          // 群组ID
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('群组ID:', style: TextStyle(fontSize: 12)),
                SizedBox(
                  height: 30,
                  child: TextField(
                    controller: _groupIDController,
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
          // 群组名称
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('群组名称:', style: TextStyle(fontSize: 12)),
                SizedBox(
                  height: 30,
                  child: TextField(
                    controller: _groupNameController,
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

      // 搜索选项
      Row(
        children: [
          Expanded(
            child: CheckboxListTile(
              title: const Text('搜索群ID', style: TextStyle(fontSize: 12)),
              value: _isSearchGroupID,
              onChanged: (bool? value) {
                setState(() {
                  _isSearchGroupID = value ?? true;
                });
              },
              contentPadding: EdgeInsets.zero,
            ),
          ),
          Expanded(
            child: CheckboxListTile(
              title: const Text('搜索群名称', style: TextStyle(fontSize: 12)),
              value: _isSearchGroupName,
              onChanged: (bool? value) {
                setState(() {
                  _isSearchGroupName = value ?? true;
                });
              },
              contentPadding: EdgeInsets.zero,
            ),
          ),
        ],
      ),

      // 群成员搜索选项
      Row(
        children: [
          // 是否搜索群成员ID
          Expanded(
            child: CheckboxListTile(
              title: const Text('搜索成员ID', style: TextStyle(fontSize: 12)),
              value: _isSearchMemberUserID,
              onChanged: (bool? value) {
                setState(() {
                  _isSearchMemberUserID = value ?? true;
                });
              },
              contentPadding: EdgeInsets.zero,
              dense: true,
            ),
          ),
          // 是否搜索群成员昵称
          Expanded(
            child: CheckboxListTile(
              title: const Text('搜索成员昵称', style: TextStyle(fontSize: 12)),
              value: _isSearchMemberNickName,
              onChanged: (bool? value) {
                setState(() {
                  _isSearchMemberNickName = value ?? true;
                });
              },
              contentPadding: EdgeInsets.zero,
              dense: true,
            ),
          ),
        ],
      ),

      // 群成员搜索选项（续）
      Row(
        children: [
          // 是否搜索群成员备注
          Expanded(
            child: CheckboxListTile(
              title: const Text('搜索成员备注', style: TextStyle(fontSize: 12)),
              value: _isSearchMemberRemark,
              onChanged: (bool? value) {
                setState(() {
                  _isSearchMemberRemark = value ?? true;
                });
              },
              contentPadding: EdgeInsets.zero,
              dense: true,
            ),
          ),
          // 是否搜索群成员名片
          Expanded(
            child: CheckboxListTile(
              title: const Text('搜索成员名片', style: TextStyle(fontSize: 12)),
              value: _isSearchMemberNameCard,
              onChanged: (bool? value) {
                setState(() {
                  _isSearchMemberNameCard = value ?? true;
                });
              },
              contentPadding: EdgeInsets.zero,
              dense: true,
            ),
          ),
        ],
      ),

      // 群组类型和用户ID列表
      Row(
        children: [
          // 群组类型
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('群组类型:', style: TextStyle(fontSize: 12)),
                SizedBox(
                  height: 30,
                  child: DropdownButtonFormField<String>(
                    value: _groupTypeController.text.isEmpty ? null : _groupTypeController.text,
                    decoration: const InputDecoration(
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'Work', child: Text('Work', style: TextStyle(fontSize: 13))),
                      DropdownMenuItem(value: 'Public', child: Text('Public', style: TextStyle(fontSize: 13))),
                      DropdownMenuItem(value: 'Meeting', child: Text('Meeting', style: TextStyle(fontSize: 13))),
                      DropdownMenuItem(value: 'Community', child: Text('Community', style: TextStyle(fontSize: 13))),
                      DropdownMenuItem(value: 'AVChatRoom', child: Text('AVChatRoom', style: TextStyle(fontSize: 13))),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _groupTypeController.text = value ?? '';
                      });
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // 用户ID列表
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('用户ID列表:', style: TextStyle(fontSize: 12)),
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
      const SizedBox(height: 4),

      // 群组简介和群组公告
      Row(
        children: [
          // 群组简介
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('群组简介:', style: TextStyle(fontSize: 12)),
                SizedBox(
                  height: 30,
                  child: TextField(
                    controller: _groupIntroductionController,
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
          // 群组公告
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('群组公告:', style: TextStyle(fontSize: 12)),
                SizedBox(
                  height: 30,
                  child: TextField(
                    controller: _groupNotificationController,
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

      // 群组头像和群成员角色
      Row(
        children: [
          // 群组头像
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('群组头像:', style: TextStyle(fontSize: 12)),
                SizedBox(
                  height: 30,
                  child: TextField(
                    controller: _groupFaceURLController,
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
          // 群成员角色
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('群成员角色:', style: TextStyle(fontSize: 12)),
                SizedBox(
                  height: 30,
                  child: TextField(
                    controller: _roleController,
                    style: const TextStyle(fontSize: 13),
                    decoration: const InputDecoration(
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      border: OutlineInputBorder(),
                      hintText: '0:普通成员 1:管理员 2:群主',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      const SizedBox(height: 4),

      // 群成员ID和群名片输入框
      Row(
        children: [
          // 群成员ID
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('群成员ID:', style: TextStyle(fontSize: 12)),
                SizedBox(
                  height: 30,
                  child: TextField(
                    controller: _userIDController,
                    style: const TextStyle(fontSize: 13),
                    decoration: const InputDecoration(
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      border: OutlineInputBorder(),
                      hintText: '输入成员ID',
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // 群名片
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('群名片:', style: TextStyle(fontSize: 12)),
                SizedBox(
                  height: 30,
                  child: TextField(
                    controller: _nameCardController,
                    style: const TextStyle(fontSize: 13),
                    decoration: const InputDecoration(
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      border: OutlineInputBorder(),
                      hintText: '设置群名片',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      const SizedBox(height: 4),

      // 禁言时长和原因输入框
      Row(
        children: [
          // 禁言时长
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('禁言时长:', style: TextStyle(fontSize: 12)),
                SizedBox(
                  height: 30,
                  child: TextField(
                    controller: _secondsController,
                    style: const TextStyle(fontSize: 13),
                    decoration: const InputDecoration(
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      border: OutlineInputBorder(),
                      hintText: '单位:秒',
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // 原因
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('操作原因:', style: TextStyle(fontSize: 12)),
                SizedBox(
                  height: 30,
                  child: TextField(
                    controller: _reasonController,
                    style: const TextStyle(fontSize: 13),
                    decoration: const InputDecoration(
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      border: OutlineInputBorder(),
                      hintText: '踢人或处理申请原因',
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
      _buildDynamicButton('创建群组', _createGroup),
      _buildDynamicButton('获取已加入群组列表', _getJoinedGroupList),
      _buildDynamicButton('获取群组信息', _getGroupsInfo),
      _buildDynamicButton('设置群组信息', _setGroupInfo),
      _buildDynamicButton('初始化群属性', _initGroupAttributes),
      _buildDynamicButton('设置群属性', _setGroupAttributes),
      _buildDynamicButton('删除群属性', _deleteGroupAttributes),
      _buildDynamicButton('获取群属性', _getGroupAttributes),
      _buildDynamicButton('获取群成员列表', _getGroupMemberList),
      _buildDynamicButton('获取群成员资料', _getGroupMembersInfo),
      _buildDynamicButton('修改群成员资料', _setGroupMemberInfo),
      _buildDynamicButton('禁言群成员', _muteGroupMember),
      _buildDynamicButton('禁言全体群成员', () => _muteAllGroupMembers(true)),
      _buildDynamicButton('解除全体禁言', () => _muteAllGroupMembers(false)),
      _buildDynamicButton('邀请他人入群', _inviteUserToGroup),
      _buildDynamicButton('踢人', _kickGroupMember),
      _buildDynamicButton('设置群成员角色', _setGroupMemberRole),
      _buildDynamicButton('转让群主', _transferGroupOwner),
      _buildDynamicButton('标记群成员', _markGroupMemberList),
      _buildDynamicButton('获取群组申请列表', _getGroupApplicationList),
      _buildDynamicButton('接受加群申请', _acceptGroupApplication),
      _buildDynamicButton('拒绝加群申请', _refuseGroupApplication),
      _buildDynamicButton('获取群组在线人数', _getGroupOnlineMemberCount),
      _buildDynamicButton('标记群组申请已读', _setGroupApplicationRead),
      _buildDynamicButton('搜索群组', _searchGroups),
      _buildDynamicButton('搜索群成员', _searchGroupMembers),
      _buildDynamicButton('搜索云端群组', _searchCloudGroups),
      _buildDynamicButton('搜索云端群成员', _searchCloudGroupMembers),
      _buildDynamicButton('设置群计数器', _setGroupCounters),
      _buildDynamicButton('获取群计数器', _getGroupCounters),
      _buildDynamicButton('递增群计数器', _increaseGroupCounter),
      _buildDynamicButton('递减群计数器', _decreaseGroupCounter),
    ];

    return BaseAPITest(
      title: '群组管理',
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
    _groupIDController.dispose();
    _groupNameController.dispose();
    _groupTypeController.dispose();
    _userIDListController.dispose();
    _groupIntroductionController.dispose();
    _groupNotificationController.dispose();
    _groupFaceURLController.dispose();
    _notificationController.dispose();
    _introductionController.dispose();
    _faceUrlController.dispose();
    _isAllMutedController.dispose();
    _isSupportTopicController.dispose();
    _addOptController.dispose();
    _approveOptController.dispose();
    _isEnablePermissionGroupController.dispose();
    _defaultPermissionsController.dispose();
    _nextSeqController.dispose();
    _countController.dispose();
    _nameCardController.dispose();
    _userIDController.dispose();
    _secondsController.dispose();
    _reasonController.dispose();
    _fromUserController.dispose();
    _toUserController.dispose();
    _addTimeController.dispose();
    _typeController.dispose();
    _roleController.dispose();
    super.dispose();
  }
}