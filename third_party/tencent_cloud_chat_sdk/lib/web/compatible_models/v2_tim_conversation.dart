import 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_group_at_info.dart';
import 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_message.dart';
import 'package:tencent_cloud_chat_sdk/utils/utils.dart';

/// V2TimConversation
///
/// {@category Models}
///
class V2TimConversation {
  late String conversationID;
  int? type;
  String? userID;
  String? groupID;
  String? showName;
  String? faceUrl;
  String? groupType;
  int? unreadCount;
  V2TimMessage? lastMessage;
  String? draftText;
  int? draftTimestamp;
  bool? isPinned;
  int? recvOpt;
  List<V2TimGroupAtInfo?>? groupAtInfoList = List.empty(growable: true);
  int? orderkey;
  List<int?>? markList;
  String? customData;
  List<String?>? conversationGroupList;
  int? c2cReadTimestamp;
  int? groupReadSequence;
  V2TimConversation({
    required this.conversationID,
    this.type,
    this.userID,
    this.groupID,
    this.showName,
    this.faceUrl,
    this.groupType,
    this.unreadCount,
    this.lastMessage,
    this.draftText,
    this.draftTimestamp,
    this.groupAtInfoList,
    this.isPinned,
    this.recvOpt,
    this.orderkey,
    this.markList,
    this.customData,
    this.conversationGroupList,
    this.c2cReadTimestamp,
    this.groupReadSequence,
  });

  V2TimConversation.fromJson(Map json) {
    json = Utils.formatJson(json);
    String? gid = json['groupID'] == "" ? null : json['groupID'];
    String? uid = json['userID'] == "" ? null : json['userID'];
    c2cReadTimestamp = json["c2cReadTimestamp"] ?? 0;
    groupReadSequence = json["groupReadSequence"] ?? 0;
    conversationID = (json['conversationID'] ?? '').toString();
    type = json['type'];
    userID = uid;
    groupID = gid;
    showName = json['showName'];
    faceUrl = json['faceUrl'];
    groupType = json['groupType'];
    unreadCount = json['unreadCount'];
    isPinned = json['isPinned'];
    recvOpt = json['recvOpt'];
    orderkey = json['orderkey'];
    lastMessage = json['lastMessage'] != null
        ? V2TimMessage.fromJson(json['lastMessage'])
        : null;
    draftText = json['draftText'];
    customData = json['customData'];
    draftTimestamp = json['draftTimestamp'];
    if (json['markList'] != null) {
      markList = List.empty(growable: true);
      json['markList'].forEach((v) {
        markList?.add(v);
      });
    }
    if (json['conversationGroupList'] != null) {
      conversationGroupList = List.empty(growable: true);
      json['conversationGroupList'].forEach((v) {
        conversationGroupList?.add(v);
      });
    }

    if (json['groupAtInfoList'] != null) {
      groupAtInfoList = List.empty(growable: true);
      json['groupAtInfoList'].forEach((v) {
        groupAtInfoList!.add(V2TimGroupAtInfo.fromJson(v));
      });
    }
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['conversationID'] = conversationID;
    data['type'] = type;
    data['userID'] = userID;
    data['groupID'] = groupID;
    data['showName'] = showName;
    data['faceUrl'] = faceUrl;
    data['groupType'] = groupType;
    data['unreadCount'] = unreadCount;
    data['isPinned'] = isPinned;
    data['recvOpt'] = recvOpt;
    data['orderkey'] = orderkey;
    data['customData'] = customData;
    data['c2cReadTimestamp'] = c2cReadTimestamp ?? 0;
    data['groupReadSequence'] = groupReadSequence ?? 0;

    if (lastMessage != null) {
      data['lastMessage'] = lastMessage!.toJson();
    }
    data['draftText'] = draftText;
    data['draftTimestamp'] = draftTimestamp;
    if (groupAtInfoList != null) {
      data['groupAtInfoList'] =
          groupAtInfoList?.map((v) => v?.toJson()).toList();
    }
    if (conversationGroupList != null) {
      data['conversationGroupList'] =
          conversationGroupList?.map((v) => v).toList();
    }
    if (markList != null) {
      data['markList'] = markList?.map((v) => v).toList();
    }
    return data;
  }
  String toLogString() {
    String res =
        "conversationID:$conversationID|type:$type|userID:$userID|groupID:$groupID|showName:$showName|groupType:$groupType|unreadCount:$unreadCount|isPinned:$isPinned|recvOpt:$recvOpt|customData:$customData|c2cReadTimestamp:$c2cReadTimestamp|groupReadSequence:$groupReadSequence|lastMessage:${lastMessage?.msgID}";
    return res;
  }
}
// {
//   "conversationID":"",
//   "type":0,
//   "userID":"",
//   "groupID":"",
//   "showName":"",
//   "faceUrl":"",
// "groupType":"",
// "unreadCount":0,
// "lastMessage":{},
// "draftText":"",
// "draftTimestamp":0,
// "groupAtInfoList":[{}]
// }
