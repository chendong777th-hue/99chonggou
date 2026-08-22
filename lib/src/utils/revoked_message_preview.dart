import 'dart:convert';

import 'package:tencent_chat_i18n_tool/tencent_chat_i18n_tool.dart';
import 'package:tencent_cloud_chat_sdk/enum/message_status.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_message.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_message.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_user_full_info.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_user_full_info.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/message.dart';

bool isRevokedMessage(V2TimMessage? message) {
  if (message == null) {
    return false;
  }
  if (message.status == MessageStatus.V2TIM_MSG_STATUS_LOCAL_REVOKED) {
    return true;
  }
  final revokerId = message.revokerInfo?.userID?.trim() ?? '';
  if (revokerId.isNotEmpty) {
    return true;
  }
  return _readRevokeFlag(message.cloudCustomData) ||
      _readRevokeFlag(message.localCustomData);
}

bool isRevokedByAdmin(V2TimMessage message) {
  return _readAdminRevokeFlag(message.cloudCustomData) ||
      _readAdminRevokeFlag(message.localCustomData);
}

String buildRevokedMessagePreviewLabel(V2TimMessage message) {
  final isSelf = message.isSelf ?? true;
  final isAdmin = isRevokedByAdmin(message);
  final isGroup = message.groupID?.trim().isNotEmpty ?? false;
  final actor = isAdmin
      ? TIM_t('管理员')
      : (isSelf
          ? TIM_t('您')
          : (isGroup
              ? MessageUtils.getDisplayName(message)
              : TIM_t('对方')));
  return TIM_t_para('{{option1}}撤回了一条消息', '$actor撤回了一条消息')(
    option1: actor,
  );
}

void applyRevokedStateToMessage(
  V2TimMessage message, {
  bool isAdmin = false,
}) {
  message.status = MessageStatus.V2TIM_MSG_STATUS_LOCAL_REVOKED;
  message.cloudCustomData = _revokedCloudCustomData(
    message.cloudCustomData,
    isAdmin: isAdmin,
  );
}

/// 收到对端/管理员撤回回调时，除本地撤回旗外写入 revokerInfo 供列表识别。
void applyRemoteRevokedStateToMessage(
  V2TimMessage message, {
  bool isAdmin = false,
  V2TimUserFullInfo? revoker,
}) {
  applyRevokedStateToMessage(message, isAdmin: isAdmin);
  final revokerId = revoker?.userID?.trim() ?? '';
  if (revokerId.isNotEmpty) {
    message.revokerInfo = revoker;
  }
}

bool messagesReferToSameMessage(V2TimMessage? left, V2TimMessage? right) {
  if (left == null || right == null) {
    return false;
  }
  final leftMsgID = left.msgID?.trim() ?? '';
  final rightMsgID = right.msgID?.trim() ?? '';
  if (leftMsgID.isNotEmpty && leftMsgID == rightMsgID) {
    return true;
  }
  final leftClientId = left.id?.trim() ?? '';
  final rightClientId = right.id?.trim() ?? '';
  if (leftClientId.isNotEmpty && leftClientId == rightClientId) {
    return true;
  }
  if (leftMsgID.isNotEmpty && leftMsgID == rightClientId) {
    return true;
  }
  if (rightMsgID.isNotEmpty && rightMsgID == leftClientId) {
    return true;
  }
  return false;
}

/// SDK 回写会话 lastMessage 时，保留本地已撤回的同一条消息状态。
void preserveRevokedLastMessageState({
  required V2TimMessage? existing,
  required V2TimMessage? incoming,
  required V2TimMessage preferred,
}) {
  for (final source in <V2TimMessage?>[existing, incoming]) {
    if (source == null || !isRevokedMessage(source)) {
      continue;
    }
    if (!messagesReferToSameMessage(source, preferred)) {
      continue;
    }
    applyRevokedStateToMessage(
      preferred,
      isAdmin: isRevokedByAdmin(source),
    );
    return;
  }
}

/// SDK 迟到回写可能带 isPeerRead=false；保留本地已标对端已读。
void preservePeerReadLastMessageState({
  required V2TimMessage? existing,
  required V2TimMessage? incoming,
  required V2TimMessage preferred,
}) {
  if (preferred.isPeerRead == true) {
    return;
  }
  for (final source in <V2TimMessage?>[existing, incoming]) {
    if (source == null || source.isPeerRead != true) {
      continue;
    }
    if (!messagesReferToSameMessage(source, preferred)) {
      continue;
    }
    preferred.isPeerRead = true;
    return;
  }
}

/// 会话列表 UI 指纹用：撤回态变化时也要触发刷新。
String revokedLastMessageFingerprint(V2TimMessage? message) {
  if (message == null) {
    return '';
  }
  if (!isRevokedMessage(message)) {
    return '0';
  }
  final admin = isRevokedByAdmin(message) ? '1' : '0';
  return '1|$admin|${message.status ?? -1}';
}

bool lastMessageMatchesRevokeTarget(
  V2TimMessage message,
  String targetMsgID,
) {
  final target = targetMsgID.trim();
  if (target.isEmpty) {
    return false;
  }
  final msgID = message.msgID?.trim() ?? '';
  final clientId = message.id?.trim() ?? '';
  return msgID == target || clientId == target;
}

bool _readRevokeFlag(String? raw) {
  final data = _decodeMap(raw);
  return data?['isRevoke'] == true;
}

bool _readAdminRevokeFlag(String? raw) {
  final data = _decodeMap(raw);
  return data?['revokeByAdmin'] == true;
}

Map<String, dynamic>? _decodeMap(String? raw) {
  final value = raw?.trim();
  if (value == null || value.isEmpty) {
    return null;
  }
  try {
    final decoded = jsonDecode(value);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
    if (decoded is Map) {
      return Map<String, dynamic>.from(decoded);
    }
  } catch (_) {}
  return null;
}

String _revokedCloudCustomData(String? raw, {required bool isAdmin}) {
  final data = _decodeMap(raw) ?? <String, dynamic>{};
  data['isRevoke'] = true;
  data['revokeByAdmin'] = isAdmin;
  return jsonEncode(data);
}
