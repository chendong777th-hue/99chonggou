#ifndef FLUTTER_PLUGIN_TENCENT_CLOUD_CHAT_SDK_PLUGIN_H_
#define FLUTTER_PLUGIN_TENCENT_CLOUD_CHAT_SDK_PLUGIN_H_

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>

#include <memory>

namespace tencent_cloud_chat_sdk {

class TencentCloudChatSdkPlugin : public flutter::Plugin {
public:
    static void RegisterWithRegistrar(flutter::PluginRegistrarWindows *registrar);

    TencentCloudChatSdkPlugin();

    virtual ~TencentCloudChatSdkPlugin();

    // Disallow copy and assign.
    TencentCloudChatSdkPlugin(const TencentCloudChatSdkPlugin &) = delete;
    TencentCloudChatSdkPlugin &operator=(const TencentCloudChatSdkPlugin &) = delete;

    // Called when a method is called on this plugin's channel from Dart.
    void HandleMethodCall(const flutter::MethodCall<flutter::EncodableValue> &method_call,
                          std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
};

}  // namespace tencent_cloud_chat_sdk

#endif  // FLUTTER_PLUGIN_TENCENT_CLOUD_CHAT_SDK_PLUGIN_H_
