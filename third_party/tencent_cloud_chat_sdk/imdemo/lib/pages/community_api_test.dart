import 'package:flutter/material.dart';
import 'package:tencent_cloud_chat_sdk/enum/group_member_role_enum.dart';
import 'package:tencent_cloud_chat_sdk/enum/group_type.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_create_group_member_info.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_create_group_member_info.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_group_info.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_group_info.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_permission_group_info.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_permission_group_info.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_topic_info.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_topic_info.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_topic_info_result.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_topic_info_result.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_value_callback.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_value_callback.dart';
import 'package:tencent_cloud_chat_sdk/tencent_im_sdk_plugin.dart';
import 'package:tencent_cloud_chat_sdk_example/utils/log_manager.dart';
import 'base_api_test.dart';

class CommunityAPITest extends StatefulWidget {
  const CommunityAPITest({Key? key}) : super(key: key);

  @override
  State<CommunityAPITest> createState() => _CommunityAPITestState();
}

class _CommunityAPITestState extends State<CommunityAPITest> {
  final TextEditingController _groupIDController = TextEditingController();
  final TextEditingController _groupNameController = TextEditingController();
  final TextEditingController _userIDListController = TextEditingController();
  final TextEditingController _groupFaceURLController = TextEditingController();
  final TextEditingController _topicIDController = TextEditingController();
  final TextEditingController _topicNameController = TextEditingController();
  final TextEditingController _topicCustomDataController = TextEditingController();
  final TextEditingController _permissionGroupIDController = TextEditingController();
  final TextEditingController _permissionGroupNameController = TextEditingController();
  final TextEditingController _permissionGroupDescriptionController = TextEditingController();
  final TextEditingController _permissionGroupCustomDataController = TextEditingController();
  final TextEditingController _nextCursorController = TextEditingController(text: '0');
  final TextEditingController _countController = TextEditingController(text: '20');
  final TextEditingController _topicPermissionController = TextEditingController(text: '1');

  // 使用全局日志管理器和监听器管理器
  final LogManager _logManager = LogManager();

  @override
  void initState() {
    super.initState();
    _topicNameController.text = '话题名称测试';
  }

  // 添加日志的帮助方法
  void _addLog(String text) {
    _logManager.updateLogText(text);
  }

  // 更新社区日志
  void _updateCommunityLog(String text) {
    _logManager.updateCommunityLog(text);
  }

  // 清空日志
  void _clearLog() {
    _logManager.clearAllLogs();
  }

  // 创建社群
  Future<void> _createCommunity() async {
    if (_groupNameController.text.isEmpty) {
      _addLog('请输入群组名称');
      return;
    }
    try {
      final info = V2TimGroupInfo(
        groupID: _groupIDController.text,
        groupType: GroupType.Community,
        isSupportTopic: true,
        groupName: _groupNameController.text,
        faceUrl: _groupFaceURLController.text.isEmpty ? null : _groupFaceURLController.text,
      );

      List<V2TimCreateGroupMemberInfo> memberList = _userIDListController.text.isEmpty ? [] :
        _userIDListController.text.split(',').map((e) => 
          V2TimCreateGroupMemberInfo(
            userID: e,
            role: GroupMemberRoleTypeEnum.V2TIM_GROUP_MEMBER_ROLE_MEMBER.index,
          )
        ).toList();

      final result = await TencentImSDKPlugin.v2TIMManager.getCommunityManager().createCommunity(
        info: info,
        memberList: memberList,
      );
      _addLog('创建社群: ${result.toJson()}');
    } catch (e) {
      _addLog('创建社群失败: $e');
    }
  }

  // 获取已加入的社群列表
  Future<void> _getJoinedCommunityList() async {
    try {
      V2TimValueCallback<List<V2TimGroupInfo>> result = await TencentImSDKPlugin.v2TIMManager.getCommunityManager().getJoinedCommunityList();
      if (result.code == 0) {
        String groupInfoLog = '';
        for (V2TimGroupInfo groupInfo in result.data!) {
          groupInfoLog += '${groupInfo.toLogString()}\n\n';
        }
        _addLog('获取已加入的社群列表: $groupInfoLog');
      } else {
        _addLog('获取已加入的社群列表失败, code: ${result.code}, desc: ${result.desc}');
      }
    } catch (e) {
      _addLog('获取已加入的社群列表失败: $e');
    }
  }

