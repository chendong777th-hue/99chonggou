import 'package:tencent_cloud_chat_sdk/utils/utils.dart';

/// V2TimGroupChangeInfo
///
/// {@category Models}
///
class V2TimGroupChangeInfo {
  int? type;
  String? value;
  String? key;
  bool? boolValue;
  int? intValue;

  V2TimGroupChangeInfo({
    required this.type,
    this.value,
    this.key,
    this.boolValue,
    this.intValue,
  });

  V2TimGroupChangeInfo.fromJson(Map json) {
    json = Utils.formatJson(json);
    type = json['type'];
    value = json['value'];
    key = json['key'];
    boolValue = json['boolValue'];
    intValue = json["intValue"];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['type'] = type;
    data['value'] = value;
    data['key'] = key;
    data['boolValue'] = boolValue;
    data['intValue'] = intValue;
    return data;
  }
  String toLogString() {
    String res = "type:$type|value:$value|key:$key|boolValue:$boolValue|intValue:$intValue";
    return res;
  }
}

// {
//   "type":0,
//   "value":"",
//   "key":""
// }
