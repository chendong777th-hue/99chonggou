import 'package:flutter/material.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_conversation.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_conversation.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_conversation_filter.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_conversation_filter.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_conversation_result.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_conversation_result.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_value_callback.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_value_callback.dart';
import 'package:tencent_cloud_chat_sdk/tencent_im_sdk_plugin.dart';
import 'package:tencent_cloud_chat_sdk_example/utils/log_manager.dart';
import 'package:tencent_cloud_chat_sdk/enum/conversation_type.dart';
import 'package:tencent_cloud_chat_sdk/enum/v2_tim_conversation_marktype.dart';
import 'base_api_test.dart';

class ConversationAPITest extends StatefulWidget {
  const ConversationAPITest({Key? key}) : super(key: key);

  @override
  State<ConversationAPITest> createState() => _ConversationAPITestState();
}

class _ConversationAPITestState extends State<ConversationAPITest> {
  final TextEditingController _conversationIDController = TextEditingController();
  final TextEditingController _nextSeqController = TextEditingController();
  final TextEditingController _countController = TextEditingController();
  final TextEditingController _draftTextController = TextEditingController();
  final TextEditingController _markTypeController = TextEditingController();
  final TextEditingController _enableMarkController = TextEditingController();
  final TextEditingController _conversationIDListController = TextEditingController();
  final TextEditingController _customDataController = TextEditingController();
  final TextEditingController _groupNameController = TextEditingController();
  final TextEditingController _oldNameController = TextEditingController();
  final TextEditingController _newNameController = TextEditingController();
  final TextEditingController _isPinnedController = TextEditingController();
  final TextEditingController _clearMessageController = TextEditingController();
  final TextEditingController _filterTypeController = TextEditingController();
  final TextEditingController _filterConversationTypeController = TextEditingController();
  final TextEditingController _filterEnableMarkController = TextEditingController();
  final TextEditingController _cleanTimestampController = TextEditingController();
  final TextEditingController _cleanSequenceController = TextEditingController();

  // 布尔值状态
  bool _clearMessageValue = false;
  bool _enableMarkValue = false;
  bool _isPinnedValue = false;
  bool _filterHasUnreadCountValue = false;
  bool _hasGroupAtInfoValue = false;

  // 使用全局日志管理器
  final LogManager _logManager = LogManager();

  int _selectedConversationType = ConversationType.CONVERSATION_TYPE_INVALID;
  int _selectedMarkType = 0;
  // 用于存储选中的过滤标记类型
  final Set<int> _selectedFilterMarkTypes = <int>{};
  
  final Map<int, String> _conversationTypeMap = {
    ConversationType.CONVERSATION_TYPE_INVALID: '非法类型',
    ConversationType.V2TIM_C2C: '单聊',
    ConversationType.V2TIM_GROUP: '群聊',
  };
  
  final Map<int, String> _markTypeMap = {
    0: '无标记',
    V2TimConversationMarkType.V2TIM_CONVERSATION_MARK_TYPE_STAR: '会话标星',
    V2TimConversationMarkType.V2TIM_CONVERSATION_MARK_TYPE_UNREAD: '会话标记未读',
    V2TimConversationMarkType.V2TIM_CONVERSATION_MARK_TYPE_FOLD: '会话折叠',
    V2TimConversationMarkType.V2TIM_CONVERSATION_MARK_TYPE_HIDE: '会话隐藏',
    0x1 << 33 : '自定义标记',
  };

  @override
  void initState() {
    super.initState();

    _conversationIDController.text = 'c2c_teacher13';
    _conversationIDListController.text = 'c2c_teacher13,c2c_teacher15';
    _customDataController.text = 'custom data test';
    _groupNameController.text = 'flutterGROUP';
    _oldNameController.text = 'flutterGROUP';
    _newNameController.text = 'flutterGROUP2';
  }

  // 添加日志的帮助方法
  void _addLog(String log) {
    _logManager.updateLogText(log);
  }

  // 清空日志
  void _clearLog() {
    _logManager.clearAllLogs();
  }

