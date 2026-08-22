import 'dart:convert';

import 'package:tencent_cloud_chat_sdk/utils/utils.dart';
import 'v2_tim_group_member_full_info.dart';

/// V2TimGroupMemberInfoResult
///
/// {@category Models}
///

class V2TimGroupMemberInfoResult {
  late String? nextSeq;
  List<V2TimGroupMemberFullInfo>? memberInfoList = List.empty(growable: true);

  V2TimGroupMemberInfoResult({
    this.nextSeq,
    this.memberInfoList,
  });

  V2TimGroupMemberInfoResult.fromJson(Map json, {String? rawJsonParam}) {
    json = Utils.formatJson(json);
    // nextSeq 是 uint64_t 类型，可能超出 double 精度范围，优先从原始 JSON 字符串中提取精确值
    nextSeq = _extractNextSeqFromRawJson(rawJsonParam) ?? json['group_get_member_info_list_result_next_seq']?.toString();
    if (json['group_get_member_info_list_result_info_array'] != null) {
      memberInfoList = List.empty(growable: true);
      json['group_get_member_info_list_result_info_array'].forEach((v) {
        memberInfoList!.add(V2TimGroupMemberFullInfo.fromJson(v));
      });
    }
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['group_get_member_info_list_result_next_seq'] = nextSeq;
    if (memberInfoList != null) {
      data['group_get_member_info_list_result_info_array'] = memberInfoList?.map((v) => v?.toJson()).toList();
    }
    return data;
  }

  /// 从原始 JSON 字符串中用正则提取 group_get_member_info_list_result_next_seq 的精确数值字符串，
  /// 避免 json.decode 将超出 int64 范围的 uint64 数字转为 double 导致精度丢失。
  static String? _extractNextSeqFromRawJson(String? rawJson) {
    if (rawJson == null || rawJson.isEmpty) return null;
    final match = RegExp(r'"group_get_member_info_list_result_next_seq"\s*:\s*(\d+)').firstMatch(rawJson);
    return match?.group(1);
  }

  String toLogString() {
    String res = "nextSeq:$nextSeq|memberInfoList:${json.encode(memberInfoList?.map((e) => e?.toLogString()).toList())}";
    return res;
  }
}
// {
//   "nextSeq":0,
//   "memberInfoList":[{}]
// }
