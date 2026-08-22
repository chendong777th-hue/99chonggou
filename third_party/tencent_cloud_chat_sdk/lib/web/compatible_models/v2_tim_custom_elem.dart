import 'package:tencent_cloud_chat_sdk/utils/utils.dart';
import 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_elem.dart';

/// V2TimCustomElem
///
/// {@category Models}
///
class V2TimCustomElem extends V2TIMElem {
  late String? data;
  late String? desc;
  late String? extension;

  V2TimCustomElem({
    this.data,
    this.desc,
    this.extension,
  });

  V2TimCustomElem.fromJson(Map json) {
    json = Utils.formatJson(json);
    data = json['data'];
    desc = json['desc'];
    extension = json['extension'];
    if (json['nextElem'] != null) {
      nextElem = Utils.formatJson(json['nextElem']);
    }
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['data'] = this.data;
    data['desc'] = desc;
    data['extension'] = extension;
    if (nextElem != null) {
      data['nextElem'] = nextElem;
    }
    return data;
  }
  String toLogString() {
    String res = "data:$data|desc:$desc|extension:$extension";
    return res;
  }
}
// {
//   "data":"",
//   "desc":"",
//   "extension":""
// }
