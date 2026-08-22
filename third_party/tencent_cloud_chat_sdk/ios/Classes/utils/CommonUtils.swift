import Flutter
import ImSDK_Plus

//  通用工具类
public class CommonUtils {
    /**
     * 通用方法，获得参数值，如未找到参数，则直接中断
     *
     * @param methodCall 方法调用对象
     * @param result     返回对象
     * @param param      参数名
     */
    public static func getParam(call: FlutterMethodCall, result: @escaping FlutterResult, param: String) -> Any? {
        let value = (call.arguments as! [String: Any])[param];
        if value == nil {
        }
        return value
    }

    // 返回失败结果
	public static func resultFailed(desc: String? = "failed", code: Int32? = 0, call: FlutterMethodCall, result: @escaping FlutterResult) {
        DispatchQueue.main.async {
            let res = ["code": code ?? -1, "desc": desc ?? ""] as [String : Any]
            
            result(res)
        }
    }
	
	public static func resultFailed(desc: String? = "failed", code: Int32? = -1, data: Dictionary<String, Any>, call: FlutterMethodCall, result: @escaping FlutterResult) {
        
        DispatchQueue.main.async {
            let res = ["code": code ?? -1, "desc": desc ?? "", "data": data] as [String : Any]
           
            result(res)
        }
	}

    // 返回成功结果
	public static func resultSuccess(desc: String = "ok", call: FlutterMethodCall, result: @escaping FlutterResult, data: Any = NSNull()) {
        DispatchQueue.main.async {
            let res = ["code": 0, "desc": desc, "data": data] as [String : Any]

            result(res)
        }
    }
}