  // 获取会话列表
  Future<void> _getConversationList() async {
    try {
      final result = await TencentImSDKPlugin.v2TIMManager
          .getConversationManager()
          .getConversationList(
            nextSeq: _nextSeqController.text.isEmpty ? "0" : _nextSeqController.text,
            count: int.tryParse(_countController.text) ?? 20,
          );
      if (result.code == 0) {
        V2TimConversationResult conversationResult = result.data!;
        _addLog('获取会话列表成功: nextSeq:${conversationResult.nextSeq}, isFinished:${conversationResult.isFinished}');
        for (var conversation in conversationResult.conversationList!) {
          _addLog('会话: ${conversation?.toJson()}\n');
        }
      } else {
        _addLog('获取会话列表失败, code:${result.code}|desc:${result.desc}');
      }
    } catch (e) {
      _addLog('获取会话列表失败: $e');
    }
  }

  // 获取会话列表(不格式化)
  Future<void> _getConversationListWithoutFormat() async {
    try {
      final result = await TencentImSDKPlugin.v2TIMManager
          .getConversationManager()
          .getConversationListWithoutFormat(
            nextSeq: _nextSeqController.text.isEmpty ? "0" : _nextSeqController.text,
            count: int.tryParse(_countController.text) ?? 20,
          );
      _addLog('获取会话列表(不格式化)成功: $result');
    } catch (e) {
      _addLog('获取会话列表(不格式化)失败: $e');
    }
  }

  // 获取会话信息
  Future<void> _getConversationInfo() async {
    try {
      final result = await TencentImSDKPlugin.v2TIMManager
          .getConversationManager()
          .getConversation(
            conversationID: _conversationIDController.text,
          );
      _addLog('获取会话信息成功: ${result.toLogString()}');
    } catch (e) {
      _addLog('获取会话信息失败: $e');
    }
  }

  // 设置会话草稿
  Future<void> _setConversationDraft() async {
    try {
      final result = await TencentImSDKPlugin.v2TIMManager
          .getConversationManager()
          .setConversationDraft(
            conversationID: _conversationIDController.text,
            draftText: _draftTextController.text,
          );
      _addLog('设置会话草稿成功: ${result.toJson()}');
    } catch (e) {
      _addLog('设置会话草稿失败: $e');
    }
  }

  // 删除会话
  Future<void> _deleteConversation() async {
    try {
      final result = await TencentImSDKPlugin.v2TIMManager
          .getConversationManager()
          .deleteConversation(
            conversationID: _conversationIDController.text,
          );
      _addLog('删除会话成功: ${result.toJson()}');
    } catch (e) {
      _addLog('删除会话失败: $e');
    }
  }

  // 删除会话列表
  Future<void> _deleteConversationList() async {
    try {
      final result = await TencentImSDKPlugin.v2TIMManager
          .getConversationManager()
          .deleteConversationList(
            conversationIDList: _conversationIDListController.text.split(','),
            clearMessage: _clearMessageValue,
          );
      _addLog('删除会话列表成功: ${result.toJson()}');
    } catch (e) {
      _addLog('删除会话列表失败: $e');
    }
  }

  // 标记会话
  Future<void> _markConversation() async {
    try {
      final result = await TencentImSDKPlugin.v2TIMManager
          .getConversationManager()
          .markConversation(
            conversationIDList: [_conversationIDController.text],
            markType: _selectedMarkType,
            enableMark: _enableMarkValue,
          );
      _addLog('标记会话: ${result.toJson()}');
    } catch (e) {
      _addLog('标记会话失败: $e');
    }
  }

