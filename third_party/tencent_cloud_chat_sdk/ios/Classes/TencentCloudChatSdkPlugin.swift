import Flutter
import UIKit

public class TencentCloudChatSdkPlugin: NSObject, FlutterPlugin {
  public static var channels: [FlutterMethodChannel] = []
  
  public var channel: FlutterMethodChannel?

  var sdkManager: SDKManager?

  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "tencent_cloud_chat_sdk", binaryMessenger: registrar.messenger())
    let instance = TencentCloudChatSdkPlugin()
    registrar.addApplicationDelegate(instance)
    registrar.addMethodCallDelegate(instance, channel: channel)
    channels.append(channel)
    instance.sdkManager = SDKManager()
    instance.channel = channel

    registrar.publish(instance)
  }

  public func detachFromEngine(for registrar: FlutterPluginRegistrar) {
    guard channel != nil else { return }

    TencentCloudChatSdkPlugin.channels.removeAll(where: { $0 == channel })
    channel?.setMethodCallHandler(nil)
    channel = nil
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
      case "setAPNS":
        sdkManager!.setAPNS(call: call, result: result)
        break
      case "setVOIP":
        sdkManager!.setVOIP(call:call,result: result)
        break;
      case "setAPNSListener":
        sdkManager!.setAPNSListener(call: call, result: result)
        break
      case "doBackground":
        sdkManager!.doBackground(call: call, result: result)
        break
      case "doForeground":
        sdkManager!.doForeground(call: call, result: result)
        break
      default:
        break
    }
  }

  public static func invokeListener(type: UInt32, method: String, data: Any?, listenerUuid: String?) {
     DispatchQueue.main.async {
        var resultParams: [String: Any] = [:];
        resultParams["type"] = "\(type)";
        if data != nil {
            resultParams["data"] = data;
        }
        
        resultParams["listenerUuid"] = listenerUuid;
        
         for channel:FlutterMethodChannel in channels {
             channel.invokeMethod(method, arguments: resultParams);
         }
     }
  }
}
