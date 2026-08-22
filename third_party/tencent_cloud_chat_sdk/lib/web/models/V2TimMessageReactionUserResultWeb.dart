import 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_message_reaction_user_result.dart';
import 'package:tencent_cloud_chat_sdk/web/models/V2TimUserInfoWeb.dart';

class V2TimMessageReactionUserResultWeb {
  static V2TimMessageReactionUserResult fromJsObj(Map<String, dynamic> data) {
    return V2TimMessageReactionUserResult.fromJson({
      "nextSeq": data["nextSeq"] ?? 0,
      "isFinished": data["isCompleted"] ?? true,
      "userInfoList": V2TimUserInfoWeb.fromJsObjs(
              List<dynamic>.from(data["userList"] ?? []))
          .map((e) => e.toJson())
          .toList(),
    });
  }
}