  // 创建话题
  Future<void> _createTopicInCommunity() async {
    if (_groupIDController.text.isEmpty || _topicNameController.text.isEmpty) {
      _addLog('请输入群组ID和话题名称');
      return;
    }
    try {
      final topicInfo = V2TimTopicInfo(
        topicName: _topicNameController.text,
        customString: _topicCustomDataController.text.isEmpty ? null : _topicCustomDataController.text,
      );

      final result = await TencentImSDKPlugin.v2TIMManager.getCommunityManager().createTopicInCommunity(
        groupID: _groupIDController.text,
        topicInfo: topicInfo,
      );
      _addLog('创建话题成功: ${result.toJson()}');
    } catch (e) {
      _addLog('创建话题失败: $e');
    }
  }

  // 删除话题
  Future<void> _deleteTopicFromCommunity() async {
    if (_groupIDController.text.isEmpty || _topicIDController.text.isEmpty) {
      _addLog('请输入群组ID和话题ID');
      return;
    }
    try {
      final result = await TencentImSDKPlugin.v2TIMManager.getCommunityManager().deleteTopicFromCommunity(
        groupID: _groupIDController.text,
        topicIDList: [_topicIDController.text],
      );
      _addLog('删除话题成功: ${result.toJson()}');
    } catch (e) {
      _addLog('删除话题失败: $e');
    }
  }

  // 修改话题信息
  Future<void> _setTopicInfo() async {
    if (_groupIDController.text.isEmpty || _topicIDController.text.isEmpty) {
      _addLog('请输入群组ID、话题ID和话题名称');
      return;
    }
    try {
      final topicInfo = V2TimTopicInfo(
        topicID: _topicIDController.text,
        topicName: _topicNameController.text,
        customString: _topicCustomDataController.text.isEmpty ? null : _topicCustomDataController.text,
      );

      final result = await TencentImSDKPlugin.v2TIMManager.getCommunityManager().setTopicInfo(
        topicInfo: topicInfo,
      );
      _addLog('修改话题信息成功: ${result.toJson()}');
    } catch (e) {
      _addLog('修改话题信息失败: $e');
    }
  }

  // 获取话题列表
  Future<void> _getTopicInfoList() async {
    if (_groupIDController.text.isEmpty) {
      _addLog('请输入群组ID和话题ID');
      return;
    }
    try {
      V2TimValueCallback<List<V2TimTopicInfoResult>> result = await TencentImSDKPlugin.v2TIMManager.getCommunityManager().getTopicInfoList(
        groupID: _groupIDController.text,
        topicIDList: [],
        // topicIDList: _topicIDController.text.isEmpty ? [] : _topicIDController.text.split(','),
      );

      if (result.code == 0) {
        String topicLog = '';
        for (V2TimTopicInfoResult topicInfoResult in result.data!) {
          topicLog += '${topicInfoResult.toJson()}\n\n';
        }
        _addLog('获取话题列表: $topicLog');
      } else {
        _addLog('获取话题列表失败, code: ${result.code}, desc: ${result.desc}');
      }
    } catch (e) {
      _addLog('获取话题列表失败: $e');
    }
  }

  // 创建权限组
  Future<void> _createPermissionGroupInCommunity() async {
    if (_groupIDController.text.isEmpty || _permissionGroupNameController.text.isEmpty) {
      _addLog('请输入群组ID和权限组名称');
      return;
    }
    try {
      final info = V2TimPermissionGroupInfo(
        groupID: _groupIDController.text,
        permissionGroupID: _permissionGroupIDController.text,
        permissionGroupName: _permissionGroupNameController.text,
        customData: _permissionGroupCustomDataController.text.isEmpty ? null : _permissionGroupCustomDataController.text,
        groupPermission: 0,
      );

      final result = await TencentImSDKPlugin.v2TIMManager.getCommunityManager().createPermissionGroupInCommunity(
        info: info,
      );
      _addLog('创建权限组成功: ${result.toJson()}');
    } catch (e) {
      _addLog('创建权限组失败: $e');
    }
  }

  // 删除权限组
  Future<void> _deletePermissionGroupFromCommunity() async {
    if (_groupIDController.text.isEmpty || _permissionGroupIDController.text.isEmpty) {
      _addLog('请输入群组ID和权限组ID');
      return;
    }
    try {
      final result = await TencentImSDKPlugin.v2TIMManager.getCommunityManager().deletePermissionGroupFromCommunity(
        groupID: _groupIDController.text,
        permissionGroupIDList: [_permissionGroupIDController.text],
      );
      _addLog('删除权限组成功: ${result.toJson()}');
    } catch (e) {
      _addLog('删除权限组失败: $e');
    }
  }

