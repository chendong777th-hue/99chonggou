/// V2TimOfflinePushConfig
///
/// {@category Models}
///
// ignore_for_file: non_constant_identifier_names

class V2TimOfflinePushConfig {
    late int businessID;
    late String token;
    late bool isTPNSToken;
    late bool isVoip;
    int _pushTokenType = 0;

  V2TimOfflinePushConfig({
    required this.businessID,
    required this.token,
    required this.isTPNSToken,
    required this.isVoip,
  }) {
    // 默认厂商 token, 例如 APNS/小米 push/Huawei push 等
    // TIMOfflinePushTokenType_Default = 0,
    // TPNS
    // TIMOfflinePushTokenType_TPNS = 1,
    // VoIP push
    // TIMOfflinePushTokenType_VOIP = 2,
    if (isTPNSToken) {
      _pushTokenType = 1;
    } else if (isVoip) {
      _pushTokenType = 2;
    } else {
      _pushTokenType = 0;
    }
  }


  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['offline_push_token_business_id'] = businessID;
    data['offline_push_token_token'] = token;
    data['offline_push_token_type'] = _pushTokenType;
    return data;
  }

  String toLogString() {
    String res = "businessID:$businessID|token:$token|isTPNSToken:$isTPNSToken|isVoip:$isVoip";
    return res;
  }
}

// {
//   "title":"",
//   "desc":"",
//   "disablePush":true
// }
