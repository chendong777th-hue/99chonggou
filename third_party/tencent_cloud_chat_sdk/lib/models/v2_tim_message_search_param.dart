import 'package:tencent_cloud_chat_sdk/utils/utils.dart';
import 'package:tencent_cloud_chat_sdk/enum/utils.dart';

import 'package:tencent_cloud_chat_sdk/native_im/bindings/native_imsdk_bindings_generated.dart';

/// V2TimMessageSearchParam
///
/// {@category Models}
///
class V2TimMessageSearchParam {
  String? conversationID;
  List<String>? keywordList;
  int? type;
  List<String>? userIDList = [];
  List<int>? messageTypeList = [];
  int? searchTimePosition;
  int? searchTimePeriod;
  int? pageSize = 100;
  int? pageIndex = 0;
  int? searchCount = 10;
  String? searchCursor = "";
  V2TimMessageSearchParam({
    required this.type,
    required this.keywordList,
    this.conversationID,
    this.userIDList,
    this.messageTypeList,
    this.searchTimePosition,
    this.searchTimePeriod,
    this.pageSize,
    this.pageIndex,
    this.searchCount,
    this.searchCursor,
  }) {
    messageTypeList = messageTypeList?.map((e) => EnumUtils.dartElemType2CElemType(e)).toList();
  }

  V2TimMessageSearchParam.fromJson(Map json) {
    json = Utils.formatJson(json);
    String cConversationID = json['msg_search_param_conv_id'];
    int cIntConversationType = 0;
    cIntConversationType = json['msg_search_param_conv_type'];
    if (cIntConversationType == TIMConvType.kTIMConv_C2C.value) {
      conversationID = "c2c_$cConversationID";
    } else if (cIntConversationType == TIMConvType.kTIMConv_Group.value) {
      conversationID = "group_$cConversationID";
    }

    keywordList = json['msg_search_param_keyword_array']?.cast<String>() ?? [];
    type = json['msg_search_param_keyword_list_match_type'];
    userIDList = json['msg_search_param_send_identifier_array']?.cast<String>() ?? [];
    messageTypeList = json['msg_search_param_message_type_array']?.cast<int>() ?? [];
    searchTimePosition = json['msg_search_param_search_time_position'];
    searchTimePeriod = json['msg_search_param_search_time_period'];
    pageSize = json['msg_search_param_page_size'];
    pageIndex = json['msg_search_param_page_index'];
    searchCount = json["msg_search_param_search_count"] ?? 10;
    searchCursor = json["msg_search_param_search_cursor"] ?? "";

    messageTypeList = messageTypeList?.map((e) => EnumUtils.cElemType2DartElemType(e)).toList();
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    if (conversationID != null && conversationID!.isNotEmpty) {
      TIMConvType cConversationType = TIMConvType.kTIMConv_Invalid;
      String cConversationID = "";
      if (conversationID!.startsWith('c2c_')) {
        cConversationType = TIMConvType.kTIMConv_C2C;
        cConversationID = conversationID!.substring(4);
      } else if (conversationID!.startsWith('group_')) {
        cConversationType = TIMConvType.kTIMConv_Group;
        cConversationID = conversationID!.substring(6);
      }

      if (cConversationID.isNotEmpty) {
        data['msg_search_param_conv_id'] = cConversationID;
        data['msg_search_param_conv_type'] = cConversationType.value;
      }
    }

    data['msg_search_param_keyword_array'] = keywordList;
    data['msg_search_param_keyword_list_match_type'] = type;
    data['msg_search_param_send_identifier_array'] = userIDList ?? List.empty(growable: true);
    data['msg_search_param_message_type_array'] = messageTypeList ?? List.empty(growable: true);
    data['msg_search_param_search_time_position'] = searchTimePosition;
    data['msg_search_param_search_time_period'] = searchTimePeriod;
    data['msg_search_param_page_size'] = pageSize;
    data['msg_search_param_page_index'] = pageIndex;
    data['msg_search_param_search_count'] = searchCount;
    data['msg_search_param_search_cursor'] = searchCursor;
    return data;
  }
  String toLogString() {
    String res = "conversationID:$conversationID|keywordList:$keywordList|type:$type|userIDList:$userIDList|messageTypeList:$messageTypeList|searchTimePosition:$searchTimePosition|searchTimePeriod:$searchTimePeriod|pageSize:$pageSize|pageIndex:$pageIndex|searchCount:$searchCount|searchCursor:$searchCursor";
    return res;
  }
}
