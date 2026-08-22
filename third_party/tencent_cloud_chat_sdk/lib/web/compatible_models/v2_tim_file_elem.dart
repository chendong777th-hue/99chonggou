import 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_elem.dart';
import 'package:tencent_cloud_chat_sdk/utils/utils.dart';

/// V2TimFileElem
///
/// {@category Models}
///
class V2TimFileElem extends V2TIMElem {
  /// 文件本地路径，仅在发送消息成功之前有效，用作文件本地预览
  late String? path;

  /// 文件名
  late String? fileName;
  // ignore: non_constant_identifier_names
  late String? UUID;

  /// 文件url，默认不返回，通过getMessageOnlineUrl获取
  late String? url;

  /// 文件大小
  late int? fileSize;

  /// 文件本地路径，downloadMessage之后有值
  String? localUrl;

  V2TimFileElem({
    this.path,
    this.fileName,
    // ignore: non_constant_identifier_names
    this.UUID,
    this.url,
    this.fileSize,
    this.localUrl,
  });

  V2TimFileElem.fromJson(Map json) {
    json = Utils.formatJson(json);
    path = json['path'];
    fileName = json['fileName'];
    UUID = json['UUID'];
    url = json['url'];
    localUrl = json['localUrl'];
    fileSize = json['fileSize'];
    if (json['nextElem'] != null) {
      nextElem = Utils.formatJson(json['nextElem']);
    }
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['path'] = path;
    data['fileName'] = fileName;
    data['UUID'] = UUID;
    data['url'] = url;
    data['fileSize'] = fileSize;
    data['localUrl'] = localUrl;
    if (nextElem != null) {
      data['nextElem'] = nextElem;
    }
    return data;
  }
  String toLogString() {
    String res = "path:${path == null ? false : true}|fileName:$fileName|UUID:$UUID|fileSize:$fileSize|localUrl:${localUrl == null ? false : true}";
    return res;
  }
}
// {
//   "path":"",
//   "fileName":"",
//   "UUID":"",
//   "url":"",
//   "fileSize": 0
// }
