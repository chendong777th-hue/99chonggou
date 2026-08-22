import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:tencent_cloud_chat_sdk/enum/log_level_enum.dart';
import 'package:tencent_cloud_chat_sdk/enum/login_status.dart';
import 'package:tencent_cloud_chat_sdk/enum/message_priority_enum.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_user_info.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_user_info.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_user_search_result.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_user_search_result.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_value_callback.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_value_callback.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_user_full_info.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_user_full_info.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_user_search_param.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_user_search_param.dart';
import 'package:tencent_cloud_chat_sdk/tencent_im_sdk_plugin.dart';
import 'package:tencent_cloud_chat_sdk_example/config.dart';
import 'package:tencent_cloud_chat_sdk_example/utils/GenerateUserSig.dart';
import 'package:tencent_cloud_chat_sdk_example/utils/listener_manager.dart';
import 'package:tencent_cloud_chat_sdk_example/utils/log_manager.dart';
import 'base_api_test.dart';

class MainAPITest extends StatefulWidget {
  const MainAPITest({Key? key}) : super(key: key);

  @override
  State<MainAPITest> createState() => _MainAPITestState();
}

class _MainAPITestState extends State<MainAPITest> {
  // 按钮样式相关常量
  static const double BUTTON_HORIZONTAL_PADDING = 5.0; // 按钮内部左右内边距
  static const double BUTTON_VERTICAL_PADDING = 3.0; // 按钮内部上下内边距
  static const double BUTTON_MIN_HEIGHT = 30.0; // 按钮最小高度
  static const double BUTTON_FONT_SIZE = 12.0; // 按钮文字大小
  static const double BUTTON_BORDER_RADIUS = 4.0; // 按钮圆角半径
  static const double BUTTON_CHAR_WIDTH = 6.0; // 每个字符的估计宽度
  static const double BUTTON_EXTRA_WIDTH = 12.0; // 按钮额外宽度
  static const Color BUTTON_TEXT_COLOR = Colors.white; // 按钮文字颜色
  static const Color BUTTON_BG_COLOR = Colors.blue; // 按钮背景颜色

  // 按钮布局相关常量
  static const double BUTTON_HORIZONTAL_SPACING = 2.0; // 按钮之间的水平间距
  static const double BUTTON_VERTICAL_SPACING = 4.0; // 按钮之间的垂直间距
  static const double BUTTONS_TOP_MARGIN = 2.0; // 按钮区域顶部间距
  static const double BUTTON_BOTTOM_MARGIN = 1.0; // 单个按钮底部外边距

  final TextEditingController _loginUserController = TextEditingController();
  final TextEditingController _receiverIDController = TextEditingController();
  final TextEditingController _groupIDController = TextEditingController();
  final TextEditingController _conversationIDController = TextEditingController();
  final TextEditingController _messageController = TextEditingController();
  final TextEditingController _customDataController = TextEditingController(); // 自定义消息数据
  final TextEditingController _userIDListController = TextEditingController(); // 用户ID列表
  final TextEditingController _groupTypeController = TextEditingController(); // 群组类型
  final TextEditingController _groupNameController = TextEditingController(); // 群组名称

  // 使用全局日志管理器和监听器管理器
  final LogManager _logManager = LogManager();
  final ListenerManager _listenerManager = ListenerManager();

  @override
  void initState() {
    super.initState();
    _loginUserController.text = 'teacher10';
    _receiverIDController.text = 'teacher13';
    _groupIDController.text = 'public15';
    _conversationIDController.text = 'c2c_@TOA#_@TOA#dHD4';
    _messageController.text = '这是一条测试消息';
    _customDataController.text = '这是一条自定义消息';
    _userIDListController.text = 'teacher10,teacher13,teacher20';

    // 初始化全局监听器
    _listenerManager.initialize();
  }

  // 清空日志
  void _clearLog() {
    _logManager.clearAllLogs();
  }

