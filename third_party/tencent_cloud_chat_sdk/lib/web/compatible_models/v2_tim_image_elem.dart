import 'dart:convert';

import 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_elem.dart';
import 'package:tencent_cloud_chat_sdk/utils/utils.dart';
import 'v2_tim_image.dart';

/// V2TimImageElem
///
/// {@category Models}
///

class V2TimImageElem extends V2TIMElem {
  /// 图片本地路径，仅在发送消息时有效，用做发消息提前上屏预览
  late String? path;

  /// 图片资源列表
  List<V2TimImage?>? imageList = List.empty(growable: true);

  V2TimImageElem({
    this.path,
    this.imageList,
  });

  V2TimImageElem.fromJson(Map json) {
    json = Utils.formatJson(json);
    path = json['path'];
    if (json['imageList'] != null) {
      imageList = List.empty(growable: true);
      json['imageList'].forEach((v) {
        imageList!.add(V2TimImage.fromJson(v));
      });
    }
    if (json['nextElem'] != null) {
      nextElem = Utils.formatJson(json['nextElem']);
    }
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['path'] = path;
    if (imageList != null) {
      data['imageList'] = imageList?.map((v) => v?.toJson()).toList();
    }
    if (nextElem != null) {
      data['nextElem'] = nextElem;
    }
    return data;
  }
  String toLogString() {
    String res = "path:${path == null ? false : true}|imageList:${json.encode(imageList?.map((e) => e?.toLogString()).toList())}";
    return res;
  }
}
// {
//   "path":"",
//   "imageList":[{}]
// }