  // 修改权限组信息
  Future<void> _modifyPermissionGroupInfoInCommunity() async {
    if (_groupIDController.text.isEmpty || _permissionGroupIDController.text.isEmpty || _permissionGroupNameController.text.isEmpty) {
      _addLog('请输入群组ID、权限组ID和权限组名称');
      return;
    }
    try {
      final info = V2TimPermissionGroupInfo(
        groupID: _groupIDController.text,
        permissionGroupID: _permissionGroupIDController.text,
        permissionGroupName: _permissionGroupNameController.text,
        customData: _permissionGroupCustomDataController.text.isEmpty ? null : _permissionGroupCustomDataController.text,
        groupPermission: 0,
        memberCount: 0,
      );

      final result = await TencentImSDKPlugin.v2TIMManager.getCommunityManager().modifyPermissionGroupInfoInCommunity(
        info: info,
      );
      _addLog('修改权限组信息成功: ${result.toJson()}');
    } catch (e) {
      _addLog('修改权限组信息失败: $e');
    }
  }

  // 获取已加入的权限组列表
  Future<void> _getJoinedPermissionGroupListInCommunity() async {
    if (_groupIDController.text.isEmpty) {
      _addLog('请输入群组ID');
      return;
    }
    try {
      final result = await TencentImSDKPlugin.v2TIMManager.getCommunityManager().getJoinedPermissionGroupListInCommunity(
        groupID: _groupIDController.text,
      );
      _addLog('获取已加入的权限组列表成功: ${result.toJson()}');
    } catch (e) {
      _addLog('获取已加入的权限组列表失败: $e');
    }
  }

  // 获取权限组列表
  Future<void> _getPermissionGroupListInCommunity() async {
    if (_groupIDController.text.isEmpty || _permissionGroupIDController.text.isEmpty) {
      _addLog('请输入群组ID和权限组ID');
      return;
    }
    try {
      final result = await TencentImSDKPlugin.v2TIMManager.getCommunityManager().getPermissionGroupListInCommunity(
        groupID: _groupIDController.text,
        permissionGroupIDList: [_permissionGroupIDController.text],
      );
      _addLog('获取权限组列表成功: ${result.toJson()}');
    } catch (e) {
      _addLog('获取权限组列表失败: $e');
    }
  }

  // 添加成员到权限组
  Future<void> _addCommunityMembersToPermissionGroup() async {
    if (_groupIDController.text.isEmpty || _permissionGroupIDController.text.isEmpty || _userIDListController.text.isEmpty) {
      _addLog('请输入群组ID、权限组ID和用户ID列表');
      return;
    }
    try {
      final result = await TencentImSDKPlugin.v2TIMManager.getCommunityManager().addCommunityMembersToPermissionGroup(
        groupID: _groupIDController.text,
        permissionGroupID: _permissionGroupIDController.text,
        memberList: _userIDListController.text.split(','),
      );
      _addLog('添加成员到权限组成功: ${result.toJson()}');
    } catch (e) {
      _addLog('添加成员到权限组失败: $e');
    }
  }

  // 从权限组移除成员
  Future<void> _removeCommunityMembersFromPermissionGroup() async {
    if (_groupIDController.text.isEmpty || _permissionGroupIDController.text.isEmpty || _userIDListController.text.isEmpty) {
      _addLog('请输入群组ID、权限组ID和用户ID列表');
      return;
    }
    try {
      final result = await TencentImSDKPlugin.v2TIMManager.getCommunityManager().removeCommunityMembersFromPermissionGroup(
        groupID: _groupIDController.text,
        permissionGroupID: _permissionGroupIDController.text,
        memberList: _userIDListController.text.split(','),
      );
      _addLog('从权限组移除成员成功: ${result.toJson()}');
    } catch (e) {
      _addLog('从权限组移除成员失败: $e');
    }
  }

  // 获取权限组中的成员列表
  Future<void> _getCommunityMemberListInPermissionGroup() async {
    if (_groupIDController.text.isEmpty || _permissionGroupIDController.text.isEmpty) {
      _addLog('请输入群组ID和权限组ID');
      return;
    }
    try {
      final result = await TencentImSDKPlugin.v2TIMManager.getCommunityManager().getCommunityMemberListInPermissionGroup(
        groupID: _groupIDController.text,
        permissionGroupID: _permissionGroupIDController.text,
        nextCursor: _nextCursorController.text.isEmpty ? "0" : _nextCursorController.text,
      );
      _addLog('获取权限组中的成员列表成功: ${result.toJson()}');
    } catch (e) {
      _addLog('获取权限组中的成员列表失败: $e');
    }
  }

