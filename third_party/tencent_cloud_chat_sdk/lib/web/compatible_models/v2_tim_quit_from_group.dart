import 'package:tencent_cloud_chat_sdk/utils/utils.dart';

/// V2TimQuitFromGroup
///
/// {@category Models}
///
class V2TimQuitFromGroup {
  late String groupID;

  V2TimQuitFromGroup({
    required this.groupID,
  });

  V2TimQuitFromGroup.fromJson(Map json) {
    json = Utils.formatJson(json);
    groupID = json['groupID'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['groupID'] = groupID;
    return data;
  }
  String toLogString() {
    String res = "groupID:$groupID";
    return res;
  }
}

// {
//   "groupID":""
// }
