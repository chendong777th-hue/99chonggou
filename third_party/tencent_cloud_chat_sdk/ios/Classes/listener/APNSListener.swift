//
//  APNSListener.swift
//  tencent_im_sdk_plugin
//
//  Created by xingchenhe on 2020/12/18.
//

import Foundation
import ImSDK_Plus
import Flutter
class APNSListener: NSObject, V2TIMAPNSListener {
	public static var count: UInt32 = 0;
	
	public func onSetAPPUnreadCount() -> UInt32 {
            print("im sdk set unreadCount :\(SDKManager.unreadCount)")
            return SDKManager.unreadCount
        }
	
}
