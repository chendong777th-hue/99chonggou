import 'package:tencent_cloud_chat_sdk/utils/utils.dart';

/// V2TimReceiveRestCustomData
///
/// {@category Models}
///
class V2TimReceiveRestCustomData {
  late String groupID;
  late String customData;

  V2TimReceiveRestCustomData({
    required this.groupID,
    required this.customData,
  });

  V2TimReceiveRestCustomData.fromJson(Map json) {
    json = Utils.formatJson(json);
    groupID = json['groupID'];
    customData = json['customData'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['groupID'] = groupID;
    data['customData'] = customData;
    return data;
  }
  String toLogString() {
    String res = "groupID:$groupID|customData:$customData";
    return res;
  }
}

// {
//   "groupID":"",
//   "customData":""
// }
