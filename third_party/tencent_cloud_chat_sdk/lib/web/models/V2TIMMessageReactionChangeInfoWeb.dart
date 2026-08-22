import 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_message_reaction_change_info.dart';
import 'package:tencent_cloud_chat_sdk/web/models/V2TimUserInfoWeb.dart';
import 'package:tencent_cloud_chat_sdk/web/utils/utils.dart';

class V2TIMMessageReactionChangeInfoWeb {
  static V2TIMMessageReactionChangeInfo fromJsObj(Map<String, dynamic> data) {
    return V2TIMMessageReactionChangeInfo.fromJson({
      "reactionID": data["reactionID"] ?? "",
      "totalUserCount": data["totalUserCount"] ?? 0,
      "reactedByMyself": data["reactedByMyself"] ?? false,
      "partialUserList": V2TimUserInfoWeb.fromJsObjs(
              List<dynamic>.from(data["partialUserList"] ?? []))
          .map((e) => e.toJson())
          .toList(),
    });
  }

  static List<V2TIMMessageReactionChangeInfo> fromJsObjs(List<dynamic> datas) {
    List<V2TIMMessageReactionChangeInfo> res = [];

    for (var element in datas) {
      res.add(V2TIMMessageReactionChangeInfoWeb.fromJsObj(jsToMap(element)));
    }
    return res;
  }
}
