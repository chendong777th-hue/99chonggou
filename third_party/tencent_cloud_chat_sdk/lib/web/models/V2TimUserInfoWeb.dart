import 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_user_info.dart';
import 'package:tencent_cloud_chat_sdk/web/utils/utils.dart';

class V2TimUserInfoWeb {
  static V2TimUserInfo fromJsObj(Map<String, dynamic> data) {
    return V2TimUserInfo.fromJson({
      "faceUrl": data["avatar"] ?? "",
      "nickName": data["nick"] ?? 0,
      "userID": data["userID"] ?? false,
    });
  }

  static List<V2TimUserInfo> fromJsObjs(List<dynamic> datas) {
    List<V2TimUserInfo> res = [];

    for (var element in datas) {
      var da = V2TimUserInfoWeb.fromJsObj(jsToMap(element));
      res.add(da);
    }
    return res;
  }
}
