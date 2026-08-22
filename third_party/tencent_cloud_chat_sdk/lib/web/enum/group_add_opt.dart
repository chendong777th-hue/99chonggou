// ignore_for_file: non_constant_identifier_names
@JS()
library js_interop;

import 'package:js/js.dart'; // Pull in our dependency

import 'package:tencent_cloud_chat_sdk/enum/group_add_opt_type.dart';
import 'package:tencent_cloud_chat_sdk/web/utils/utils.dart';

@JS("TencentCloudChat")
class GroupAddOptEnum {
  external static dynamic TYPES; // 这个是用作枚举的
}

class GroupAddOptWeb {
  static String JOIN_OPTIONS_FREE_ACCESS =
      jsToMap(GroupAddOptEnum.TYPES)["JOIN_OPTIONS_FREE_ACCESS"];
  static String JOIN_OPTIONS_NEED_PERMISSION =
      jsToMap(GroupAddOptEnum.TYPES)["JOIN_OPTIONS_NEED_PERMISSION"];
  static String JOIN_OPTIONS_DISABLE_APPLY =
      jsToMap(GroupAddOptEnum.TYPES)["JOIN_OPTIONS_DISABLE_APPLY"];

  static int? convertGroupAddOpt(String opt) {
    if (opt == JOIN_OPTIONS_FREE_ACCESS) {
      return GroupAddOptType.V2TIM_GROUP_ADD_ANY;
    }

    if (opt == JOIN_OPTIONS_NEED_PERMISSION) {
      return GroupAddOptType.V2TIM_GROUP_ADD_AUTH;
    }

    if (opt == JOIN_OPTIONS_DISABLE_APPLY) {
      return GroupAddOptType.V2TIM_GROUP_ADD_FORBID;
    }
    return null;
  }

  static String? convertGroupAddOptToWeb(int? opt) {
    if (opt == GroupAddOptType.V2TIM_GROUP_ADD_ANY) {
      return JOIN_OPTIONS_FREE_ACCESS;
    }

    if (opt == GroupAddOptType.V2TIM_GROUP_ADD_AUTH) {
      return JOIN_OPTIONS_NEED_PERMISSION;
    }

    if (opt == GroupAddOptType.V2TIM_GROUP_ADD_FORBID) {
      return JOIN_OPTIONS_DISABLE_APPLY;
    }
    return null;
  }
}

class GroupInviteOptWeb {
  static String JOIN_OPTIONS_FREE_ACCESS =
      jsToMap(GroupAddOptEnum.TYPES)["JOIN_OPTIONS_FREE_ACCESS"];
  static String JOIN_OPTIONS_NEED_PERMISSION =
      jsToMap(GroupAddOptEnum.TYPES)["JOIN_OPTIONS_NEED_PERMISSION"];
  static String JOIN_OPTIONS_DISABLE_APPLY =
      jsToMap(GroupAddOptEnum.TYPES)["JOIN_OPTIONS_DISABLE_APPLY"];

  static int? convertGroupAddOpt(String opt) {
    if (opt == JOIN_OPTIONS_FREE_ACCESS) {
      return GroupAddOptType.V2TIM_GROUP_ADD_ANY;
    }

    if (opt == JOIN_OPTIONS_NEED_PERMISSION) {
      return GroupAddOptType.V2TIM_GROUP_ADD_AUTH;
    }

    if (opt == JOIN_OPTIONS_DISABLE_APPLY) {
      return GroupAddOptType.V2TIM_GROUP_ADD_FORBID;
    }
    return null;
  }

  static String? convertGroupAddOptToWeb(int? opt) {
    if (opt == GroupAddOptType.V2TIM_GROUP_ADD_ANY) {
      return JOIN_OPTIONS_FREE_ACCESS;
    }

    if (opt == GroupAddOptType.V2TIM_GROUP_ADD_AUTH) {
      return JOIN_OPTIONS_NEED_PERMISSION;
    }

    if (opt == GroupAddOptType.V2TIM_GROUP_ADD_FORBID) {
      return JOIN_OPTIONS_DISABLE_APPLY;
    }
    return null;
  }
}
