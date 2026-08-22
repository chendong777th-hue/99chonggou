import {
  FlutterPlugin,
  FlutterPluginBinding,
  MethodCall,
  MethodCallHandler,
  MethodChannel,
  MethodResult,
} from '@ohos/flutter_ohos';

import {
  V2TIMManager,
} from '@tencentcloud/imsdk';

import NetworkCenter from "./NetworkCenter";

/** TencentCloudChatSdkPlugin **/
export default class TencentCloudChatSdkPlugin implements FlutterPlugin, MethodCallHandler {
  private channel: MethodChannel | null = null;

  constructor() {
  }

  getUniqueClassName(): string {
    return "TencentCloudChatSdkPlugin"
  }

  onAttachedToEngine(binding: FlutterPluginBinding): void {
    this.channel = new MethodChannel(binding.getBinaryMessenger(), "tencent_cloud_chat_sdk");
    this.channel.setMethodCallHandler(this);

    // 鸿蒙的 http 请求需要初始化 native 的 JsObjectFactory 才能使用
    V2TIMManager.getInstance().callExperimentalAPI("initObjectFactory", binding.getApplicationContext());
    // C 接口的 initSDK 需要 ohos 系统侧的网络信息，以及网络变化需要通知 native
    NetworkCenter.getInstance().init();
  }

  onDetachedFromEngine(binding: FlutterPluginBinding): void {
    if (this.channel != null) {
      this.channel.setMethodCallHandler(null)
    }
  }

  onMethodCall(call: MethodCall, result: MethodResult): void {
    if (call.method == "getPlatformVersion") {
      result.success("OpenHarmony ^ ^ ")
    } else if (call.method == "getNetworkInfo") {
      let networkInfo = NetworkCenter.getInstance().getNetworkInfo();

      let networkInfoMap: Map<string, number | string | boolean> = new Map<string, number | string | boolean>();
      networkInfoMap.set("networkType", Number(networkInfo.network_type));
      networkInfoMap.set("ipType", Number(networkInfo.ip_type));
      networkInfoMap.set("networkId", networkInfo.network_id);
      networkInfoMap.set("wifiNetworkHandle", networkInfo.wifi_network_interface.network_handle);
      networkInfoMap.set("xgNetworkHandle", networkInfo.xg_network_interface.network_handle);
      networkInfoMap.set("initializeCostTime", networkInfo.initialize_cost_time);
      networkInfoMap.set("networkConnected", Number(networkInfo.network_status) == 2);

      result.success(networkInfoMap);
    } else {
      result.notImplemented()
    }
  }
}