  // SDK初始化
  Future<void> _initSDK() async {
    // 使用config.dart中定义的sdkAppID
    if (IMConfig.sdkappid == 0) {
      _logManager.updateLogText('Please input sdkappid and appKey in config.dart');
      return;
    }

    var initSDKRes = await TencentImSDKPlugin.v2TIMManager.initSDK(
      sdkAppID: IMConfig.sdkappid,
      loglevel: LogLevelEnum.V2TIM_LOG_DEBUG,
      listener: _listenerManager.sdkListener,
    );

    if (initSDKRes.code == 0) {
      _logManager.updateLogText('初始化SDK成功');
    } else {
      _logManager.updateLogText('初始化SDK失败: ${initSDKRes.code} ${initSDKRes.desc ?? ''}');
    }
  }

  // SDK卸载
  Future<void> _unInitSDK() async {
    var unInitRes = await TencentImSDKPlugin.v2TIMManager.unInitSDK();

    if (unInitRes.code == 0) {
      _logManager.updateLogText('卸载SDK成功');
    } else {
      _logManager.updateLogText('卸载SDK失败: ${unInitRes.code} ${unInitRes.desc ?? ''}');
    }
  }

  // 登录
  Future<void> _login() async {
    String userID = _loginUserController.text;

    // 使用 GenerateUserSig 类生成 UserSig
    String userSig = GenerateDevUsersigForTest(sdkappid: IMConfig.sdkappid, key: IMConfig.appKey)
        .genSig(userID: userID, expireTime: IMConfig.expireTime);

    var loginRes = await TencentImSDKPlugin.v2TIMManager.login(
      userID: userID,
      userSig: userSig,
    );

    if (loginRes.code == 0) {
      var loginStatusResult = await TencentImSDKPlugin.v2TIMManager.getLoginStatus();
      var statusStr = 'unknown';
      switch (loginStatusResult.data) {
        case 1:
          statusStr = '已登录';
          break;
        case 2:
          statusStr = '登录中';
          break;
        case 3:
          statusStr = '未登录';
          break;
        default:
          break;
      }
      _logManager.updateLogText('登录成功, 登录状态: $statusStr');
    } else {
      _logManager.updateLogText('登录失败: ${loginRes.code} ${loginRes.desc}');
    }
  }

  // 登出
  Future<void> _logout() async {
    var logoutRes = await TencentImSDKPlugin.v2TIMManager.logout();

    if (logoutRes.code == 0) {
      var loginStatusResult = await TencentImSDKPlugin.v2TIMManager.getLoginStatus();
      var statusStr = 'unknown';
      switch (loginStatusResult.data) {
        case 1:
          statusStr = '已登录';
          break;
        case 2:
          statusStr = '登录中';
          break;
        case 3:
          statusStr = '未登录';
          break;
        default:
          break;
      }
      _logManager.updateLogText('登出成功, 登录状态: $statusStr');
    } else {
      _logManager.updateLogText('登出失败: ${logoutRes.code} ${logoutRes.desc}');
    }
  }

  // 获取登录状态
  Future<void> _getLoginStatus() async {
    var statusRes = await TencentImSDKPlugin.v2TIMManager.getLoginStatus();

    if (statusRes.code == 0) {
      var statusStr = 'unknown';
      switch (statusRes.data) {
        case LoginStatus.V2TIM_STATUS_LOGINED:
          statusStr = '已登录';
          break;
        case LoginStatus.V2TIM_STATUS_LOGINING:
          statusStr = '登录中';
          break;
        case LoginStatus.V2TIM_STATUS_LOGOUT:
          statusStr = '未登录';
          break;
        default:
          break;
      }
      _logManager.updateLogText('登录状态: $statusStr');
    } else {
      _logManager.updateLogText('获取登录状态失败: ${statusRes.code} ${statusRes.desc}');
    }
  }

  // 获取登录用户
  Future<void> _getLoginUser() async {
    var userRes = await TencentImSDKPlugin.v2TIMManager.getLoginUser();

    if (userRes.code == 0) {
      _logManager.updateLogText('获取登录用户成功: ${userRes.data}');
    } else {
      _logManager.updateLogText('获取登录用户失败: ${userRes.code} ${userRes.desc}');
    }
  }

  // 发送C2C文本消息
  Future<void> _sendC2CTextMessage() async {
    String receiverID = _receiverIDController.text;
    String text = _messageController.text;

    var sendRes = await TencentImSDKPlugin.v2TIMManager.sendC2CTextMessage(
      text: text,
      userID: receiverID,
    );

    if (sendRes.code == 0) {
      _logManager.updateLogText('发送C2C文本消息成功: ${sendRes.data?.msgID}');
    } else {
      _logManager.updateLogText('发送C2C文本消息失败: ${sendRes.code} ${sendRes.desc}');
    }
  }

