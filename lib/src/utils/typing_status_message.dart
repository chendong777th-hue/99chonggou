import 'dart:convert';

import 'package:tencent_cloud_chat_sdk/enum/message_elem_type.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_message.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_message.dart';

/// Detects Tencent UIKit typing-status custom messages (`user_typing_status`).
///
/// These are online-only signals and must not trigger message alerts or enter
/// the visible chat history.
class TypingStatusMessage {
  TypingStatusMessage._();

  static bool isTypingStatus(V2TimMessage message) {
    if (message.elemType != MessageElemType.V2TIM_ELEM_TYPE_CUSTOM) {
      return false;
    }
    final groupId = message.groupID?.trim() ?? '';
    if (groupId.isNotEmpty) {
      return false;
    }
    final raw = message.customElem?.data?.trim() ?? '';
    if (raw.isEmpty) {
      return false;
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        return false;
      }
      final data = Map<String, dynamic>.from(decoded);
      if (data['businessID']?.toString() == 'user_typing_status') {
        return true;
      }
      final userAction = data['userAction'];
      if (userAction == 14) {
        final actionParam = data['actionParam']?.toString() ?? '';
        return actionParam == 'EIMAMSG_InputStatus_Ing' ||
            actionParam == 'EIMAMSG_InputStatus_End';
      }
    } catch (_) {}
    return false;
  }
}
