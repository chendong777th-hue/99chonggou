import 'package:tencent_cloud_chat_sdk/utils/utils.dart';

/// V2TimCallback
///
/// {@category Models}
///
class V2TimCallback {
  late int code;
  late String desc;

  V2TimCallback({
    required this.code,
    required this.desc,
  });

  V2TimCallback.fromJson(Map json) {
    json = Utils.formatJson(json);
    code = json['code'];
    desc = json['desc'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['code'] = code;
    data['desc'] = desc;
    return data;
  }

  V2TimCallback.fromBool(bool isSuccess, String desc)  {
    code = isSuccess ? 0 : 1;
    desc = desc;
  }

  String toLogString() {
    String res = "code:$code|desc:$desc";
    return res;
  }
}
// {
//   code:0,
//   desc:''
// }