  // 发送Group文本消息
  Future<void> _sendGroupTextMessage() async {
    String groupID = _groupIDController.text;
    String text = _messageController.text;

    var sendRes = await TencentImSDKPlugin.v2TIMManager.sendGroupTextMessage(
      text: text,
      groupID: groupID,
      priority: 0, // V2TIM_PRIORITY_NORMAL
    );

    if (sendRes.code == 0) {
      _logManager.updateLogText('发送群组文本消息成功: ${sendRes.data?.msgID}');
    } else {
      _logManager.updateLogText('发送群组文本消息失败: ${sendRes.code} ${sendRes.desc}');
    }
  }

  // 加入群组
  Future<void> _joinGroup() async {
    String groupID = _groupIDController.text;

    var joinRes = await TencentImSDKPlugin.v2TIMManager.joinGroup(
      groupID: groupID,
      message: '申请加入群组',
    );

    if (joinRes.code == 0) {
      _logManager.updateLogText('加入群组成功');
    } else {
      _logManager.updateLogText('加入群组失败: ${joinRes.code} ${joinRes.desc}');
    }
  }

  // 退出群组
  Future<void> _quitGroup() async {
    String groupID = _groupIDController.text;

    var quitRes = await TencentImSDKPlugin.v2TIMManager.quitGroup(
      groupID: groupID,
    );

    if (quitRes.code == 0) {
      _logManager.updateLogText('退出群组成功');
    } else {
      _logManager.updateLogText('退出群组失败: ${quitRes.code} ${quitRes.desc}');
    }
  }

  // 解散群组
  Future<void> _dismissGroup() async {
    String groupID = _groupIDController.text;

    var dismissRes = await TencentImSDKPlugin.v2TIMManager.dismissGroup(
      groupID: groupID,
    );

    if (dismissRes.code == 0) {
      _logManager.updateLogText('解散群组成功');
    } else {
      _logManager.updateLogText('解散群组失败: ${dismissRes.code} ${dismissRes.desc}');
    }
  }

  // 获取用户资料
  Future<void> _getUsersInfo() async {
    if (_userIDListController.text.isEmpty) {
      _logManager.updateLogText('请输入用户ID列表');
      return;
    }

    List<String> userIDList = _userIDListController.text.split(',');

    var userInfoRes = await TencentImSDKPlugin.v2TIMManager.getUsersInfo(
      userIDList: userIDList,
    );

    if (userInfoRes.code == 0) {
      _logManager.updateLogText('获取用户资料成功: ${userInfoRes.data?.map((e) => e.toLogString()).toList()}');
    } else {
      _logManager.updateLogText('获取用户资料失败: ${userInfoRes.code} ${userInfoRes.desc}');
    }
  }

  // 获取用户状态
  Future<void> _getUserStatus() async {
    if (_userIDListController.text.isEmpty) {
      _logManager.updateLogText('请输入用户ID列表');
      return;
    }

    List<String> userIDList = _userIDListController.text.split(',');

    var statusRes = await TencentImSDKPlugin.v2TIMManager.getUserStatus(
      userIDList: userIDList,
    );

    if (statusRes.code == 0) {
      _logManager.updateLogText('获取用户状态成功: ${statusRes.data?.map((e) => e.toJson()).toList()}');
    } else {
      _logManager.updateLogText('获取用户状态失败: ${statusRes.code} ${statusRes.desc}');
    }
  }

  // 获取服务器时间
  Future<void> _getServerTime() async {
    var timeRes = await TencentImSDKPlugin.v2TIMManager.getServerTime();

    DateTime dateTime = DateTime.fromMillisecondsSinceEpoch((timeRes.data ?? 0) * 1000);
    if (timeRes.code == 0) {
      _logManager.updateLogText('获取服务器时间: ${timeRes.data}, 格式化时间: ${dateTime.toLocal()}');
    } else {
      _logManager.updateLogText('获取服务器时间失败: ${timeRes.code} ${timeRes.desc}');
    }
  }

