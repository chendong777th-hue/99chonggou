import 'package:tencent_cloud_chat_sdk/utils/utils.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_permission_group_info.dart';

class V2TimPermissionGroupInfoModifyParam {
  V2TimPermissionGroupInfo info;
  late int modifyFlag;

  // 修改权限组信息的类型
  // 未定义
  static const int kTIMPermissionGroupModifyInfoFlag_None = 0x00;
  // 名称
  static const int kTIMPermissionGroupModifyInfoFlag_Name = 0x01;
  // 群权限
  static const int kTIMPermissionGroupModifyInfoFlag_GroupPermission = 0x01 << 1;
  // 自定义字段
  static const int kTIMPermissionGroupModifyInfoFlag_CustomData = 0x01 << 2;


  V2TimPermissionGroupInfoModifyParam({
    required this.info,
  }) {
    modifyFlag = kTIMPermissionGroupModifyInfoFlag_Name | kTIMPermissionGroupModifyInfoFlag_GroupPermission |
                 kTIMPermissionGroupModifyInfoFlag_CustomData;
  }

  V2TimPermissionGroupInfoModifyParam.fromJson(Map json): info = V2TimPermissionGroupInfo.fromJson(json) {
    json = Utils.formatJson(json);
    modifyFlag = json['permission_group_modify_info_flag'] ?? 0;
  }

  Map<String, dynamic> toJson() {
    Map<String, dynamic> data = info.toJson();
    data['permission_group_modify_info_flag'] = modifyFlag;

    return data;
  }

  String toLogString() {
    String res = "info: ${info.toLogString()}|modifyFlag: $modifyFlag";
    return res;
  }
}
