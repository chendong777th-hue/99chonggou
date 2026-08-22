import 'package:tencent_cloud_chat_sdk/utils/utils.dart';

class V2TimReceiveMessageOptInfo {
  late int? c2CReceiveMessageOpt;
  late String userID;
  int? allReceiveMessageOpt;
  int? duration;
  int? startHour;
  int? startSecond;
  int? startTimeStamp;
  int? startMinute;

  V2TimReceiveMessageOptInfo({
    this.c2CReceiveMessageOpt,
    required this.userID,
    this.allReceiveMessageOpt,
    this.duration,
    this.startHour,
    this.startMinute,
    this.startSecond,
    this.startTimeStamp,
  });

  V2TimReceiveMessageOptInfo.fromJson(Map jsonStr) {
    jsonStr = Utils.formatJson(jsonStr);
    c2CReceiveMessageOpt = jsonStr['msg_recv_msg_opt_result_opt'];
    userID = jsonStr['msg_recv_msg_opt_result_identifier'] ?? "";
    allReceiveMessageOpt = jsonStr['msg_all_recv_msg_opt_level'];
    duration = jsonStr['msg_all_recv_msg_duration'];
    startHour = jsonStr['msg_all_recv_msg_opt_start_hour'];
    startSecond = jsonStr['msg_all_recv_msg_opt_start_second'];
    startTimeStamp = jsonStr['msg_all_recv_msg_opt_start_time_stamp'];
    startMinute = jsonStr['msg_all_recv_msg_opt_start_minute'];
  }
  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['msg_recv_msg_opt_result_opt'] = c2CReceiveMessageOpt;
    data['msg_recv_msg_opt_result_identifier'] = userID;
    data['msg_all_recv_msg_opt_level'] = allReceiveMessageOpt;
    data['msg_all_recv_msg_duration'] = duration;
    data['msg_all_recv_msg_opt_start_hour'] = startHour;
    data['msg_all_recv_msg_opt_start_second'] = startSecond;
    data['msg_all_recv_msg_opt_start_time_stamp'] = startTimeStamp;
    data['msg_all_recv_msg_opt_start_minute'] = startMinute;
    return data;
  }
  String toLogString() {
    String res =
        "c2CReceiveMessageOpt:$c2CReceiveMessageOpt|userID:$userID|allReceiveMessageOpt:$allReceiveMessageOpt|duration:$duration|startHour:$startHour|startSecond:$startSecond|startTimeStamp:$startTimeStamp|startMinute:$startMinute";
    return res;
  }
}
