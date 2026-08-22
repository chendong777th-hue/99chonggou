//
//  SDKManager.swift
//  tencent_im_sdk_plugin
//
//  Created by xingchenhe on 2020/12/24.
//

import Foundation
import ImSDK_Plus
import Flutter

class SDKManager {
    private var apnsListener = APNSListener();
    public static var unreadCount:UInt32 = 0;

    public func doBackground(call: FlutterMethodCall, result: @escaping FlutterResult) {
        let unreadCount = CommonUtils.getParam(call: call, result: result, param: "unreadCount") as! UInt32;
        SDKManager.unreadCount = unreadCount
        CommonUtils.resultSuccess(call: call, result: result)
    }
    public func doForeground(call: FlutterMethodCall, result: @escaping FlutterResult) {
        SDKManager.unreadCount = 0
        CommonUtils.resultSuccess(call: call, result: result)
    }

    public func setAPNSListener(call: FlutterMethodCall, result: @escaping FlutterResult) {
        V2TIMManager.sharedInstance().setAPNSListener(apnsListener: apnsListener)
        CommonUtils.resultSuccess(call: call, result: result, data: "setAPNSListener is done")
    }

    public func setAPNS(call: FlutterMethodCall, result: @escaping FlutterResult) {
        if let businessID = CommonUtils.getParam(call: call, result: result, param: "businessID") as? Int32,
            let token = CommonUtils.getParam(call: call, result: result, param: "token") as? String {
            let config = V2TIMAPNSConfig()
            config.token = token.hexadecimal()
            config.businessID = businessID

            V2TIMManager.sharedInstance().setAPNS(config: config, succ: {
                CommonUtils.resultSuccess(call: call, result: result);
            }, fail: { code, desc in
                CommonUtils.resultFailed(desc: desc, code: code, call: call, result: result)
            })
        }
    }

    public func setVOIP(call: FlutterMethodCall, result: @escaping FlutterResult) {
        if let businessID = CommonUtils.getParam(call: call, result: result, param: "businessID") as? Int,
            let token = CommonUtils.getParam(call: call, result: result, param: "token") as? String {
            let config = V2TIMVOIPConfig()
            config.token = token.hexadecimal()    
            config.certificateID = businessID

            V2TIMManager.sharedInstance().setVOIP(config: config, succ: {
                CommonUtils.resultSuccess(call: call, result: result);
            }, fail: { code, desc in
                CommonUtils.resultFailed(desc: desc, code: code, call: call, result: result)
            })
        }
    }
}

extension String {
    /// Create `Data` from hexadecimal string representation
    ///
    /// This takes a hexadecimal representation and creates a `Data` object. Note, if the string has any spaces or non-hex characters (e.g. starts with '<' and with a '>'), those are ignored and only hex characters are processed.
    ///
    /// - returns: Data represented by this hexadecimal string.

    func hexadecimal() -> Data? {
        var data = Data(capacity: count / 2)

        let regex = try! NSRegularExpression(pattern: "[0-9a-f]{1,2}", options: .caseInsensitive)
        regex.enumerateMatches(in: self, range: NSMakeRange(0, utf16.count)) { match, flags, stop in
            let byteString = (self as NSString).substring(with: match!.range)
            var num = UInt8(byteString, radix: 16)!
            data.append(&num, count: 1)
        }

        guard data.count > 0 else { return nil }

        return data
    }

}
