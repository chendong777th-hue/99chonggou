import 'package:tencent_cloud_chat_sdk/utils/utils.dart';

/// V2TimMessageSearchParam
///
/// {@category Models}
///
class V2TimMessageSearchParam {
  String? conversationID;
  late List<String> keywordList;
  late int type;
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
  });

  V2TimMessageSearchParam.fromJson(Map json) {
    json = Utils.formatJson(json);
    conversationID = json['conversationID'];
    keywordList = json['keywordList'] == null
        ? List.empty(growable: true)
        : json['keywordList'].cast<String>();
    type = json['type'];
    userIDList = json['userIDList'] == null
        ? List.empty(growable: true)
        : json['userIDList'].cast<String>();
    messageTypeList = json['messageTypeList'] == null
        ? List.empty(growable: true)
        : json['messageTypeList'].cast<int>();
    searchTimePosition = json['searchTimePosition'];
    searchTimePeriod = json['searchTimePeriod'];
    pageSize = json['pageSize'];
    pageIndex = json['pageIndex'];
    searchCount = json["searchCount"] ?? 10;
    searchCursor = json["searchCursor"] ?? "";
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['conversationID'] = conversationID;
    data['keywordList'] = keywordList;
    data['type'] = type;
    data['userIDList'] = userIDList ?? List.empty(growable: true);
    data['messageTypeList'] = messageTypeList ?? List.empty(growable: true);
    data['searchTimePosition'] = searchTimePosition;
    data['searchTimePeriod'] = searchTimePeriod;
    data['pageSize'] = pageSize;
    data['pageIndex'] = pageIndex;
    data['searchCount'] = searchCount;
    data['searchCursor'] = searchCursor;
    return data;
  }
  String toLogString() {
    String res = "conversationID:$conversationID|";
    return res;
  }
}
