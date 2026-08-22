class V2TimPermissionGroupMemberOperationResult {
  String memberID;
  int resultCode;
  V2TimPermissionGroupMemberOperationResult({
    required this.memberID,
    required this.resultCode,
  });
  Map<String, dynamic> toJson() {
    return Map<String, dynamic>.from({
      'memberID': memberID,
      'resultCode': resultCode,
    });
  }

  static V2TimPermissionGroupMemberOperationResult fromJson(
      Map<String, dynamic> json) {
    return V2TimPermissionGroupMemberOperationResult(
      memberID: json['memberID'],
      resultCode: json['resultCode'],
    );
  }
  String toLogString() {
    String res = "memberID:$memberID|resultCode:$resultCode";
    return res;
  }
}