  // 添加话题权限到权限组
  Future<void> _addTopicPermissionToPermissionGroup() async {
    if (_groupIDController.text.isEmpty || _permissionGroupIDController.text.isEmpty || _topicIDController.text.isEmpty) {
      _addLog('请输入群组ID、权限组ID和话题ID');
      return;
    }
    try {
      // 创建话题权限Map，包含两个值用于测试
      Map<String, int> topicPermissionMap = {
        _topicIDController.text: int.parse(_topicPermissionController.text),
        "${_topicIDController.text}_2": int.parse(_topicPermissionController.text) + 1,
      };
      
      final result = await TencentImSDKPlugin.v2TIMManager.getCommunityManager().addTopicPermissionToPermissionGroup(
        groupID: _groupIDController.text,
        permissionGroupID: _permissionGroupIDController.text,
        topicPermissionMap: topicPermissionMap,
      );
      _addLog('添加话题权限成功: ${result.toJson()}');
    } catch (e) {
      _addLog('添加话题权限失败: $e');
    }
  }

  // 从权限组删除话题权限
  Future<void> _deleteTopicPermissionFromPermissionGroup() async {
    if (_groupIDController.text.isEmpty || _permissionGroupIDController.text.isEmpty) {
      _addLog('请输入群组ID和权限组ID');
      return;
    }
    
    List<String> topicIDList = [];
    if (_topicIDController.text.isNotEmpty) {
      // 如果没有指定话题ID列表，则使用单个话题ID
      topicIDList = [_topicIDController.text];
    } else {
      _addLog('请输入话题ID或话题ID列表');
      return;
    }
    
    try {
      final result = await TencentImSDKPlugin.v2TIMManager.getCommunityManager().deleteTopicPermissionFromPermissionGroup(
        groupID: _groupIDController.text,
        permissionGroupID: _permissionGroupIDController.text,
        topicIDList: topicIDList,
      );
      _addLog('删除话题权限成功: ${result.toJson()}');
    } catch (e) {
      _addLog('删除话题权限失败: $e');
    }
  }

  // 修改权限组中的话题权限
  Future<void> _modifyTopicPermissionInPermissionGroup() async {
    if (_groupIDController.text.isEmpty || _permissionGroupIDController.text.isEmpty || _topicIDController.text.isEmpty) {
      _addLog('请输入群组ID、权限组ID和话题ID');
      return;
    }
    try {
      // 创建话题权限Map，包含两个值用于测试
      Map<String, int> topicPermissionMap = {
        _topicIDController.text: int.parse(_topicPermissionController.text),
        "${_topicIDController.text}_2": int.parse(_topicPermissionController.text) + 1,
      };
      
      final result = await TencentImSDKPlugin.v2TIMManager.getCommunityManager().modifyTopicPermissionInPermissionGroup(
        groupID: _groupIDController.text,
        permissionGroupID: _permissionGroupIDController.text,
        topicPermissionMap: topicPermissionMap,
      );
      _addLog('修改话题权限成功: ${result.toJson()}');
    } catch (e) {
      _addLog('修改话题权限失败: $e');
    }
  }

