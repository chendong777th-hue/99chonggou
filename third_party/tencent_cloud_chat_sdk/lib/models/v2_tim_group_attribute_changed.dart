import 'dart:convert';

import 'package:tencent_cloud_chat_sdk/native_im/tools.dart';
import 'package:tencent_cloud_chat_sdk/utils/utils.dart';

/// V2TimGroupAttributeChanged
///
/// {@category Models}
///
class V2TimGroupAttributeChanged {
  late String groupID;
  late Map<String, String> groupAttributeMap;

  V2TimGroupAttributeChanged({
    required this.groupID,
    required this.groupAttributeMap,
  });

  V2TimGroupAttributeChanged.fromJson(Map json) {
    json = Utils.formatJson(json);
    groupID = json["group_id"] ?? '';
    final groupChangeAttributeList = jsonDecode(json["json_group_attribute_array"]);
    groupAttributeMap = {};
    if (groupChangeAttributeList is List && groupChangeAttributeList.isNotEmpty) {
      groupAttributeMap = Tools.jsonList2Map<String>(groupChangeAttributeList.whereType<Map<String, dynamic>>().toList(), 'group_attribute_key', 'group_attribute_value');
    }
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['groupID'] = groupID;
    data['groupAttributeMap'] = groupAttributeMap;
    return data;
  }
  String toLogString() {
    String res = "groupID:$groupID|groupAttributeMap:${json.encode(groupAttributeMap)}";
    return res;
  }
}
// {
//   "groupID":"",
//   "groupAttributeMap":{}
// }
