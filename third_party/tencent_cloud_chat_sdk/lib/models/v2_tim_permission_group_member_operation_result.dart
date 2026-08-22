class V2TimPermissionGroupMemberOperationResult {
  String memberID;
  int resultCode;
  V2TimPermissionGroupMemberOperationResult({
    required this.memberID,
    required this.resultCode,
  });

  Map<String, dynamic> toJson() {
    return Map<String, dynamic>.from({
      'permission_group_member_operation_result_identifier': memberID,
      'permission_group_member_operation_result_error_code': resultCode,
    });
  }

  static V2TimPermissionGroupMemberOperationResult fromJson(
      Map<String, dynamic> json) {
    return V2TimPermissionGroupMemberOperationResult(
      memberID: json['permission_group_member_operation_result_identifier'] ?? '',
      resultCode: json['permission_group_member_operation_result_error_code'] ?? 0,
    );
  }

  String toLogString() {
    String res = "memberID:$memberID|resultCode:$resultCode";
    return res;
  }
}
