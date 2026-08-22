import 'dart:convert';

import 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_elem.dart';
import 'package:tencent_cloud_chat_sdk/utils/utils.dart';

/// V2TimTextElem
///
/// {@category Models}
class V2TimTextElem extends V2TIMElem {
  late String? text;

  V2TimTextElem({
    this.text,
  });

  V2TimTextElem.fromJson(Map json) {
    json = Utils.formatJson(json);
    text = json['text'];
    if (json['nextElem'] != null) {
      nextElem = Utils.formatJson(json['nextElem']);
    }
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['text'] = text;
    if (nextElem != null) {
      data['nextElem'] = nextElem;
    }
    return data;
  }

  formatJson(jsonSrc) {
    return json.decode(json.encode(jsonSrc));
  }
  String toLogString() {
    String res = "text:$text";
    return res;
  }
}

// {
//   "text":""
// }