  // 获取SDK版本号
  Future<void> _getVersion() async {
    var versionRes = await TencentImSDKPlugin.v2TIMManager.getVersion();

    if (versionRes.code == 0) {
      _logManager.updateLogText('获取SDK版本号成功: ${versionRes.data}');
    } else {
      _logManager.updateLogText('获取SDK版本号失败: ${versionRes.code} ${versionRes.desc}');
    }
  }

  // 创建群组
  Future<void> _createGroup() async {
    if (_groupTypeController.text.isEmpty || _groupNameController.text.isEmpty) {
      _logManager.updateLogText('请输入群组类型和群组名称');
      return;
    }

    var createRes = await TencentImSDKPlugin.v2TIMManager.createGroup(
      groupType: _groupTypeController.text,
      groupName: _groupNameController.text,
      groupID: _groupIDController.text.isEmpty ? null : _groupIDController.text,
    );

    if (createRes.code == 0) {
      _logManager.updateLogText('创建群组成功: ${createRes.data}');
    } else {
      _logManager.updateLogText('创建群组失败: ${createRes.code} ${createRes.desc}');
    }
  }

  // 发送群组自定义消息
  Future<void> _sendGroupCustomMessage() async {
    String groupID = _groupIDController.text;
    String customData = _customDataController.text;

    if (groupID.isEmpty) {
      _logManager.updateLogText('请输入群组ID');
      return;
    }

    if (customData.isEmpty) {
      _logManager.updateLogText('请输入自定义消息内容');
      return;
    }

    var sendRes = await TencentImSDKPlugin.v2TIMManager.sendGroupCustomMessage(
      customData: customData,
      groupID: groupID,
      priority: MessagePriorityEnum.V2TIM_PRIORITY_NORMAL,
    );

    if (sendRes.code == 0) {
      _logManager.updateLogText('发送群组自定义消息成功: ${sendRes.data?.msgID}');
    } else {
      _logManager.updateLogText('发送群组自定义消息失败: ${sendRes.code} ${sendRes.desc}');
    }
  }

  // 发送C2C自定义消息
  Future<void> _sendC2CCustomMessage() async {
    String receiverID = _receiverIDController.text;
    String customData = _customDataController.text;

    if (receiverID.isEmpty) {
      _logManager.updateLogText('请输入接收者ID');
      return;
    }

    if (customData.isEmpty) {
      _logManager.updateLogText('请输入自定义消息内容');
      return;
    }

    var sendRes = await TencentImSDKPlugin.v2TIMManager.sendC2CCustomMessage(
      customData: customData,
      userID: receiverID,
    );

    if (sendRes.code == 0) {
      _logManager.updateLogText('发送C2C自定义消息成功: ${sendRes.data?.msgID}');
    } else {
      _logManager.updateLogText('发送C2C自定义消息失败: ${sendRes.code} ${sendRes.desc}');
    }
  }

  // 设置个人信息
  Future<void> _setSelfInfo() async {
    // 创建用户资料
    Map<String, String> userCustomMap = {"Str": "Str value"};
    V2TimUserFullInfo userInfo = V2TimUserFullInfo(
      userID: TencentImSDKPlugin.v2TIMManager.getLoginUser().toString(),
      nickName: _loginUserController.text,
      faceUrl: 'https://example.com/avatar.jpg',
      // 示例头像URL
      selfSignature: '这是我的个性签名',
      customInfo: userCustomMap,
    );

    var setInfoRes = await TencentImSDKPlugin.v2TIMManager.setSelfInfo(
      userFullInfo: userInfo,
    );

    if (setInfoRes.code == 0) {
      _logManager.updateLogText('设置个人信息成功');
    } else {
      _logManager.updateLogText('设置个人信息失败: ${setInfoRes.code} ${setInfoRes.desc}');
    }
  }

  // 设置个人状态
  Future<void> _setSelfStatus() async {
    var setStatusRes = await TencentImSDKPlugin.v2TIMManager.setSelfStatus(
      status: '我是在线状态', // 自定义状态
    );

    if (setStatusRes.code == 0) {
      _logManager.updateLogText('设置个人状态成功');
    } else {
      _logManager.updateLogText('设置个人状态失败: ${setStatusRes.code} ${setStatusRes.desc}');
    }
  }

