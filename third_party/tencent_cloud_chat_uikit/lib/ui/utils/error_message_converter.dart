import 'dart:convert';

import 'package:tencent_chat_i18n_tool/tencent_chat_i18n_tool.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/c2c_peer_id.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_friend_info.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_friend_info.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_message.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_message.dart';

class ErrorMessageConverter {
  static const String sendFailCodeKey = 'sendFailCode';

  static const Set<int> friendRelationFailCodes = {20009, 20010, 20011};
  static Map<int, String> errorCodeMap = {
    10007: TIM_t("操作权限不足"),
    20007: TIM_t("发送单聊消息，被对方拉黑，禁止发送。"),
    20009: TIM_t("对方不是好友，无法发送消息"),
    20010: TIM_t("您不是对方的好友，无法发送该消息。"),
    20011: TIM_t("对方不是您的好友，无法发送该消息。"),
    30010: TIM_t("您的好友数已达系统上限"),
    30014: TIM_t("对方的好友数已达系统上限"),
    30015: TIM_t("对方已是您的好友"),
    30515: TIM_t("被加好友在自己的黑名单中"),
    30516: TIM_t("对方已禁止加好友"),
    30525: TIM_t("您已被被对方设置为黑名单"),
    30539: TIM_t("等待好友审核同意"),
    131006: TIM_t("公众号未开通或未发布，暂无法发送消息，请联系管理员在 IM 控制台启用运营公众号"),
  };

  static String getErrorMessage(int code, [String? errorDesc]) {
    if (errorCodeMap.containsKey(code)) {
      return errorCodeMap[code]!;
    }
    if (errorDesc != null && errorDesc.isNotEmpty) {
      final sdkDesc = localizeSdkDesc(errorDesc);
      if (sdkDesc.isNotEmpty) {
        return sdkDesc;
      }
      final matched = _matchErrorDesc(errorDesc);
      if (matched.isNotEmpty) {
        return matched;
      }
    }
    return "";
  }

  /// 将 SDK 返回的英文错误文案转为中文（用于消息气泡等直接展示 desc 的场景）。
  static String localizeMessageText(String text) {
    if (text.isEmpty) {
      return text;
    }
    final matched = _matchErrorDesc(text);
    return matched.isNotEmpty ? matched : text;
  }

  static String localizeSdkDesc(String? desc) {
    if (desc == null || desc.isEmpty) {
      return '';
    }
    final lower = desc.toLowerCase();
    if (lower.contains('last request is running')) {
      return TIM_t("上一个操作还在处理中，请稍后再试");
    }
    return '';
  }

  static bool isLastRequestRunningError(String? desc) {
    return (desc ?? '').toLowerCase().contains('last request is running');
  }

  static String _matchErrorDesc(String desc) {
    final lower = desc.toLowerCase();
    if (lower.contains('sender and receiver are not friends') ||
        (lower.contains('not friends') && lower.contains('fail to send'))) {
      return TIM_t("对方不是好友，无法发送消息");
    }
    if (lower.contains('you are not friend of receiver') ||
        lower.contains('you are not a friend of the receiver')) {
      return TIM_t("您不是对方的好友，无法发送该消息。");
    }
    if (lower.contains('receiver is not friend of you') ||
        lower.contains('receiver is not a friend of you')) {
      return TIM_t("对方不是您的好友，无法发送该消息。");
    }
    if (lower.contains('not open') &&
        (lower.contains('official') || lower.contains('account'))) {
      return TIM_t("公众号未开通或未发布，暂无法发送消息，请联系管理员在 IM 控制台启用运营公众号");
    }
    return "";
  }

  static String get friendDeletedByOtherHintPrefix =>
      TIM_t("对方不是您的好友，");

  static String get friendDeletedByOtherHintLink => TIM_t("请重新添加好友");

  static String get friendDeletedByOtherHint =>
      friendDeletedByOtherHintPrefix + friendDeletedByOtherHintLink;

  static bool isFriendRelationSendFail(int code) =>
      friendRelationFailCodes.contains(code);

  static void attachSendFailCode(V2TimMessage message, int code) {
    if (!isFriendRelationSendFail(code)) {
      return;
    }
    Map<String, dynamic> map = {};
    final raw = message.localCustomData;
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = json.decode(raw);
        if (decoded is Map) {
          map = Map<String, dynamic>.from(decoded);
        }
      } catch (_) {}
    }
    map[sendFailCodeKey] = code;
    message.localCustomData = json.encode(map);
  }

  static void clearSendFailCode(V2TimMessage message) {
    final raw = message.localCustomData;
    if (raw == null || raw.isEmpty) {
      return;
    }
    try {
      final decoded = json.decode(raw);
      if (decoded is! Map || decoded[sendFailCodeKey] == null) {
        return;
      }
      final map = Map<String, dynamic>.from(decoded);
      map.remove(sendFailCodeKey);
      message.localCustomData = map.isEmpty ? '' : json.encode(map);
    } catch (_) {}
  }

  static int? getSendFailCode(V2TimMessage? message) {
    if (message == null) {
      return null;
    }
    final raw = message.localCustomData;
    if (raw == null || raw.isEmpty) {
      return null;
    }
    try {
      final decoded = json.decode(raw);
      if (decoded is Map && decoded[sendFailCodeKey] != null) {
        return int.tryParse(decoded[sendFailCodeKey].toString());
      }
    } catch (_) {}
    return null;
  }

  /// 是否应在失败消息下方展示「被对方删除好友」提示（调用方需已确认为单聊且发送失败）。
  static bool shouldShowFriendDeletedHint(
    V2TimMessage message, {
    String? c2cPeerUserId,
    List<V2TimFriendInfo>? friendList,
  }) {
    final code = getSendFailCode(message);
    if (code != null) {
      return isFriendRelationSendFail(code);
    }
    final text = message.textElem?.text ?? '';
    if (_matchErrorDesc(text).isNotEmpty) {
      return true;
    }
    if (c2cPeerUserId != null && friendList != null) {
      final peerId = normalizedPeerUserId(c2cPeerUserId);
      if (peerId.isEmpty) {
        return false;
      }
      for (final friend in friendList) {
        if (normalizedPeerUserId(friend.userID) != peerId) {
          continue;
        }
        final custom = friend.friendCustomInfo;
        if (custom != null) {
          if (custom['canMessage'] == '0') {
            return true;
          }
          if (custom['peerDeletedMe'] == '1') {
            return true;
          }
        }
        return false;
      }
      // 无明确好友关系错误码时，不在好友列表中也不能推断为「非好友」
      // （可能是网络失败、好友缓存未同步，或 conversationID 与 userID 形态不一致）。
      return false;
    }
    return false;
  }

  static String normalizedPeerUserId(String? raw) {
    return C2cPeerId.normalize(raw);
  }
}
