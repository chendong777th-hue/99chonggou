import 'package:tencent_cloud_chat_sdk/enum/user_info_allow_type.dart';
import 'package:tencent_cloud_chat_sdk/native_im/adapter/tim_c_enum.dart';
import 'package:tencent_cloud_chat_sdk/native_im/tools.dart';
import 'package:tencent_cloud_chat_sdk/utils/utils.dart';

/// V2TimUserFullInfo
///
/// {@category Models}
///
class V2TimUserFullInfo {
  String? userID;
  String? nickName;
  String? faceUrl;
  String? selfSignature;
  int? gender;
  int? allowType;
  Map<String, String>? customInfo;
  int? role;
  int? level;
  int? birthday;

  V2TimUserFullInfo({
    this.userID,
    this.nickName,
    this.faceUrl,
    this.selfSignature,
    this.gender,
    this.allowType,
    this.customInfo,
    this.role,
    this.level,
    this.birthday,
  });

  V2TimUserFullInfo.fromJson(Map json) {
    json = Utils.formatJson(json);
    userID = json['user_profile_identifier'] ?? "";
    nickName = json['user_profile_nick_name'];
    faceUrl = json['user_profile_face_url'];
    selfSignature = json['user_profile_self_signature'];
    gender = json['user_profile_gender'];
    int? addPermission = json['user_profile_add_permission'];
    allowType = AllowType.V2TIM_FRIEND_ALLOW_ANY;
    if (addPermission != null) {
      switch (addPermission) {
        case CFriendAddPermission.AllowAny:
          allowType = AllowType.V2TIM_FRIEND_ALLOW_ANY;
          break;
        case CFriendAddPermission.NeedConfirm:
          allowType = AllowType.V2TIM_FRIEND_NEED_CONFIRM;
          break;
        case CFriendAddPermission.DenyAny:
          allowType = AllowType.V2TIM_FRIEND_DENY_ANY;
          break;
        default:
          allowType = AllowType.V2TIM_FRIEND_ALLOW_ANY;
          break;
      }
    }
    var customInfoList = List<Map<String, dynamic>>.from(json['user_profile_custom_string_array'] ?? []);
    // C 接口在获取时没有去掉 "Tag_Profile_Custom_" 前缀。
    customInfoList = customInfoList.map((item) {
      final key = item['user_profile_custom_string_info_key'] as String?;
      if (key != null && key.startsWith('Tag_Profile_Custom_')) {
        return {
          'user_profile_custom_string_info_key': key.replaceFirst('Tag_Profile_Custom_', ''),
          'user_profile_custom_string_info_value': item['user_profile_custom_string_info_value']
        };
      }
      return item;
    }).toList();
    customInfo = Tools.jsonList2Map<String>(
        customInfoList, 'user_profile_custom_string_info_key', 'user_profile_custom_string_info_value');

    role = json['user_profile_role'];
    level = json['user_profile_level'];
    birthday = json['user_profile_birthday'];
  }

  int _convert2CFriendAddPermission(int allowType) {
    switch (allowType) {
      case AllowType.V2TIM_FRIEND_ALLOW_ANY:
        return CFriendAddPermission.AllowAny;
      case AllowType.V2TIM_FRIEND_NEED_CONFIRM:
        return CFriendAddPermission.NeedConfirm;
      case AllowType.V2TIM_FRIEND_DENY_ANY:
        return CFriendAddPermission.DenyAny;
      default:
        return CFriendAddPermission.AllowAny;
    }
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['user_profile_identifier'] = userID;
    data['user_profile_nick_name'] = nickName;
    data['user_profile_face_url'] = faceUrl;
    data['user_profile_self_signature'] = selfSignature;
    data['user_profile_gender'] = gender;
    data['user_profile_add_permission'] = _convert2CFriendAddPermission(allowType ?? AllowType.V2TIM_FRIEND_ALLOW_ANY);
    // C 接口已处理有无 "Tag_Profile_Custom_" 前缀的情况，此处不用处理。
    if (customInfo != null && customInfo!.isNotEmpty) {
      List<Map<String, dynamic>> customInfoList = Tools.map2JsonList(
          customInfo!, 'user_profile_custom_string_info_key', 'user_profile_custom_string_info_value');
      data['user_profile_custom_string_array'] = customInfoList;
    }
    data['user_profile_role'] = role;
    data['user_profile_level'] = level;
    data['user_profile_birthday'] = birthday;
    return data;
  }

  Map<String, dynamic> toSetUserInfoParam() {
    final Map<String, dynamic> data = <String, dynamic>{};
    if (nickName != null) {
      data['user_profile_item_nick_name'] = nickName;
    }
    if (gender != null) {
      data['user_profile_item_gender'] = gender;
    }
    if (faceUrl != null) {
      data['user_profile_item_face_url'] = faceUrl;
    }
    if (selfSignature != null) {
      data['user_profile_item_self_signature'] = selfSignature;
    }
    if (allowType != null) {
      data['user_profile_item_add_permission'] = _convert2CFriendAddPermission(allowType!);
    }
    // data['user_profile_item_language'] =
    if (birthday != null) {
      data['user_profile_item_birthday'] = birthday;
    }
    if (level != null) {
      data['user_profile_item_level'] = level;
    }
    if (role != null) {
      data['user_profile_item_role'] = role;
    }
    if (customInfo != null && customInfo!.isNotEmpty) {
      List<Map<String, dynamic>> customInfoList = Tools.map2JsonList(
          customInfo!, 'user_profile_custom_string_info_key', 'user_profile_custom_string_info_value');
      data['user_profile_item_custom_string_array'] = customInfoList;
    }

    return data;
  }

  toLogString() {
    String res =
        "userID:$userID|nickName:$nickName|faceUrl:$faceUrl|selfSignature:$selfSignature|gender:$gender|allowType:$allowType|role:$role|level:$level|birthday:$birthday|customInfo:$customInfo";
    return res;
  }
}
// {
//   "userID":"",
//   "nickName":"",
//   "faceUrl":"",
//   "selfSignature":"",
//   "gender":0,
//   "allowType":0,
//   "customInfo":{"test":""},
//   "role":0,
//   "level":0
// }