  // 订阅用户状态
  Future<void> _subscribeUserStatus() async {
    if (_userIDListController.text.isEmpty) {
      _logManager.updateLogText('请输入用户ID列表');
      return;
    }

    List<String> userIDList = _userIDListController.text.split(',');

    var subscribeRes = await TencentImSDKPlugin.v2TIMManager.subscribeUserStatus(
      userIDList: userIDList,
    );

    if (subscribeRes.code == 0) {
      _logManager.updateLogText('订阅用户状态成功');
    } else {
      _logManager.updateLogText('订阅用户状态失败: ${subscribeRes.code} ${subscribeRes.desc}');
    }
  }

  // 取消订阅用户状态
  Future<void> _unsubscribeUserStatus() async {
    if (_userIDListController.text.isEmpty) {
      _logManager.updateLogText('请输入用户ID列表');
      return;
    }

    List<String> userIDList = _userIDListController.text.split(',');

    var unsubscribeRes = await TencentImSDKPlugin.v2TIMManager.unsubscribeUserStatus(
      userIDList: userIDList,
    );

    if (unsubscribeRes.code == 0) {
      _logManager.updateLogText('取消订阅用户状态成功');
    } else {
      _logManager.updateLogText('取消订阅用户状态失败: ${unsubscribeRes.code} ${unsubscribeRes.desc}');
    }
  }

  // 订阅用户资料
  Future<void> _subscribeUserInfo() async {
    if (_userIDListController.text.isEmpty) {
      _logManager.updateLogText('请输入用户ID列表');
      return;
    }

    List<String> userIDList = _userIDListController.text.split(',');

    var subscribeRes = await TencentImSDKPlugin.v2TIMManager.subscribeUserInfo(
      userIDList: userIDList,
    );

    if (subscribeRes.code == 0) {
      _logManager.updateLogText('订阅用户资料成功');
    } else {
      _logManager.updateLogText('订阅用户资料失败: ${subscribeRes.code} ${subscribeRes.desc}');
    }
  }

  // 取消订阅用户资料
  Future<void> _unsubscribeUserInfo() async {
    if (_userIDListController.text.isEmpty) {
      _logManager.updateLogText('请输入用户ID列表');
      return;
    }

    List<String> userIDList = _userIDListController.text.split(',');

    var unsubscribeRes = await TencentImSDKPlugin.v2TIMManager.unsubscribeUserInfo(
      userIDList: userIDList,
    );

    if (unsubscribeRes.code == 0) {
      _logManager.updateLogText('取消订阅用户资料成功');
    } else {
      _logManager.updateLogText('取消订阅用户资料失败: ${unsubscribeRes.code} ${unsubscribeRes.desc}');
    }
  }

