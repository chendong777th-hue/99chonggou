#include "tencent_cloud_chat_sdk_plugin.h"

// For getPlatformVersion; remove unless needed for your plugin implementation.
#include <VersionHelpers.h>
#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/standard_method_codec.h>

namespace tencent_cloud_chat_sdk {

void TencentCloudChatSdkPlugin::RegisterWithRegistrar(flutter::PluginRegistrarWindows *registrar) {}

TencentCloudChatSdkPlugin::TencentCloudChatSdkPlugin() {}

TencentCloudChatSdkPlugin::~TencentCloudChatSdkPlugin() {}

void TencentCloudChatSdkPlugin::HandleMethodCall(
    const flutter::MethodCall<flutter::EncodableValue> &method_call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {}
}  // namespace tencent_cloud_chat_sdk