  // 获取会话列表
  Future<void> _getConversationListByID() async {
    try {
      V2TimValueCallback<List<V2TimConversation>> result = await TencentImSDKPlugin.v2TIMManager
          .getConversationManager()
          .getConversationListByConversationIds(
            conversationIDList: _conversationIDListController.text.split(','),
          );
      if (result.code == 0) {
        List<V2TimConversation>? list = result.data ?? [];
        String conversationListLog = '';
        for (V2TimConversation conversation in list)  {
          conversationListLog += '${conversation.toLogString()}\n\n';
        }

        _addLog('获取会话列表成功: \n$conversationListLog');
      } else {
        _addLog('获取会话列表失败, code:${result.code}|desc:${result.desc}');
      }
    } catch (e) {
      _addLog('获取会话列表失败: $e');
    }
  }

  // 设置会话自定义数据
  Future<void> _setConversationCustomData() async {
    try {
      final result = await TencentImSDKPlugin.v2TIMManager
          .getConversationManager()
          .setConversationCustomData(
            customData: _customDataController.text,
            conversationIDList: _conversationIDListController.text.split(','),
          );
      _addLog('设置会话自定义数据成功: ${result.toJson()}');
    } catch (e) {
      _addLog('设置会话自定义数据失败: $e');
    }
  }

  // 会话置顶
  Future<void> _pinConversation() async {
    try {
      final result = await TencentImSDKPlugin.v2TIMManager
          .getConversationManager()
          .pinConversation(
            conversationID: _conversationIDController.text,
            isPinned: _isPinnedValue,
          );
      _addLog('会话置顶($_isPinnedValue)成功: ${result.toJson()}');
    } catch (e) {
      _addLog('会话置顶失败: $e');
    }
  }

  // 获取会话未读总数
  Future<void> _getTotalUnreadMessageCount() async {
    try {
      final result = await TencentImSDKPlugin.v2TIMManager
          .getConversationManager()
          .getTotalUnreadMessageCount();
      if (result.code == 0) {
        _addLog('获取会话未读总数: ${result.data}');
      } else {
        _addLog('获取会话未读总数失败, code:${result.code}|desc:${result.desc}');
      }
    } catch (e) {
      _addLog('获取会话未读总数失败: $e');
    }
  }

  // 创建会话分组
  Future<void> _createConversationGroup() async {
    try {
      final result = await TencentImSDKPlugin.v2TIMManager
          .getConversationManager()
          .createConversationGroup(
            groupName: _groupNameController.text,
            conversationIDList: _conversationIDListController.text.split(','),
          );
      _addLog('创建会话分组成功: ${result.toJson()}');
    } catch (e) {
      _addLog('创建会话分组失败: $e');
    }
  }

  // 获取会话分组列表
  Future<void> _getConversationGroupList() async {
    try {
      final result = await TencentImSDKPlugin.v2TIMManager
          .getConversationManager()
          .getConversationGroupList();
      if (result.code == 0) {
        _addLog('获取会话分组列表: ${result.data}');
      } else {
        _addLog('获取会话分组列表失败, code:${result.code}|desc:${result.desc}');
      }
    } catch (e) {
      _addLog('获取会话分组列表失败: $e');
    }
  }

  // 删除会话分组
  Future<void> _deleteConversationGroup() async {
    try {
      final result = await TencentImSDKPlugin.v2TIMManager
          .getConversationManager()
          .deleteConversationGroup(
            groupName: _groupNameController.text,
          );
      _addLog('删除会话分组成功: ${result.toJson()}');
    } catch (e) {
      _addLog('删除会话分组失败: $e');
    }
  }

  // 重命名会话分组
  Future<void> _renameConversationGroup() async {
    try {
      final result = await TencentImSDKPlugin.v2TIMManager
          .getConversationManager()
          .renameConversationGroup(
            oldName: _oldNameController.text,
            newName: _newNameController.text,
          );
      _addLog('重命名会话分组成功: ${result.toJson()}');
    } catch (e) {
      _addLog('重命名会话分组失败: $e');
    }
  }

  // 添加会话到分组
  Future<void> _addConversationsToGroup() async {
    try {
      final result = await TencentImSDKPlugin.v2TIMManager
          .getConversationManager()
          .addConversationsToGroup(
            groupName: _groupNameController.text,
            conversationIDList: _conversationIDListController.text.split(','),
          );
      _addLog('添加会话到分组成功: ${result.toJson()}');
    } catch (e) {
      _addLog('添加会话到分组失败: $e');
    }
  }