  Future<void> _searchUsers() async {
    V2TimUserSearchParam searchParam = V2TimUserSearchParam(keywordList: ['tea'], searchCount: 10, searchCursor: '');
    V2TimValueCallback<V2TimUserSearchResult> result = await TencentImSDKPlugin.v2TIMManager.searchUsers(
        searchParam: searchParam);

    if (result.code == 0) {
      String searchUserLog = 'isFinished: ${result.data?.isFinished}, totalCount: ${result.data
          ?.totalCount}, searchCursor: ${result.data?.nextCursor}\n';
      for (V2TimUserInfo userInfo in result.data?.userInfoList ?? []) {
        searchUserLog += '${userInfo.toLogString()}\n\n';
      }

      _logManager.updateLogText('_searchUsers: $searchUserLog');
    } else {
      _logManager.updateLogText('_searchUsers failed: ${result.code} ${result.desc}');
    }
  }

  // 邀请某个人
  Future<void> _invite() async {
    if (_userIDListController.text.isEmpty) {
      _logManager.updateLogText('请输入用户ID列表');
      return;
    }

    List<String> userIDList = _userIDListController.text.split(',');

    var result = await TencentImSDKPlugin.v2TIMManager.getSignalingManager().invite(
      invitee: userIDList[0],
      // data: "test",
      data: jsonEncode(getCustomMap()),
    );

    if (result.code == 0) {
      _logManager.updateLogText('邀请用户成功: inviteID: ${result.data}');
    } else {
      _logManager.updateLogText('邀请用户失败: ${result.code} ${result.desc}');
    }
  }

  // 邀请群内的某些人
  Future<void> _inviteInGroup() async {
    if (_groupIDController.text.isEmpty) {
      _logManager.updateLogText('请输入群组ID');
      return;
    }
    if (_userIDListController.text.isEmpty) {
      _logManager.updateLogText('请输入用户ID列表');
      return;
    }

    String groupID = _groupIDController.text;

    List<String> userIDList = _userIDListController.text.split(',');

    var result = await TencentImSDKPlugin.v2TIMManager.getSignalingManager().inviteInGroup(
      groupID: groupID,
      inviteeList: userIDList,
      data: "test",
    );

    if (result.code == 0) {
      _logManager.updateLogText('邀请群内用户成功: inviteID: ${result.data}');
    } else {
      _logManager.updateLogText('邀请群内用户失败: ${result.code} ${result.desc}');
    }
  }

  Future<void> _setOfflinePushConfig({bool isVoip = false}) async {
    var result = await TencentImSDKPlugin.v2TIMManager.getOfflinePushManager().setOfflinePushConfig(
      businessID: 1,
      token: "test",
      isVoip: isVoip,
    );
    if (result.code == 0) {
      _logManager.updateLogText('setOfflinePushConfig success');
    } else {
      _logManager.updateLogText('setOfflinePushConfig failed: ${result.code} ${result.desc}');
    }
  }

  Future<void> _doBackground() async {
    var result = await TencentImSDKPlugin.v2TIMManager.getOfflinePushManager().doBackground(unreadCount: 0);
    if (result.code == 0) {
      _logManager.updateLogText('doBackground success');
    } else {
      _logManager.updateLogText('doBackground failed: ${result.code} ${result.desc}');
    }
  }

  Future<void> _doForeground() async {
    var result = await TencentImSDKPlugin.v2TIMManager.getOfflinePushManager().doForeground();
    if (result.code == 0) {
      _logManager.updateLogText('doForeground success');
    } else {
      _logManager.updateLogText('doForeground failed: ${result.code} ${result.desc}');
    }
  }

  Map<String, dynamic> getCustomMap() {
    Map<String, dynamic> customMap = <String, dynamic>{};
    customMap['customData1'] = 1;
    customMap['customData2'] = "ccc2";
    customMap['customData3'] = 3;
    customMap['customData4'] = 4;

    return customMap;
  }

  Future<void> _setTestEnv() async {
    Map<String, dynamic> param = {"request_set_env_param": true};
    TencentImSDKPlugin.v2TIMManager.callExperimentalAPI(api: "internal_operation_set_env", param: param);
  }

  /// 复现 logout → reLogin 卡死场景（并发版，模拟 client_uikit Demo 真实时序）
  Future<void> _reproduceLogoutReloginHang() async {
    String userID = _loginUserController.text;
    String userSig = GenerateDevUsersigForTest(sdkappid: IMConfig.sdkappid, key: IMConfig.appKey)
        .genSig(userID: userID, expireTime: IMConfig.expireTime);

    _logManager.updateLogText('===== 并发复现: logout→reLogin =====');

    _logManager.updateLogText('[Step1] initSDK + login ...');
    await TencentImSDKPlugin.v2TIMManager.initSDK(
      sdkAppID: IMConfig.sdkappid, loglevel: LogLevelEnum.V2TIM_LOG_INFO, listener: _listenerManager.sdkListener);
    var loginRes = await TencentImSDKPlugin.v2TIMManager.login(userID: userID, userSig: userSig);
    _logManager.updateLogText('[Step1] login result: ${loginRes.code} ${loginRes.desc}');
    if (loginRes.code != 0) { _logManager.updateLogText('首次登录失败，终止'); return; }

    _logManager.updateLogText('[Step2] logout (LoginStore 路径) ...');
    var logoutRes = await TencentImSDKPlugin.v2TIMManager.logout();
    _logManager.updateLogText('[Step2] logout result: ${logoutRes.code}');

    _logManager.updateLogText('[Step3] TUILogin.logout: logout + unInitSDK (no await) ...');
    _tuiLoginLogout();

    _logManager.updateLogText('[Step4] re-initSDK + login ...');
    var reInitRes = await TencentImSDKPlugin.v2TIMManager.initSDK(
      sdkAppID: IMConfig.sdkappid, loglevel: LogLevelEnum.V2TIM_LOG_INFO, listener: _listenerManager.sdkListener);
    _logManager.updateLogText('[Step4] re-initSDK result: ${reInitRes.code}');
    var reLoginRes = await TencentImSDKPlugin.v2TIMManager.login(userID: userID, userSig: userSig);
    _logManager.updateLogText('[Step4] re-login result: ${reLoginRes.code} ${reLoginRes.desc}');
    _logManager.updateLogText('===== 并发复现结束 =====');
  }

  void _tuiLoginLogout() async {
    var res = await TencentImSDKPlugin.v2TIMManager.logout();
    if (res.code == 0) {
      await TencentImSDKPlugin.v2TIMManager.unInitSDK();
    }
  }

  /// 复现 logout → reLogin 卡死场景（串行版，排除并发因素）
  Future<void> _reproduceLogoutReloginSerial() async {
    String userID = _loginUserController.text;
    String userSig = GenerateDevUsersigForTest(sdkappid: IMConfig.sdkappid, key: IMConfig.appKey)
        .genSig(userID: userID, expireTime: IMConfig.expireTime);

    _logManager.updateLogText('===== 串行复现: logout→unInit→initSDK→login =====');

    _logManager.updateLogText('[Step1] initSDK + login ...');
    await TencentImSDKPlugin.v2TIMManager.initSDK(
      sdkAppID: IMConfig.sdkappid, loglevel: LogLevelEnum.V2TIM_LOG_INFO, listener: _listenerManager.sdkListener);
    var loginRes = await TencentImSDKPlugin.v2TIMManager.login(userID: userID, userSig: userSig);
    _logManager.updateLogText('[Step1] login result: ${loginRes.code}');
    if (loginRes.code != 0) { _logManager.updateLogText('首次登录失败，终止'); return; }

    _logManager.updateLogText('[Step2] logout ...');
    await TencentImSDKPlugin.v2TIMManager.logout();

    _logManager.updateLogText('[Step3] unInitSDK ...');
    await TencentImSDKPlugin.v2TIMManager.unInitSDK();
    _logManager.updateLogText('[Step3] unInitSDK done');

    _logManager.updateLogText('[Step4] re-initSDK + login ...');
    var reInitRes = await TencentImSDKPlugin.v2TIMManager.initSDK(
      sdkAppID: IMConfig.sdkappid, loglevel: LogLevelEnum.V2TIM_LOG_INFO, listener: _listenerManager.sdkListener);
    _logManager.updateLogText('[Step4] re-initSDK result: ${reInitRes.code}');
    var reLoginRes = await TencentImSDKPlugin.v2TIMManager.login(userID: userID, userSig: userSig);
    _logManager.updateLogText('[Step4] re-login result: ${reLoginRes.code}');
    _logManager.updateLogText('===== 串行复现结束 =====');
  }

  // 使用全局监听器管理器注册所有监听器
  void _registerAllListeners() {
    _listenerManager.registerAllListeners();
  }

  @override
  Widget build(BuildContext context) {
    final inputFields = [
      // 用户输入区域 - 使用更紧凑的布局
      Row(
        children: [
          // 登录用户ID
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('登录用户ID:', style: TextStyle(fontSize: 12)),
                SizedBox(
                  height: 30,
                  child: TextField(
                    controller: _loginUserController,
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
          // 接收者ID
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('接收者ID:', style: TextStyle(fontSize: 12)),
                SizedBox(
                  height: 30,
                  child: TextField(
                    controller: _receiverIDController,
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

      // 群组ID和会话ID
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
                    style: const TextStyle(fontSize: 10, letterSpacing: -0.3),
                    maxLines: 1,
                    decoration: const InputDecoration(
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      border: OutlineInputBorder(),
                      hintStyle: TextStyle(fontSize: 10, height: 1.0),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // 消息内容
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('消息内容:', style: TextStyle(fontSize: 12)),
                SizedBox(
                  height: 30,
                  child: TextField(
                    controller: _messageController,
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

      // 自定义消息和用户ID列表
      Row(
        children: [
          // 自定义消息数据
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('自定义消息:', style: TextStyle(fontSize: 12)),
                SizedBox(
                  height: 30,
                  child: TextField(
                    controller: _customDataController,
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
                    style: const TextStyle(fontSize: 10),
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

      // 群组类型和群组名称
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
    ];

    final buttons = [
      _buildDynamicButton('initSDK', _initSDK),
      _buildDynamicButton('unInitSDK', _unInitSDK),
      _buildDynamicButton('registerAllListeners', _registerAllListeners),
      _buildDynamicButton('login', _login),
      _buildDynamicButton('logout', _logout),
      _buildDynamicButton('getLoginStatus', _getLoginStatus),
      _buildDynamicButton('getLoginUser', _getLoginUser),
      _buildDynamicButton('getServerTime', _getServerTime),
      _buildDynamicButton('getVersion', _getVersion),
      _buildDynamicButton('sendC2CTextMessage', _sendC2CTextMessage),
      _buildDynamicButton('sendC2CCustomMessage', _sendC2CCustomMessage),
      _buildDynamicButton('sendGroupTextMessage', _sendGroupTextMessage),
      _buildDynamicButton('sendGroupCustomMessage', _sendGroupCustomMessage),
      _buildDynamicButton('createGroup', _createGroup),
      _buildDynamicButton('joinGroup', _joinGroup),
      _buildDynamicButton('quitGroup', _quitGroup),
      _buildDynamicButton('dismissGroup', _dismissGroup),
      _buildDynamicButton('getUsersInfo', _getUsersInfo),
      _buildDynamicButton('setSelfInfo', _setSelfInfo),
      _buildDynamicButton('getUserStatus', _getUserStatus),
      _buildDynamicButton('setSelfStatus', _setSelfStatus),
      _buildDynamicButton('subscribeUserStatus', _subscribeUserStatus),
      _buildDynamicButton('unsubscribeUserStatus', _unsubscribeUserStatus),
      _buildDynamicButton('subscribeUserInfo', _subscribeUserInfo),
      _buildDynamicButton('unsubscribeUserInfo', _unsubscribeUserInfo),
      _buildDynamicButton('searchUsers', _searchUsers),
      _buildDynamicButton('invite', _invite),
      _buildDynamicButton('inviteInGroup', _inviteInGroup),
      _buildDynamicButton('setOfflinePushConfig', _setOfflinePushConfig),
      _buildDynamicButton('setOfflinePushConfig(VOIP)', (){_setOfflinePushConfig(isVoip: true);}),
      _buildDynamicButton('doBackground', _doBackground),
      _buildDynamicButton('doForeground', _doForeground),
      _buildDynamicButton('复现:并发logout→reLogin', _reproduceLogoutReloginHang),
      _buildDynamicButton('复现:串行logout→reLogin', _reproduceLogoutReloginSerial),
    ];

    return BaseAPITest(
      title: 'IMSDK API 测试',
      inputFields: inputFields,
      buttons: buttons,
      onClearLog: _clearLog,
    );
  }

  // 创建宽度根据内容自适应的按钮
  Widget _buildDynamicButton(String text, VoidCallback onPressed) {
    // 根据文本长度计算大致宽度，保证文本能完全显示
    double width = text.length * BUTTON_CHAR_WIDTH + BUTTON_EXTRA_WIDTH;

    return Container(
      margin: const EdgeInsets.only(bottom: BUTTON_BOTTOM_MARGIN),
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: BUTTON_HORIZONTAL_PADDING, vertical: BUTTON_VERTICAL_PADDING),
          minimumSize: Size(width, BUTTON_MIN_HEIGHT),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          // 缩小点击区域
          visualDensity: VisualDensity.compact,
          // 更紧凑的视觉密度
          textStyle: const TextStyle(fontSize: BUTTON_FONT_SIZE),
          foregroundColor: BUTTON_TEXT_COLOR,
          backgroundColor: BUTTON_BG_COLOR,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(BUTTON_BORDER_RADIUS),
          ),
        ),
        child: Text(text),
      ),
    );
  }

  @override
  void dispose() {
    _loginUserController.dispose();
    _receiverIDController.dispose();
    _groupIDController.dispose();
    _conversationIDController.dispose();
    _messageController.dispose();
    _customDataController.dispose();
    _userIDListController.dispose();
    _groupTypeController.dispose();
    _groupNameController.dispose();
    super.dispose();
  }
}
