import 'package:tencent_cloud_chat_sdk/models/v2_tim_group_member_operation_result.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_group_member_operation_result.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_value_callback.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_value_callback.dart';

typedef SelfHostedGroupInviteHandler = Future<
    V2TimValueCallback<List<V2TimGroupMemberOperationResult>>> Function({
  required String groupID,
  required String? groupType,
  required List<String> userList,
});

typedef SelfHostedGroupInviteResultMessageBuilder = String Function({
  required int code,
  String? desc,
});

typedef SelfHostedGroupInviteSuccessMessageBuilder = String Function();

/// 99chat 自建后端代理 Public/Meeting/Community 邀请入群。
class SelfHostedGroupInviteBridge {
  SelfHostedGroupInviteBridge._();

  static SelfHostedGroupInviteHandler? _inviteHandler;
  static SelfHostedGroupInviteResultMessageBuilder? _inviteResultMessageBuilder;
  static SelfHostedGroupInviteSuccessMessageBuilder? _inviteSuccessMessageBuilder;

  static bool get enabled => _inviteHandler != null;

  static void configure({
    SelfHostedGroupInviteHandler? inviteHandler,
    SelfHostedGroupInviteResultMessageBuilder? inviteResultMessageBuilder,
    SelfHostedGroupInviteSuccessMessageBuilder? inviteSuccessMessageBuilder,
  }) {
    _inviteHandler = inviteHandler;
    _inviteResultMessageBuilder = inviteResultMessageBuilder;
    _inviteSuccessMessageBuilder = inviteSuccessMessageBuilder;
  }

  static void clear() {
    _inviteHandler = null;
    _inviteResultMessageBuilder = null;
    _inviteSuccessMessageBuilder = null;
  }

  static String formatInviteResultMessage({
    required int code,
    String? desc,
  }) {
    final builder = _inviteResultMessageBuilder;
    if (builder != null) {
      return builder(code: code, desc: desc);
    }
    if (desc?.trim().isNotEmpty == true) {
      return desc!.trim();
    }
    return 'Failed to add group members';
  }

  static String formatInviteSuccessMessage() {
    return _inviteSuccessMessageBuilder?.call() ?? 'Group members added';
  }

  static Future<V2TimValueCallback<List<V2TimGroupMemberOperationResult>>?>
      tryInvite({
    required String groupID,
    required String? groupType,
    required List<String> userList,
  }) async {
    final handler = _inviteHandler;
    if (handler == null) {
      return null;
    }
    return handler(
      groupID: groupID,
      groupType: groupType,
      userList: userList,
    );
  }
}
