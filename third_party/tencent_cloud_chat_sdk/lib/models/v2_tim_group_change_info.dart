import 'package:tencent_cloud_chat_sdk/utils/utils.dart';

/// V2TimGroupChangeInfo
///
/// {@category Models}
///
class V2TimGroupChangeInfo {
  /// [GroupChangeInfoType]
  int? type;
  String? value;
  String? key;
  bool? boolValue;
  int? intValue;
  int? uint64Value;

  V2TimGroupChangeInfo({
    required this.type,
    this.value,
    this.key,
    this.boolValue,
    this.intValue,
  });

  V2TimGroupChangeInfo.fromJson(Map json) {
    json = Utils.formatJson(json);
    type = json['group_tips_group_change_info_flag'];
    value = json['group_tips_group_change_info_value'];
    key = json['group_tips_group_change_info_key'];
    boolValue = json['group_tips_group_change_info_bool_value'];
    intValue = json["group_tips_group_change_info_int_value"];
    if ( json['group_tips_group_change_info_uint64_value'] is int) {
      uint64Value = json['group_tips_group_change_info_uint64_value'];
    }
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['group_tips_group_change_info_flag'] = type;
    data['group_tips_group_change_info_value'] = value;
    data['group_tips_group_change_info_key'] = key;
    data['group_tips_group_change_info_bool_value'] = boolValue;
    data['group_tips_group_change_info_int_value'] = intValue;
    data['group_tips_group_change_info_uint64_value'] = uint64Value;
    return data;
  }

  String toLogString() {
    String res = "type:$type|value:$value|key:$key|boolValue:$boolValue|intValue:$intValue|uint64Value:$uint64Value";
    return res;
  }
}

// {
//   "type":0,
//   "value":"",
//   "key":""
// }
