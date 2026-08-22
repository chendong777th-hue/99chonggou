import 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_elem.dart';
import 'package:tencent_cloud_chat_sdk/utils/utils.dart';

/// V2TimFaceElem
///
/// {@category Models}
///
class V2TimFaceElem extends V2TIMElem {
  late int? index;
  late String? data;

  V2TimFaceElem({
    this.index,
    this.data,
  });

  V2TimFaceElem.fromJson(Map json) {
    json = Utils.formatJson(json);
    index = json['index'];
    data = json['data'];
    if (json['nextElem'] != null) {
      nextElem = Utils.formatJson(json['nextElem']);
    }
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['index'] = index;
    data['data'] = this.data;
    if (nextElem != null) {
      data['nextElem'] = nextElem;
    }
    return data;
  }
  String toLogString() {
    String res = "index:$index|data:$data";
    return res;
  }
}
// {
//   "index":1,
//   "data":""
// }
