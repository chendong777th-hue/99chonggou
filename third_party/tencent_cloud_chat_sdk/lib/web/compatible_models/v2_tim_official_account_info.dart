import 'package:tencent_cloud_chat_sdk/utils/utils.dart';

class V2TimOfficialAccountInfo {
  int? createTime;
  String? customData;
  String? faceUrl;
  String? officialAccountID;
  String? introduction;
  String? officialAccountName;
  String? organization;
  String? ownerUserID;
  int? subscriberCount;
  int? subscribeTime;

  V2TimOfficialAccountInfo({
    this.createTime,
    this.customData,
    this.faceUrl,
    this.officialAccountID,
    this.introduction,
    this.officialAccountName,
    this.organization,
    this.ownerUserID,
    this.subscriberCount,
    this.subscribeTime,
  });

  V2TimOfficialAccountInfo.fromJson(Map json) {
    json = Utils.formatJson(json);
    createTime = json['createTime'];
    customData = json['customData'];
    faceUrl = json['faceUrl'];
    officialAccountID = json['officialAccountID'];
    introduction = json['introduction'];
    officialAccountName = json['officialAccountName'];
    organization = json['organization'];
    ownerUserID = json['ownerUserID'];
    subscriberCount = json['subscriberCount'];
    subscribeTime = json['subscribeTime'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['createTime'] = createTime;
    data['customData'] = customData;
    data['faceUrl'] = faceUrl;
    data['officialAccountID'] = officialAccountID;
    data['introduction'] = introduction;
    data['officialAccountName'] = officialAccountName;
    data['organization'] = organization;
    data['ownerUserID'] = ownerUserID;
    data['subscriberCount'] = subscriberCount;
    data['subscribeTime'] = subscribeTime;
    return data;
  }
  String toLogString() {
    String res = "createTime:$createTime|officialAccountID:$officialAccountID|ownerUserID:$ownerUserID|subscriberCount:$subscriberCount|subscribeTime:$subscribeTime";
    return res;
  }
}
