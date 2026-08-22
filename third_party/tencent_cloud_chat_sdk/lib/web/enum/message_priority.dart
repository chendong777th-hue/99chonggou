// ignore_for_file: non_constant_identifier_names
@JS()
library js_interop;

import 'package:js/js.dart'; // Pull in our dependency

import 'package:tencent_cloud_chat_sdk/enum/message_priority.dart';
import 'package:tencent_cloud_chat_sdk/web/utils/utils.dart';

@JS("TencentCloudChat")
class MessagePriorityEnum {
  external static dynamic TYPES; // 这个是用作枚举的
}

class MessagePriorityWeb {
  static String MSG_PRIORITY_NORMAL =
      jsToMap(MessagePriorityEnum.TYPES)["MSG_PRIORITY_NORMAL"];
  static String MSG_PRIORITY_HIGH =
      jsToMap(MessagePriorityEnum.TYPES)["MSG_PRIORITY_HIGH"];
  static String MSG_PRIORITY_LOW =
      jsToMap(MessagePriorityEnum.TYPES)["MSG_PRIORITY_HIGH"];
  static String MSG_PRIORITY_LOWEST =
      jsToMap(MessagePriorityEnum.TYPES)["MSG_PRIORITY_HIGH"];

  static int? convertMsgPriority(String priority) {
    if (priority == MSG_PRIORITY_NORMAL) {
      return MessagePriority.V2TIM_PRIORITY_DEFAULT;
    }

    if (priority == MSG_PRIORITY_LOW) {
      return MessagePriority.V2TIM_PRIORITY_NORMAL;
    }

    if (priority == MSG_PRIORITY_LOWEST) {
      return MessagePriority.V2TIM_PRIORITY_LOW;
    }

    if (priority == MSG_PRIORITY_HIGH) {
      return MessagePriority.V2TIM_PRIORITY_HIGH;
    }
    return null;
  }

  static String convertMsgPriorityToWeb(int priority) {
    if (priority == MessagePriority.V2TIM_PRIORITY_DEFAULT) {
      return MSG_PRIORITY_NORMAL;
    }

    if (priority == MessagePriority.V2TIM_PRIORITY_NORMAL) {
      return MSG_PRIORITY_LOW;
    }

    if (priority == MessagePriority.V2TIM_PRIORITY_LOW) {
      return MSG_PRIORITY_LOWEST;
    }

    if (priority == MessagePriority.V2TIM_PRIORITY_HIGH) {
      return MSG_PRIORITY_HIGH;
    }

    return '';
  }
}
