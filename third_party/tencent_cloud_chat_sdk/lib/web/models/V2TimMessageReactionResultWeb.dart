import 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_message_reaction_result.dart';
import 'package:tencent_cloud_chat_sdk/web/models/V2TimMessageReactionWeb.dart';
import 'package:tencent_cloud_chat_sdk/web/utils/utils.dart';

class V2TimMessageReactionResultWeb {
  static V2TimMessageReactionResult fromJsObj(Map<String, dynamic> data) {
    return V2TimMessageReactionResult.fromJson({
      "messageID": data["messageID"] ?? "",
      "resultCode": 0,
      "resultInfo": "",
      "reactionList": V2TimMessageReactionWeb.fromJsObjs(
              List<dynamic>.from(data["reactionList"] ?? []))
          .map((e) => e.toJson())
          .toList(),
    });
  }

  static List<V2TimMessageReactionResult> fromJsObjs(List<dynamic> datas) {
    List<V2TimMessageReactionResult> res = [];

    for (var element in datas) {
      res.add(V2TimMessageReactionResultWeb.fromJsObj(jsToMap(element)));
    }
    return res;
  }
}
