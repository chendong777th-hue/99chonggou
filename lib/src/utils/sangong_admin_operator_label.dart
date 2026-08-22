import 'package:tencent_cloud_chat_uikit/tencent_cloud_chat_uikit.dart';

/// 将昵称与 IM 用户 id 组合为操作人标识。
String formatSangongAdminOperatorLabel({
  required String userId,
  required String nickname,
}) {
  final id = userId.trim();
  final name = nickname.trim();
  if (name.isNotEmpty && id.isNotEmpty) {
    return '$name($id)';
  }
  if (name.isNotEmpty) {
    return name;
  }
  return id;
}

/// 解析当前登录管理员的操作人标识（昵称 + IM 用户 id）。
String resolveSangongAdminOperatorLabel() {
  final info = TIMUIKitCore.getInstance().loginUserInfo;
  return formatSangongAdminOperatorLabel(
    userId: info?.userID ?? '',
    nickname: info?.nickName ?? '',
  );
}