  // 从分组中删除会话
  Future<void> _deleteConversationsFromGroup() async {
    try {
      final result = await TencentImSDKPlugin.v2TIMManager
          .getConversationManager()
          .deleteConversationsFromGroup(
            groupName: _groupNameController.text,
            conversationIDList: _conversationIDListController.text.split(','),
          );
      _addLog('从分组中删除会话成功: ${result.toJson()}');
    } catch (e) {
      _addLog('从分组中删除会话失败: $e');
    }
  }

  // 获取未读消息数
  Future<void> _getUnreadMessageCountByFilter() async {
    try {
      final filter = V2TimConversationFilter(
        conversationType: _selectedConversationType,
        conversationGroup: _groupNameController.text,
        markType: _getCompositeMarkType(),
        hasUnreadCount: _filterHasUnreadCountValue,
        hasGroupAtInfo: _hasGroupAtInfoValue,
      );
      final result = await TencentImSDKPlugin.v2TIMManager
          .getConversationManager()
          .getUnreadMessageCountByFilter(filter: filter);
      _addLog('获取未读消息数成功: ${result.toJson()}');
    } catch (e) {
      _addLog('获取未读消息数失败: $e');
    }
  }

  // 订阅未读消息数
  Future<void> _subscribeUnreadMessageCountByFilter() async {
    try {
      final filter = V2TimConversationFilter(
        conversationType: _selectedConversationType,
        conversationGroup: _groupNameController.text,
        markType: _getCompositeMarkType(),
        hasUnreadCount: _filterHasUnreadCountValue,
        hasGroupAtInfo: _hasGroupAtInfoValue,
      );
      final result = await TencentImSDKPlugin.v2TIMManager
          .getConversationManager()
          .subscribeUnreadMessageCountByFilter(filter: filter);
      _addLog('订阅未读消息数成功: ${result.toJson()}');
    } catch (e) {
      _addLog('订阅未读消息数失败: $e');
    }
  }

  // 取消订阅未读消息数
  Future<void> _unsubscribeUnreadMessageCountByFilter() async {
    try {
      final filter = V2TimConversationFilter(
        conversationType: _selectedConversationType,
        conversationGroup: _groupNameController.text,
        markType: _getCompositeMarkType(),
        hasUnreadCount: _filterHasUnreadCountValue,
        hasGroupAtInfo: _hasGroupAtInfoValue,
      );
      final result = await TencentImSDKPlugin.v2TIMManager
          .getConversationManager()
          .unsubscribeUnreadMessageCountByFilter(filter: filter);
      _addLog('取消订阅未读消息数成功: ${result.toJson()}');
    } catch (e) {
      _addLog('取消订阅未读消息数失败: $e');
    }
  }

  // 清空会话未读数
  Future<void> _cleanConversationUnreadMessageCount() async {
    try {
      final result = await TencentImSDKPlugin.v2TIMManager
          .getConversationManager()
          .cleanConversationUnreadMessageCount(
            conversationID: _conversationIDController.text,
            cleanTimestamp: int.tryParse(_cleanTimestampController.text) ?? 0,
            cleanSequence: int.tryParse(_cleanSequenceController.text) ?? 0,
          );
      _addLog('清空会话未读数成功: ${result.toJson()}');
    } catch (e) {
      _addLog('清空会话未读数失败: $e');
    }
  }

