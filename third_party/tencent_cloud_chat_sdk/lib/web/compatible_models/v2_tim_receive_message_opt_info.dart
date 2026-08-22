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
    c2CReceiveMessageOpt = jsonStr['c2CReceiveMessageOpt'];
    userID = jsonStr['userID'] ?? "";
    allReceiveMessageOpt = jsonStr['allReceiveMessageOpt'];
    duration = jsonStr['duration'];
    startHour = jsonStr['startHour'];
    startSecond = jsonStr['startSecond'];
    startTimeStamp = jsonStr['startTimeStamp'];
    startMinute = jsonStr['startMinute'];
  }
  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['c2CReceiveMessageOpt'] = c2CReceiveMessageOpt;
    data['userID'] = userID;
    data['allReceiveMessageOpt'] = allReceiveMessageOpt;
    data['duration'] = duration;
    data['startHour'] = startHour;
    data['startSecond'] = startSecond;
    data['startTimeStamp'] = startTimeStamp;
    data['startMinute'] = startMinute;
    return data;
  }
  String toLogString() {
    String res =
        "c2CReceiveMessageOpt:$c2CReceiveMessageOpt|userID:$userID|allReceiveMessageOpt:$allReceiveMessageOpt|duration:$duration|startHour:$startHour|startSecond:$startSecond|startTimeStamp:$startTimeStamp|startMinute:$startMinute";
    return res;
  }
}
