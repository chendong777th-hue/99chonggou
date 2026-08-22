import 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_message_reaction.dart';
import 'package:tencent_cloud_chat_sdk/web/models/V2TimUserInfoWeb.dart';
import 'package:tencent_cloud_chat_sdk/web/utils/utils.dart';

class V2TimMessageReactionWeb {
  static V2TimMessageReaction fromJsObj(Map<String, dynamic> data) {
    return V2TimMessageReaction.fromJson({
      "reactionID": data["reactionID"] ?? "",
      "totalUserCount": data["totalUserCount"] ?? 0,
      "reactedByMyself": data["reactedByMyself"] ?? false,
      "partialUserList": V2TimUserInfoWeb.fromJsObjs(
              List<dynamic>.from(data["partialUserList"] ?? []))
          .map((e) => e.toJson())
          .toList(),
    });
  }

  static List<V2TimMessageReaction> fromJsObjs(List<dynamic> datas) {
    List<V2TimMessageReaction> res = [];

    for (var element in datas) {
      res.add(V2TimMessageReactionWeb.fromJsObj(jsToMap(element)));
    }
    return res;
  }
}
