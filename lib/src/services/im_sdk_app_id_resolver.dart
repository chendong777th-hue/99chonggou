import 'package:tencent_cloud_chat_demo/config.dart';

/// 解析 IM SDK 初始化用的 sdkAppId。
///
/// 优先级：显式传入（后端 UserSig）> 本地缓存 > [IMDemoConfig.sdkAppID] 兜底
///（仅首次安装、尚未拿到后端 AppID 时用于进登录页前的冷启）。
int resolveImSdkAppId({
  int? preferred,
  int? cached,
  int fallback = IMDemoConfig.sdkAppID,
}) {
  if (preferred != null && preferred > 0) {
    return preferred;
  }
  if (cached != null && cached > 0) {
    return cached;
  }
  return fallback;
}
