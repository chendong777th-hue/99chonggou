import 'package:flutter/widgets.dart';
import 'package:tencent_cloud_chat_sdk/manager/v2_tim_manager.dart';

typedef TencentCloudChatPluginTapFn = bool Function(Map<String, String> data);

class TencentImSDKPlugin {
  static V2TIMManager? manager;

  static V2TIMManager managerInstance() {
    manager ??= V2TIMManager();
    return manager!;
  }

  static V2TIMManager v2TIMManager = V2TIMManager();
}

abstract class TencentCloudChatPlugin {
  String name = "";
  String version = "";
  String description = "";
  String author = "";

  Future<Map<String, dynamic>> init(String? data);
  Future<Map<String, dynamic>> unInit(String? data);
  TencentCloudChatPlugin getInstance();
  Future<Map<String, dynamic>> callMethod({
    required String methodName,
    String? data,
  });
  Future<Widget?> getWidget({
    required String methodName,
    Map<String, String>? data,
    Map<String, TencentCloudChatPluginTapFn>? fns,
  });
  Map<String, dynamic> callMethodSync({
    required String methodName,
    String? data,
  });
  Widget? getWidgetSync({
    required String methodName,
    Map<String, String>? data,
    Map<String, TencentCloudChatPluginTapFn>? fns,
  });
}
