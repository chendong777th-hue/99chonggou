import 'package:tencent_cloud_chat_sdk/enum/history_msg_get_type_enum.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_message.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_message.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_message_list_result.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_message_list_result.dart';

class WebHistoryLoader {
  static Future<V2TimMessageListResult?> loadWithComplete({
    required HistoryMsgGetTypeEnum getType,
    String? userID,
    String? groupID,
    int lastMsgSeq = 0,
    required int count,
    String? lastMsgID,
    List<int>? messageTypeList,
  }) async {
    return null;
  }

  static Future<List<V2TimMessage>?> loadList({
    required HistoryMsgGetTypeEnum getType,
    String? userID,
    String? groupID,
    int lastMsgSeq = -1,
    required int count,
    String? lastMsgID,
    List<int>? messageTypeList,
  }) async {
    return null;
  }
}
