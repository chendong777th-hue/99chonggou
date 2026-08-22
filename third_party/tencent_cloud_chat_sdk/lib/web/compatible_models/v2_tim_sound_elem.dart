import 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_elem.dart';
import 'package:tencent_cloud_chat_sdk/utils/utils.dart';

/// V2TimSoundElem
///
/// {@category Models}
///
class V2TimSoundElem extends V2TIMElem {
  ///语音本地路径，仅在消息发送成功之前有效，用作消息发送成功前语音消息预览
  late String? path;
  // ignore: non_constant_identifier_names
  late String? UUID;

  /// 语音大小
  late int? dataSize;

  /// 语音时长
  late int? duration;

  ///  语音消息url 5.0.2之后默认不返回，通过getMessageOnlineUrl异步获取
  late String? url;

  /// 语音本地url，通过downloadMessage下载消息后此字段有值
  String? localUrl;

  V2TimSoundElem({
    this.path,
    // ignore: non_constant_identifier_names
    this.UUID,
    this.dataSize,
    this.duration,
    this.url,
    this.localUrl,
  });

  V2TimSoundElem.fromJson(Map json) {
    json = Utils.formatJson(json);
    path = json['path'];
    UUID = json['UUID'];
    dataSize = json['dataSize'];
    duration = json['duration'];
    localUrl = json['localUrl'];
    url = json['url'];
    if (json['nextElem'] != null) {
      nextElem = Utils.formatJson(json['nextElem']);
    }
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['path'] = path;
    data['UUID'] = UUID;
    data['dataSize'] = dataSize;
    data['duration'] = duration;
    data['localUrl'] = localUrl;
    data['url'] = url;
    if (nextElem != null) {
      data['nextElem'] = nextElem;
    }
    return data;
  }
  String toLogString() {
    String res = "UUID:$UUID|duration:$duration|dataSize:$dataSize|localUrl:${localUrl == null ? false : true}";
    return res;
  }
}
// {
//   "path":"",
//   "UUID":"",
//   "dataSize":0,
//   "duration":0,
//   "url":""
// }
