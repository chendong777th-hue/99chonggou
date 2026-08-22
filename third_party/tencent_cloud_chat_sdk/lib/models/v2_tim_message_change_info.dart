import 'package:tencent_cloud_chat_sdk/models/v2_tim_message.dart';
import 'package:tencent_cloud_chat_sdk/utils/utils.dart';

/// V2TimMessageChangeInfo
///
/// {@category Models}
///
class V2TimMessageChangeInfo {
  int? code;
  String? desc;
  V2TimMessage? message;

  V2TimMessageChangeInfo({
    this.code,
    this.desc,
    this.message,
  });

  V2TimMessageChangeInfo.fromJson(Map json) {
    json = Utils.formatJson(json);
    code = json["code"];
    desc = json["desc"];
    if (json["message"] != null) {
      message = V2TimMessage.fromJson(json["message"]);
    }
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data["code"] = code;
    data["desc"] = desc;
    if (message != null) {
      data["message"] = message?.toJson();
    }
    return data;
  }
  String toLogString() {
    String res = "code:$code|desc:$desc|message:${message?.toLogString()}";
    return res;
  }
}
