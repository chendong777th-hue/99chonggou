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
    createTime = json['official_account_create_time'];
    customData = json['official_account_custom_data'];
    faceUrl = json['official_account_face_url'];
    officialAccountID = json['official_account_id'];
    introduction = json['official_account_introduction'];
    officialAccountName = json['official_account_name'];
    organization = json['official_account_organization'];
    ownerUserID = json['official_account_owner_user_id'];
    subscriberCount = json['official_account_subscriber_count'];
    subscribeTime = json['official_account_subscribe_time'];
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
