import 'package:tencent_cloud_chat_sdk/utils/utils.dart';
import 'v2_tim_group_application.dart';

/// V2TimGroupHandleApplicationParam
///
/// {@category Models}
///
class V2TimGroupHandleApplicationParam {
  late bool isAccept;
  String? reason;
  late V2TimGroupApplication application;

  V2TimGroupHandleApplicationParam({required this.isAccept, this.reason, required this.application});

  V2TimGroupHandleApplicationParam.fromJson(Map json) {
    json = Utils.formatJson(json);
    isAccept = json['group_handle_pendency_param_is_accept'] ?? false;
    reason = json['group_handle_pendency_param_handle_msg'];
    application = V2TimGroupApplication.fromJson(json['group_handle_pendency_param_pendency'] ?? {});
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['group_handle_pendency_param_is_accept'] = isAccept;
    data['group_handle_pendency_param_handle_msg'] = reason;
    data['group_handle_pendency_param_pendency'] = application.toJson();
    return data;
  }

  String toLogString() {
    String res = "isAccept: $isAccept|reason: $reason|application: $application";
    return res;
  }
}