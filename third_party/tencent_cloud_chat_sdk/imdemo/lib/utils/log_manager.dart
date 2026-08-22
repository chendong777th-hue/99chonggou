import 'package:flutter/foundation.dart';

/// 全局日志管理器，用于集中管理各种日志
/// 使用 ChangeNotifier 实现响应式更新
class LogManager extends ChangeNotifier {
  // 单例实现
  static final LogManager _instance = LogManager._internal();
  factory LogManager() => _instance;
  LogManager._internal();

  // 各种类型的日志
  String _logText = '';
  String _simpleMsgLog = '';
  String _advMsgLog = '';
  String _groupLog = '';
  String _timSDKLog = '';
  String _conversationLog = '';
  String _friendshipLog = '';
  String _communityLog = '';

  // Getters
  String get logText => _logText;
  String get simpleMsgLog => _simpleMsgLog;
  String get advMsgLog => _advMsgLog;
  String get groupLog => _groupLog;
  String get timSDKLog => _timSDKLog;
  String get conversationLog => _conversationLog;
  String get friendshipLog => _friendshipLog;
  String get communityLog => _communityLog;

  // 更新操作日志
  void updateLogText(String text) {
    _logText = '$text\n$_logText';
    notifyListeners();
  }

  // 更新简单消息日志
  void updateSimpleMsgLog(String text) {
    _simpleMsgLog = '$text\n$_simpleMsgLog';
    notifyListeners();
  }

  // 更新高级消息日志
  void updateAdvMsgLog(String text) {
    _advMsgLog = '$text\n$_advMsgLog';
    notifyListeners();
  }

  // 更新群组日志
  void updateGroupLog(String text) {
    _groupLog = '$text\n$_groupLog';
    notifyListeners();
  }

  // 更新网络状态日志
  void updateNetStatusLog(String text) {
    _timSDKLog = '$text\n$_timSDKLog';
    notifyListeners();
  }

  // 更新会话日志
  void updateConversationLog(String text) {
    _conversationLog = '$text\n$_conversationLog';
    notifyListeners();
  }

  // 更新好友日志
  void updateFriendshipLog(String text) {
    _friendshipLog = '$text\n$_friendshipLog';
    notifyListeners();
  }

  // 更新社区日志
  void updateCommunityLog(String text) {
    _communityLog = '$text\n$_communityLog';
    notifyListeners();
  }

  // 清空所有日志
  void clearAllLogs() {
    _logText = '';
    _simpleMsgLog = '';
    _advMsgLog = '';
    _groupLog = '';
    _timSDKLog = '';
    _conversationLog = '';
    _friendshipLog = '';
    _communityLog = '';
    notifyListeners();
  }
} 