import 'package:tencent_cloud_chat_sdk/utils/utils.dart';

/// V2TimGroupAtInfo
///
/// {@category Models}
///
class V2TimGroupAtInfo {
  static String AT_ALL_TAG = "__kImSDK_MesssageAtALL__";

  late String seq;
  late int atType;

  // @ 消息的类型：
  // @ 我
  static const int _groupAtMe = 1;
  // @ 群里所有人
  static const int _groupAtAll = 2;
  // @ 群里所有人并且单独 @ 我
  static const int _groupAtAllAtMe = 3;

  // C API 的 all_all 标记, 内部使用
  static String _c_at_all_tag = "__kImSDK_MessageAtALL__";
  static String get c_api_tag => _c_at_all_tag;

  V2TimGroupAtInfo({
    required this.seq,
    required this.atType,
  });

  V2TimGroupAtInfo.fromJson(Map json) {
    json = Utils.formatJson(json);
    seq = json['conv_group_at_info_seq']?.toString() ?? '';
    atType = json['conv_group_at_info_at_type'] ?? 0;
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['conv_group_at_info_seq'] = int.tryParse(seq);
    data['conv_group_at_info_at_type'] = atType;
    return data;
  }

  String toLogString() {
    String res = "seq:$seq|atType:$atType";
    return res;
  }
}

// {
//   "seq":0,
//   "atType":0
// }