  // 获取过滤的会话列表
  Future<void> _getConversationListByFilter() async {
    try {
      final filter = V2TimConversationFilter(
        conversationType: _selectedConversationType,
        conversationGroup: _groupNameController.text,
        markType: _getCompositeMarkType(),
        hasUnreadCount: _filterHasUnreadCountValue,
        hasGroupAtInfo: _hasGroupAtInfoValue,
      );
      final result = await TencentImSDKPlugin.v2TIMManager
          .getConversationManager()
          .getConversationListByFilter(
            filter: filter,
            nextSeq: _nextSeqController.text.isEmpty ? 0 : int.parse(_nextSeqController.text),
            count: int.tryParse(_countController.text) ?? 20,
          );
      if (result.code == 0) {
        V2TimConversationResult conversationResult = result.data!;
        _addLog('获取会话列表成功: nextSeq:${conversationResult.nextSeq}, isFinished:${conversationResult.isFinished}');
        for (var conversation in conversationResult.conversationList!) {
          _addLog('会话: ${conversation?.toJson()}\n');
        }
      } else {
        _addLog('获取会话列表失败, code:${result.code}|desc:${result.desc}');
      }
    } catch (e) {
      _addLog('获取会话列表失败: $e');
    }
  }

  // 计算复合标记类型
  int? _getCompositeMarkType() {
    if (_selectedFilterMarkTypes.isEmpty) {
      return null;
    }
    
    // 如果选择了"无标记"，则返回null
    if (_selectedFilterMarkTypes.contains(0)) {
      return null;
    }
    
    // 计算复合标记类型（按位或）
    int result = 0;
    for (int markType in _selectedFilterMarkTypes) {
      result |= markType;
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final inputFields = [
      // 会话ID单独一行，因为可能较长
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('会话ID', style: TextStyle(fontSize: 12)),
          SizedBox(
            height: 30,
            child: TextField(
              controller: _conversationIDController,
              style: const TextStyle(fontSize: 13),
              decoration: const InputDecoration(
                hintText: '请输入会话ID',
                contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                border: OutlineInputBorder(),
              ),
            ),
          ),
        ],
      ),
      // 会话ID列表单独一行，因为可能较长
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('会话ID列表', style: TextStyle(fontSize: 12)),
          SizedBox(
            height: 30,
            child: TextField(
              controller: _conversationIDListController,
              style: const TextStyle(fontSize: 13),
              decoration: const InputDecoration(
                hintText: '请输入会话ID列表(用逗号分隔)',
                contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                border: OutlineInputBorder(),
              ),
            ),
          ),
        ],
      ),
      // 分页游标和获取数量放在一行
      Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('分页游标', style: TextStyle(fontSize: 12)),
                SizedBox(
                  height: 30,
                  child: TextField(
                    controller: _nextSeqController,
                    style: const TextStyle(fontSize: 13),
                    decoration: const InputDecoration(
                      hintText: '默认0',
                      contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('获取数量', style: TextStyle(fontSize: 12)),
                SizedBox(
                  height: 30,
                  child: TextField(
                    controller: _countController,
                    style: const TextStyle(fontSize: 13),
                    decoration: const InputDecoration(
                      hintText: '默认20',
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
      // 会话类型和标记类型+是否标记放在一行
      Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('会话类型', style: TextStyle(fontSize: 12)),
                SizedBox(
                  height: 30,
                  child: DropdownButtonFormField<int>(
                    value: _selectedConversationType,
                    decoration: const InputDecoration(
                      contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      border: OutlineInputBorder(),
                    ),
                    items: _conversationTypeMap.entries.map((entry) {
                      return DropdownMenuItem<int>(
                        value: entry.key,
                        child: Text(entry.value, style: const TextStyle(fontSize: 11)),
                      );
                    }).toList(),
                    onChanged: (int? value) {
                      setState(() {
                        _selectedConversationType = value ?? ConversationType.CONVERSATION_TYPE_INVALID;
                      });
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('标记类型', style: TextStyle(fontSize: 12)),
                SizedBox(
                  height: 30,
                  child: DropdownButtonFormField<int>(
                    value: _selectedMarkType,
                    decoration: const InputDecoration(
                      contentPadding: EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                      border: OutlineInputBorder(),
                    ),
                    items: _markTypeMap.entries.map((entry) {
                      return DropdownMenuItem<int>(
                        value: entry.key,
                        child: Text(entry.value, style: const TextStyle(fontSize: 10)),
                      );
                    }).toList(),
                    onChanged: (int? value) {
                      setState(() {
                        _selectedMarkType = value ?? 0;
                      });
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: CheckboxListTile(
              title: const Text('是否标记', style: TextStyle(fontSize: 12)),
              value: _enableMarkValue,
              contentPadding: const EdgeInsets.only(left: 0),
              onChanged: (bool? value) {
                setState(() {
                  _enableMarkValue = value ?? false;
                });
              },
            ),
          ),
        ],
      ),
      // 过滤标记类型放在一行
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('过滤标记类型（多选）', style: TextStyle(fontSize: 12)),
          Wrap(
            spacing: 8.0,
            children: _markTypeMap.entries.map((entry) {
              return FilterChip(
                label: Text(entry.value, style: const TextStyle(fontSize: 11)),
                selected: _selectedFilterMarkTypes.contains(entry.key),
                onSelected: (bool selected) {
                  setState(() {
                    if (selected) {
                      _selectedFilterMarkTypes.add(entry.key);
                    } else {
                      _selectedFilterMarkTypes.remove(entry.key);
                    }
                  });
                },
              );
            }).toList(),
          ),
        ],
      ),
      // 是否过滤包含未读的会话和是否包含@信息放在一行
      Row(
        children: [
          Expanded(
            child: CheckboxListTile(
              title: const Text('是否过滤包含未读数的会话', style: TextStyle(fontSize: 12)),
              value: _filterHasUnreadCountValue,
              contentPadding: const EdgeInsets.only(left: 0),
              onChanged: (bool? value) {
                setState(() {
                  _filterHasUnreadCountValue = value ?? false;
                });
              },
            ),
          ),
          Expanded(
            child: CheckboxListTile(
              title: const Text('是否包含@信息', style: TextStyle(fontSize: 12)),
              value: _hasGroupAtInfoValue,
              contentPadding: const EdgeInsets.only(left: 0),
              onChanged: (bool? value) {
                setState(() {
                  _hasGroupAtInfoValue = value ?? false;
                });
              },
            ),
          ),
        ],
      ),
      // 草稿内容和自定义数据放在一行
      Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('草稿内容', style: TextStyle(fontSize: 12)),
                SizedBox(
                  height: 30,
                  child: TextField(
                    controller: _draftTextController,
                    style: const TextStyle(fontSize: 13),
                    decoration: const InputDecoration(
                      hintText: '请输入草稿内容',
                      contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('自定义数据', style: TextStyle(fontSize: 12)),
                SizedBox(
                  height: 30,
                  child: TextField(
                    controller: _customDataController,
                    style: const TextStyle(fontSize: 13),
                    decoration: const InputDecoration(
                      hintText: '请输入自定义数据',
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
      // 是否置顶和是否清空消息放在一行
      Row(
        children: [
          Expanded(
            child: CheckboxListTile(
              title: const Text('是否置顶', style: TextStyle(fontSize: 12)),
              value: _isPinnedValue,
              contentPadding: const EdgeInsets.only(left: 0),
              onChanged: (bool? value) {
                setState(() {
                  _isPinnedValue = value ?? false;
                });
              },
            ),
          ),
          Expanded(
            child: CheckboxListTile(
              title: const Text('是否清空消息', style: TextStyle(fontSize: 12)),
              value: _clearMessageValue,
              contentPadding: const EdgeInsets.only(left: 6),
              onChanged: (bool? value) {
                setState(() {
                  _clearMessageValue = value ?? false;
                });
              },
            ),
          ),
        ],
      ),
      // 分组名称和原分组名放在一行
      Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('分组名称', style: TextStyle(fontSize: 12)),
                SizedBox(
                  height: 30,
                  child: TextField(
                    controller: _groupNameController,
                    style: const TextStyle(fontSize: 13),
                    decoration: const InputDecoration(
                      hintText: '请输入分组名称',
                      contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('原分组名', style: TextStyle(fontSize: 12)),
                SizedBox(
                  height: 30,
                  child: TextField(
                    controller: _oldNameController,
                    style: const TextStyle(fontSize: 13),
                    decoration: const InputDecoration(
                      hintText: '请输入原分组名',
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
      // 新分组名和会话类型放在一行
      Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('新分组名', style: TextStyle(fontSize: 12)),
                SizedBox(
                  height: 30,
                  child: TextField(
                    controller: _newNameController,
                    style: const TextStyle(fontSize: 13),
                    decoration: const InputDecoration(
                      hintText: '请输入新分组名',
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
      // 清空会话未读数的参数
      Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('清理时间戳', style: TextStyle(fontSize: 12)),
                SizedBox(
                  height: 30,
                  child: TextField(
                    controller: _cleanTimestampController,
                    style: const TextStyle(fontSize: 11),
                    decoration: const InputDecoration(
                      hintText: '请输入清理时间戳',
                      contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('清理序列号', style: TextStyle(fontSize: 12)),
                SizedBox(
                  height: 30,
                  child: TextField(
                    controller: _cleanSequenceController,
                    style: const TextStyle(fontSize: 11),
                    decoration: const InputDecoration(
                      hintText: '请输入清理序列号',
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
    ];

    final buttons = [
      APITestButton(text: '获取会话列表', onPressed: _getConversationList),
      APITestButton(text: '获取过滤的会话列表', onPressed: _getConversationListByFilter),
      APITestButton(text: '获取会话列表(不格式化)', onPressed: _getConversationListWithoutFormat),
      APITestButton(text: '获取会话信息', onPressed: _getConversationInfo),
      APITestButton(text: '设置会话草稿', onPressed: _setConversationDraft),
      APITestButton(text: '删除会话', onPressed: _deleteConversation),
      APITestButton(text: '删除会话列表', onPressed: _deleteConversationList),
      APITestButton(text: '标记会话', onPressed: _markConversation),
      APITestButton(text: '获取指定的会话列表', onPressed: _getConversationListByID),
      APITestButton(text: '设置自定义数据', onPressed: _setConversationCustomData),
      APITestButton(text: '会话置顶', onPressed: _pinConversation),
      APITestButton(text: '获取会话未读总数', onPressed: _getTotalUnreadMessageCount),
      APITestButton(text: '创建会话分组', onPressed: _createConversationGroup),
      APITestButton(text: '获取会话分组列表', onPressed: _getConversationGroupList),
      APITestButton(text: '删除会话分组', onPressed: _deleteConversationGroup),
      APITestButton(text: '重命名会话分组', onPressed: _renameConversationGroup),
      APITestButton(text: '添加会话到分组', onPressed: _addConversationsToGroup),
      APITestButton(text: '从分组中删除会话', onPressed: _deleteConversationsFromGroup),
      APITestButton(text: '获取未读消息数', onPressed: _getUnreadMessageCountByFilter),
      APITestButton(text: '订阅未读消息数', onPressed: _subscribeUnreadMessageCountByFilter),
      APITestButton(text: '取消订阅未读消息数', onPressed: _unsubscribeUnreadMessageCountByFilter),
      APITestButton(text: '清空会话未读数', onPressed: _cleanConversationUnreadMessageCount),
    ];

    return BaseAPITest(
      title: '会话管理',
      inputFields: inputFields,
      buttons: buttons,
      onClearLog: _clearLog,
    );
  }

  @override
  void dispose() {
    _conversationIDController.dispose();
    _nextSeqController.dispose();
    _countController.dispose();
    _draftTextController.dispose();
    _markTypeController.dispose();
    _enableMarkController.dispose();
    _conversationIDListController.dispose();
    _customDataController.dispose();
    _groupNameController.dispose();
    _oldNameController.dispose();
    _newNameController.dispose();
    _isPinnedController.dispose();
    _clearMessageController.dispose();
    _filterTypeController.dispose();
    _filterConversationTypeController.dispose();
    _filterEnableMarkController.dispose();
    _cleanTimestampController.dispose();
    _cleanSequenceController.dispose();
    super.dispose();
  }
}