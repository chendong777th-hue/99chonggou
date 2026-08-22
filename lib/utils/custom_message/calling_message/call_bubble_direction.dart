import 'package:tencent_cloud_chat_demo/src/utils/call_user_id.dart';
import 'package:tencent_cloud_chat_demo/utils/custom_message/calling_message/calling_message_data_provider.dart';

/// C2C 通话气泡方向。
class CallBubbleDirection {
  CallBubbleDirection._();

  static const String callDirectionIncoming = 'incoming';
  static const String callDirectionOutgoing = 'outgoing';

  static bool isOutgoingCall({
    required String callerId,
    required String loginUserId,
  }) {
    return CallUserId.isSameCallUserId(callerId, loginUserId);
  }

  static CallMessageDirection resolveC2C({
    required String callerId,
    required String loginUserId,
    bool? fallbackIsSelf,
  }) {
    final caller = CallUserId.normalizeCallUserId(callerId);
    final self = CallUserId.normalizeCallUserId(loginUserId);
    if (caller.isNotEmpty && self.isNotEmpty) {
      return caller == self
          ? CallMessageDirection.outcoming
          : CallMessageDirection.incoming;
    }
    if (fallbackIsSelf != null) {
      return fallbackIsSelf
          ? CallMessageDirection.outcoming
          : CallMessageDirection.incoming;
    }
    return CallMessageDirection.incoming;
  }

  /// 终态操作（拒绝/取消）是否由当前登录用户触发。
  ///
  /// 方向与文案共用此判定，避免 operator 缺失时左右与文字不一致。
  static bool resolveC2CTerminalActionBySelf({
    required CallProtocolType protocolType,
    required String callerId,
    required String operatorId,
    required String loginUserId,
    bool? fallbackIsSelf,
  }) {
    final self = CallUserId.normalizeCallUserId(loginUserId);
    if (self.isEmpty) {
      return false;
    }

    final operator = CallUserId.normalizeCallUserId(operatorId);
    if (operator.isNotEmpty) {
      return CallUserId.isSameCallUserId(operator, self);
    }

    switch (protocolType) {
      case CallProtocolType.reject:
        // 拒绝消息通常由拒绝方发出；无 operator 时以 isSelf 为准。
        if (fallbackIsSelf == true) {
          return true;
        }
        if (fallbackIsSelf == false) {
          return false;
        }
        return false;
      case CallProtocolType.cancel:
        // 取消通常由主叫发起；无 operator 时回退到 caller / isSelf。
        final caller = CallUserId.normalizeCallUserId(callerId);
        if (caller.isNotEmpty) {
          return CallUserId.isSameCallUserId(caller, self);
        }
        if (fallbackIsSelf == true) {
          return true;
        }
        return false;
      default:
        return false;
    }
  }

  /// 终态通话气泡左右方向（展示用）。
  ///
  /// 优先 [callDirectionHint]（incoming/outgoing），其次 IM [fallbackIsSelf]。
  /// **不**用 callerId 推侧——主叫身份 ≠ 头像/左右权威。
  /// 文案「已拒绝 / 对方已拒绝」仍用 [resolveC2CTerminalActionBySelf] + operator。
  static CallMessageDirection resolveC2CDisplayDirection({
    required CallProtocolType protocolType,
    required String callerId,
    required String operatorId,
    required String loginUserId,
    bool? fallbackIsSelf,
    String? callDirectionHint,
  }) {
    final hint = callDirectionHint?.trim() ?? '';
    if (hint == callDirectionOutgoing) {
      return CallMessageDirection.outcoming;
    }
    if (hint == callDirectionIncoming) {
      return CallMessageDirection.incoming;
    }
    if (fallbackIsSelf == true) {
      return CallMessageDirection.outcoming;
    }
    if (fallbackIsSelf == false) {
      return CallMessageDirection.incoming;
    }
    return CallMessageDirection.incoming;
  }

  static CallProtocolType? protocolTypeFromLocalReason(String reasonName) {
    switch (reasonName.trim()) {
      case 'hangup':
        return CallProtocolType.hangup;
      case 'canceled':
      case 'otherDeviceAccepted':
      case 'endByServer':
        return CallProtocolType.cancel;
      case 'reject':
      case 'otherDeviceReject':
        return CallProtocolType.reject;
      case 'lineBusy':
        return CallProtocolType.lineBusy;
      case 'noResponse':
      case 'offline':
        return CallProtocolType.timeout;
      default:
        return CallProtocolType.cancel;
    }
  }

  /// 根据本地通话方向标记（incoming/outgoing）推断主叫 ID。
  static String? resolveCallerIdFromDirectionHint({
    required String? callDirection,
    required String loginUserId,
    required String peerUserId,
  }) {
    final direction = callDirection?.trim() ?? '';
    final self = CallUserId.normalizeCallUserId(loginUserId);
    final peer = CallUserId.normalizeCallUserId(peerUserId);
    if (direction == callDirectionIncoming && peer.isNotEmpty) {
      return peer;
    }
    if (direction == callDirectionOutgoing && self.isNotEmpty) {
      return self;
    }
    return null;
  }

  static bool isOutgoing(CallMessageDirection direction) {
    return direction == CallMessageDirection.outcoming;
  }
}
