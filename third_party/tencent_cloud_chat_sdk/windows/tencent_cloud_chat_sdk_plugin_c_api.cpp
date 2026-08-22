#include "include/tencent_cloud_chat_sdk/tencent_cloud_chat_sdk_plugin_c_api.h"

#include <flutter/plugin_registrar_windows.h>

#include "tencent_cloud_chat_sdk_plugin.h"

void TencentCloudChatSdkPluginCApiRegisterWithRegistrar(FlutterDesktopPluginRegistrarRef registrar) {
    tencent_cloud_chat_sdk::TencentCloudChatSdkPlugin::RegisterWithRegistrar(
        flutter::PluginRegistrarManager::GetInstance()->GetRegistrar<flutter::PluginRegistrarWindows>(registrar));
}
