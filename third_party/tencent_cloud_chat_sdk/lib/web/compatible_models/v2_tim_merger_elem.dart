import 'dart:convert';

import 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_elem.dart';
import 'package:tencent_cloud_chat_sdk/utils/utils.dart';

class V2TimMergerElem extends V2TIMElem {
  late bool? isLayersOverLimit;
  late String? title;
  List<String>? abstractList = List.empty(growable: true);

  V2TimMergerElem({
    this.isLayersOverLimit,
    this.title,
    this.abstractList,
  });

  V2TimMergerElem.fromJson(Map json) {
    json = Utils.formatJson(json);
    isLayersOverLimit = json['isLayersOverLimit'];
    title = json['title'];
    abstractList = json['abstractList'].cast<String>();
    if (json['nextElem'] != null) {
      nextElem = Utils.formatJson(json['nextElem']);
    }
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['isLayersOverLimit'] = isLayersOverLimit;
    data['title'] = title;
    data['abstractList'] = abstractList;
    if (nextElem != null) {
      data['nextElem'] = nextElem;
    }
    return data;
  }

  String toLogString() {
    String res = "isLayersOverLimit:$isLayersOverLimit|title:$title|abstractList:${json.encode(abstractList ?? [])}";
    return res;
  }
}

// {
//   "isLayersOverLimit":true,
//   "title":"",
//   "abstractList":[""],
// }
