import connection from "@ohos.net.connection";

import native from "libImSDK.so";

// IP 协议类型
export enum IPType {
  IP_TYPE_UNKNOWN = 0,
  IP_TYPE_IPV4_ONLY = 1,
  IP_TYPE_IPV6_ONLY = 2,
  IP_TYPE_IPV6_MIX = 3,
}

// 网络类型
export enum NetworkType {
  // 未知
  NETWORK_UNKNOWN = 0,
  // WIFI
  NETWORK_WIFI = 1,
  // 2G
  NETWORK_2G3G = 2,
  NETWORK_GPRS = 101,
  NETWORK_EDGE = 102,
  NETWORK_CDMA = 104,
  NETWORK_1xRTT = 107,
  NETWORK_IDEN = 111,
  // 3G
  NETWORK_CDMA1X = 98,
  NETWORK_WCDMA = 99,
  NETWORK_UMTS = 103,
  NETWORK_EVDO_0 = 105,
  NETWORK_EVDO_A = 106,
  NETWORK_HSDPA = 108,
  NETWORK_HSUPA = 109,
  NETWORK_HSPA = 110,
  NETWORK_EVDO_B = 112,
  NETWORK_EHRPD = 114,
  NETWORK_HSPAP = 115,
  // 4G
  NETWORK_LTE = 113,
  // 5G
  NETWORK_NRNSA = 120,
  NETWORK_NR = 121,
  // 有线网络
  NETWORK_WIRE = 200,
}

// 连接状态
export enum NetworkStatus {
  // 网络断开
  Disconnected = 0,
  // 网络正在连接中
  Connecting = 1,
  // 网络连接成功
  Connected = 2,
}

export class NetworkInterface {
  // 仅对 Android 手机生效
  network_handle: number;
  // 仅对 IOS 手机生效
  network_interface_name: string;
}

// 网络信息
export class NetworkInfo {
  // IP 协议类型
  ip_type: IPType;
  // 网络类型
  network_type: NetworkType;
  // 网络标识，区分不同的WIFI和 运营商
  network_id: string;
  // WIFI 的网卡接口信息
  wifi_network_interface: NetworkInterface;
  // XG 的网卡接口信息
  xg_network_interface: NetworkInterface;
  // 网络状态
  network_status: NetworkStatus;
  // 获取网络信息的耗时，单位 ms
  initialize_cost_time: number;
}

export class NetworkCenter {
  private static _instance = new NetworkCenter();

  private _ipType = 0; // TODO
  private _networkType = 0; // TODO
  private _networkId = connection.getDefaultNetSync().netId.toString();
  private _wifiNetworkHandle = 0;
  private _xgNetworkHandle = 0;
  private _networkStatus = NetworkStatus.Connected;
  private _initializeCostTime = 0; // TODO

  private _netConnection = connection.createNetConnection();

  private constructor() {}

  static getInstance(): NetworkCenter {
    return this._instance;
  }

  init() {
    this._netConnection.register((error) => {
      if (error) {
        console.error(`TIM: |-flutter NetworkCenter register ${JSON.stringify(error)}`);
      }
    });

    // 网络可用
    this._netConnection.on("netAvailable", (netHandle: connection.NetHandle) => {
      this._networkId = netHandle.netId.toString();
      if (this._networkStatus != NetworkStatus.Connected) {
        this._networkStatus = NetworkStatus.Connected;
        native.notifySystemNetworkChange({ networkInfo: this.getNetworkInfo() });
      }
    });

    // 网络阻塞状态
    this._netConnection.on("netBlockStatusChange", (param: { netHandle: connection.NetHandle; blocked: boolean }) => {
      return; // TODO

      let { netHandle, blocked } = param;
      native.notifySystemNetworkChange({ networkInfo: this.getNetworkInfo() });
    });

    // 网络能力变化
    this._netConnection.on("netCapabilitiesChange", (param: { netHandle: connection.NetHandle; netCap: connection.NetCapabilities }) => {
      return; // TODO

      let { netHandle, netCap } = param;
      this._networkId = netHandle.netId.toString();
      netCap.bearerTypes.forEach((netBearType: connection.NetBearType) => {
        switch (netBearType) {
          case connection.NetBearType.BEARER_WIFI:
            this._networkType = NetworkType.NETWORK_WIFI;
            break;
          case connection.NetBearType.BEARER_CELLULAR:
            this._networkType = NetworkType.NETWORK_LTE; // TODO
            break;
          case connection.NetBearType.BEARER_ETHERNET:
            this._networkType = NetworkType.NETWORK_WIRE;
            break;
          default:
            this._networkType = NetworkType.NETWORK_UNKNOWN;
            break;
        }
      });
      native.notifySystemNetworkChange({ networkInfo: this.getNetworkInfo() });
    });

    // 网络连接信息变化
    this._netConnection.on("netConnectionPropertiesChange", (param: { netHandle: connection.NetHandle; connectionProperties: connection.ConnectionProperties }) => {
      return; // TODO

      let { netHandle, connectionProperties } = param;
      this._networkId = netHandle.netId.toString();
      connectionProperties.linkAddresses.forEach((linkAddress: connection.LinkAddress) => {
        switch (linkAddress.address.family) {
          case 1:
            this._ipType = IPType.IP_TYPE_IPV4_ONLY;
            break;
          case 2:
            this._ipType = IPType.IP_TYPE_IPV6_ONLY;
            break;
          default:
            this._ipType = IPType.IP_TYPE_UNKNOWN;
            break;
        }
      });
      native.notifySystemNetworkChange({ networkInfo: this.getNetworkInfo() });
    });

    // 网络丢失
    this._netConnection.on("netLost", (netHandle) => {
      this._networkId = netHandle.netId.toString();
      if (this._networkStatus != NetworkStatus.Disconnected) {
        this._networkStatus = NetworkStatus.Disconnected;
        native.notifySystemNetworkChange({ networkInfo: this.getNetworkInfo() });
      }
    });

    // 网络不可用
    this._netConnection.on("netUnavailable", () => {
      if (this._networkStatus != NetworkStatus.Disconnected) {
        this._networkStatus = NetworkStatus.Disconnected;
        native.notifySystemNetworkChange({ networkInfo: this.getNetworkInfo() });
      }
    });
  }

  unInit() {
    this._netConnection.unregister((error) => {
      if (error) {
        console.error(`TIM: |-flutter NetworkCenter unregister ${JSON.stringify(error)}`);
      }
    });
  }

  getNetworkInfo(): NetworkInfo {
    return {
      ip_type: this._ipType,
      network_type: this._networkType,
      network_id: this._networkId,
      wifi_network_interface: {
        network_handle: this._wifiNetworkHandle,
        network_interface_name: "",
      },
      xg_network_interface: {
        network_handle: this._xgNetworkHandle,
        network_interface_name: "",
      },
      network_status: this._networkStatus,
      initialize_cost_time: this._initializeCostTime,
    };
  }
}

export default NetworkCenter;
