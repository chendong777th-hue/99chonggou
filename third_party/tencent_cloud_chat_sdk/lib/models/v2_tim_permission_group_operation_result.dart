class V2TimPermissionGroupOperationResult {
  int resultCode;
  String resultMessage;
  String permissionGroupID;
  V2TimPermissionGroupOperationResult({
    required this.resultCode,
    required this.resultMessage,
    required this.permissionGroupID,
  });
  Map<String, dynamic> toJson() {
    return Map<String, dynamic>.from({
      'resultCode': resultCode,
      'resultMessage': resultMessage,
      'permissionGroupID': permissionGroupID,
    });
  }

  static V2TimPermissionGroupOperationResult fromJson(
      Map<String, dynamic> json) {
    return V2TimPermissionGroupOperationResult(
      resultCode: json['resultCode'] ?? 0,
      resultMessage: json['resultMessage'] ?? "",
      permissionGroupID: json['permissionGroupID'] ?? "",
    );
  }
  String toLogString() {
    String res = "resultCode:$resultCode|resultMessage:$resultMessage|permissionGroupID:$permissionGroupID";
    return res;
  }
}