  // 获取权限组中的话题权限
  Future<void> _getTopicPermissionInPermissionGroup() async {
    if (_groupIDController.text.isEmpty || _permissionGroupIDController.text.isEmpty) {
      _addLog('请输入群组ID和权限组ID');
      return;
    }
    
    List<String> topicIDList = [];
    if (_topicIDController.text.isNotEmpty) {
      // 如果没有指定话题ID列表，则使用单个话题ID
      topicIDList = [_topicIDController.text];
    } else {
      _addLog('请输入话题ID或话题ID列表');
      return;
    }
    
    try {
      final result = await TencentImSDKPlugin.v2TIMManager.getCommunityManager().getTopicPermissionInPermissionGroup(
        groupID: _groupIDController.text,
        permissionGroupID: _permissionGroupIDController.text,
        topicIDList: topicIDList,
      );
      _addLog('获取话题权限成功: ${result.toJson()}');
    } catch (e) {
      _addLog('获取话题权限失败: $e');
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
                    style: const TextStyle(fontSize: 11),
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
      
      // 用户ID列表和群组头像
      Row(
        children: [
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
          const SizedBox(width: 8),
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
        ],
      ),
      const SizedBox(height: 4),
      
      // 话题ID和话题名称
      Row(
        children: [
          // 话题ID
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('话题ID:', style: TextStyle(fontSize: 12)),
                SizedBox(
                  height: 30,
                  child: TextField(
                    controller: _topicIDController,
                    style: const TextStyle(fontSize: 11),
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
          // 话题名称
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('话题名称:', style: TextStyle(fontSize: 12)),
                SizedBox(
                  height: 30,
                  child: TextField(
                    controller: _topicNameController,
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
      
      // 话题自定义数据和权限组ID
      Row(
        children: [
          // 话题自定义数据
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('话题自定义:', style: TextStyle(fontSize: 12)),
                SizedBox(
                  height: 30,
                  child: TextField(
                    controller: _topicCustomDataController,
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
          // 权限组ID
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('权限组ID:', style: TextStyle(fontSize: 12)),
                SizedBox(
                  height: 30,
                  child: TextField(
                    controller: _permissionGroupIDController,
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
      
      // 权限组名称和权限组描述
      Row(
        children: [
          // 权限组名称
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('权限组名称:', style: TextStyle(fontSize: 12)),
                SizedBox(
                  height: 30,
                  child: TextField(
                    controller: _permissionGroupNameController,
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
          // 权限组描述
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('权限组描述:', style: TextStyle(fontSize: 12)),
                SizedBox(
                  height: 30,
                  child: TextField(
                    controller: _permissionGroupDescriptionController,
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
      
      // 权限组自定义数据和下一页游标
      Row(
        children: [
          // 权限组自定义数据
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('权限组自定义:', style: TextStyle(fontSize: 12)),
                SizedBox(
                  height: 30,
                  child: TextField(
                    controller: _permissionGroupCustomDataController,
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
          // 下一页游标
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('下一页游标:', style: TextStyle(fontSize: 12)),
                SizedBox(
                  height: 30,
                  child: TextField(
                    controller: _nextCursorController,
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
      
      // 获取数量和话题权限
      Row(
        children: [
          // 获取数量
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('获取数量:', style: TextStyle(fontSize: 12)),
                SizedBox(
                  height: 30,
                  child: TextField(
                    controller: _countController,
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
          // 话题权限
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('话题权限值:', style: TextStyle(fontSize: 12)),
                SizedBox(
                  height: 30,
                  child: TextField(
                    controller: _topicPermissionController,
                    style: const TextStyle(fontSize: 13),
                    decoration: const InputDecoration(
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      border: OutlineInputBorder(),
                      hintText: '默认为1',
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
      _buildDynamicButton('创建社群', _createCommunity),
      _buildDynamicButton('获取已加入的社群列表', _getJoinedCommunityList),
      _buildDynamicButton('创建话题', _createTopicInCommunity),
      _buildDynamicButton('删除话题', _deleteTopicFromCommunity),
      _buildDynamicButton('修改话题信息', _setTopicInfo),
      _buildDynamicButton('获取话题列表', _getTopicInfoList),
      _buildDynamicButton('创建权限组', _createPermissionGroupInCommunity),
      _buildDynamicButton('删除权限组', _deletePermissionGroupFromCommunity),
      _buildDynamicButton('修改权限组信息', _modifyPermissionGroupInfoInCommunity),
      _buildDynamicButton('获取已加入的权限组列表', _getJoinedPermissionGroupListInCommunity),
      _buildDynamicButton('获取权限组列表', _getPermissionGroupListInCommunity),
      _buildDynamicButton('添加成员到权限组', _addCommunityMembersToPermissionGroup),
      _buildDynamicButton('从权限组移除成员', _removeCommunityMembersFromPermissionGroup),
      _buildDynamicButton('获取权限组中的成员列表', _getCommunityMemberListInPermissionGroup),
      _buildDynamicButton('添加话题权限', _addTopicPermissionToPermissionGroup),
      _buildDynamicButton('删除话题权限', _deleteTopicPermissionFromPermissionGroup),
      _buildDynamicButton('修改话题权限', _modifyTopicPermissionInPermissionGroup),
      _buildDynamicButton('获取话题权限', _getTopicPermissionInPermissionGroup),
    ];

    return BaseAPITest(
      title: '社群管理',
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
    _userIDListController.dispose();
    _groupFaceURLController.dispose();
    _topicIDController.dispose();
    _topicNameController.dispose();
    _topicCustomDataController.dispose();
    _permissionGroupIDController.dispose();
    _permissionGroupNameController.dispose();
    _permissionGroupDescriptionController.dispose();
    _permissionGroupCustomDataController.dispose();
    _nextCursorController.dispose();
    _countController.dispose();
    _topicPermissionController.dispose();
    super.dispose();
  }
} 